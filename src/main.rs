use std::env;
use std::fs::{self, File};
use std::io::{self, BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc};
use std::thread;
use std::time::Instant;

const SYMBOLS: &str = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";

#[derive(Debug, Clone)]
struct RecoverConfig {
    archive: String,
    dictionary: Option<String>,
    mask: Option<String>,
    threads: usize,
}

#[derive(Debug, Clone)]
enum AppCommand {
    Recover(RecoverConfig),
    ExtractHash {
        archive: String,
        out: String,
        john_dir: Option<String>,
        perl: Option<String>,
    },
    JohnCrack {
        hash_file: String,
        wordlist: Option<String>,
        john: Option<String>,
    },
    HashcatCrack {
        hash_file: String,
        mode: String,
        attack: String,
        mask: Option<String>,
        wordlist: Option<String>,
        hashcat: Option<String>,
        extra: Vec<String>,
    },
    Help,
}

fn main() {
    let start = Instant::now();

    let command = match parse_args(env::args().skip(1).collect()) {
        Ok(cmd) => cmd,
        Err(msg) => {
            eprintln!("{msg}\n");
            print_usage();
            std::process::exit(1);
        }
    };

    let result = match command {
        AppCommand::Recover(cfg) => run_recover(cfg),
        AppCommand::ExtractHash {
            archive,
            out,
            john_dir,
            perl,
        } => extract_hash(&archive, &out, john_dir.as_deref(), perl.as_deref()),
        AppCommand::JohnCrack {
            hash_file,
            wordlist,
            john,
        } => run_john_crack(&hash_file, wordlist.as_deref(), john.as_deref()),
        AppCommand::HashcatCrack {
            hash_file,
            mode,
            attack,
            mask,
            wordlist,
            hashcat,
            extra,
        } => run_hashcat_crack(
            &hash_file,
            &mode,
            &attack,
            mask.as_deref(),
            wordlist.as_deref(),
            hashcat.as_deref(),
            &extra,
        ),
        AppCommand::Help => {
            print_usage();
            Ok(())
        }
    };

    if let Err(err) = result {
        eprintln!("錯誤: {err}");
        std::process::exit(1);
    }

    println!("elapsed_sec: {:.3}", start.elapsed().as_secs_f64());
}

fn parse_args(args: Vec<String>) -> Result<AppCommand, String> {
    if args.is_empty() {
        return Ok(AppCommand::Help);
    }

    match args[0].as_str() {
        "recover" => parse_recover_args(args[1..].to_vec()).map(AppCommand::Recover),
        "extract-hash" => parse_extract_hash_args(args[1..].to_vec()),
        "john-crack" => parse_john_args(args[1..].to_vec()),
        "hashcat-crack" => parse_hashcat_args(args[1..].to_vec()),
        "help" | "--help" | "-h" => Ok(AppCommand::Help),
        other => Err(format!("unknown command: {other}")),
    }
}

fn parse_recover_args(args: Vec<String>) -> Result<RecoverConfig, String> {
    let mut archive: Option<String> = None;
    let mut dictionary: Option<String> = None;
    let mut mask: Option<String> = None;
    let mut threads = thread::available_parallelism().map_or(4, usize::from);

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--archive" => {
                archive = Some(next_arg(&args, i, "--archive")?);
                i += 2;
            }
            "--dict" => {
                dictionary = Some(next_arg(&args, i, "--dict")?);
                i += 2;
            }
            "--mask" => {
                mask = Some(next_arg(&args, i, "--mask")?);
                i += 2;
            }
            "--threads" => {
                let val = next_arg(&args, i, "--threads")?;
                threads = val
                    .parse::<usize>()
                    .map_err(|_| "--threads 必須為整數".to_string())?;
                if threads == 0 {
                    return Err("--threads 必須大於 0".to_string());
                }
                i += 2;
            }
            unknown => {
                return Err(format!("unknown argument: {unknown}"));
            }
        }
    }

    if dictionary.is_some() && mask.is_some() {
        return Err("--dict 與 --mask 只能擇一".to_string());
    }

    let archive = archive.ok_or_else(|| "recover 需要 --archive".to_string())?;

    Ok(RecoverConfig {
        archive,
        dictionary,
        mask,
        threads,
    })
}

fn parse_extract_hash_args(args: Vec<String>) -> Result<AppCommand, String> {
    let mut archive: Option<String> = None;
    let mut out: Option<String> = None;
    let mut john_dir: Option<String> = None;
    let mut perl: Option<String> = None;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--archive" => {
                archive = Some(next_arg(&args, i, "--archive")?);
                i += 2;
            }
            "--out" => {
                out = Some(next_arg(&args, i, "--out")?);
                i += 2;
            }
            "--john-dir" => {
                john_dir = Some(next_arg(&args, i, "--john-dir")?);
                i += 2;
            }
            "--perl" => {
                perl = Some(next_arg(&args, i, "--perl")?);
                i += 2;
            }
            unknown => return Err(format!("unknown argument: {unknown}")),
        }
    }

    Ok(AppCommand::ExtractHash {
        archive: archive.ok_or_else(|| "extract-hash 需要 --archive".to_string())?,
        out: out.unwrap_or_else(|| "hash.txt".to_string()),
        john_dir,
        perl,
    })
}

fn parse_john_args(args: Vec<String>) -> Result<AppCommand, String> {
    let mut hash_file: Option<String> = None;
    let mut wordlist: Option<String> = None;
    let mut john: Option<String> = None;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--hash-file" => {
                hash_file = Some(next_arg(&args, i, "--hash-file")?);
                i += 2;
            }
            "--wordlist" => {
                wordlist = Some(next_arg(&args, i, "--wordlist")?);
                i += 2;
            }
            "--john" => {
                john = Some(next_arg(&args, i, "--john")?);
                i += 2;
            }
            unknown => return Err(format!("unknown argument: {unknown}")),
        }
    }

    Ok(AppCommand::JohnCrack {
        hash_file: hash_file.ok_or_else(|| "john-crack 需要 --hash-file".to_string())?,
        wordlist,
        john,
    })
}

fn parse_hashcat_args(args: Vec<String>) -> Result<AppCommand, String> {
    let mut hash_file: Option<String> = None;
    let mut mode: Option<String> = None;
    let mut attack: Option<String> = None;
    let mut mask: Option<String> = None;
    let mut wordlist: Option<String> = None;
    let mut hashcat: Option<String> = None;
    let mut extra: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--hash-file" => {
                hash_file = Some(next_arg(&args, i, "--hash-file")?);
                i += 2;
            }
            "--mode" => {
                mode = Some(next_arg(&args, i, "--mode")?);
                i += 2;
            }
            "--attack" => {
                attack = Some(next_arg(&args, i, "--attack")?);
                i += 2;
            }
            "--mask" => {
                mask = Some(next_arg(&args, i, "--mask")?);
                i += 2;
            }
            "--wordlist" => {
                wordlist = Some(next_arg(&args, i, "--wordlist")?);
                i += 2;
            }
            "--hashcat" => {
                hashcat = Some(next_arg(&args, i, "--hashcat")?);
                i += 2;
            }
            "--extra" => {
                extra.push(next_arg(&args, i, "--extra")?);
                i += 2;
            }
            unknown => return Err(format!("unknown argument: {unknown}")),
        }
    }

    Ok(AppCommand::HashcatCrack {
        hash_file: hash_file.ok_or_else(|| "hashcat-crack 需要 --hash-file".to_string())?,
        mode: mode.unwrap_or_else(|| "13000".to_string()),
        attack: attack.unwrap_or_else(|| "3".to_string()),
        mask,
        wordlist,
        hashcat,
        extra,
    })
}

fn next_arg(args: &[String], idx: usize, flag: &str) -> Result<String, String> {
    args.get(idx + 1)
        .cloned()
        .ok_or_else(|| format!("missing value for {flag}"))
}

fn print_usage() {
    println!(
        "用法:\n  password_recovery_rust recover --archive <file> --dict <wordlist.txt> [--threads N]\n  password_recovery_rust recover --archive <file> --mask <mask> [--threads N]\n\n  password_recovery_rust extract-hash --archive <file> [--out hash.txt] [--john-dir <dir>] [--perl <perl.exe>]\n  password_recovery_rust john-crack --hash-file <hash.txt> [--wordlist <wordlist>] [--john <john.exe>]\n  password_recovery_rust hashcat-crack --hash-file <hash.txt> [--mode 13000] [--attack 3] [--mask ?d?d?d?d] [--wordlist <wordlist>] [--hashcat <hashcat.exe>] [--extra <arg>]\n\nMask Tokens:\n  ?d digits 0-9\n  ?l lowercase a-z\n  ?u uppercase A-Z\n  ?s symbols\n  ?a all above"
    );
}

fn run_recover(cfg: RecoverConfig) -> Result<(), String> {
    if !archive_exists(&cfg.archive) {
        return Err(format!("找不到壓縮檔: {}", cfg.archive));
    }

    if !has_7z() {
        return Err("PATH 中找不到 7z，無法使用內建 recover".to_string());
    }

    let found = if let Some(dict) = cfg.dictionary.as_ref() {
        run_dictionary_attack(&cfg.archive, dict, cfg.threads)?
    } else if let Some(mask) = cfg.mask.as_ref() {
        run_mask_attack(&cfg.archive, mask, cfg.threads)?
    } else {
        return Err("recover 需要 --dict 或 --mask".to_string());
    };

    match found {
        Some(password) => {
            println!("status: found");
            println!("password: {password}");
        }
        None => {
            println!("status: not_found");
        }
    }

    Ok(())
}

fn extract_hash(
    archive: &str,
    out_file: &str,
    john_dir: Option<&str>,
    perl: Option<&str>,
) -> Result<(), String> {
    if !archive_exists(archive) {
        return Err(format!("找不到檔案: {archive}"));
    }

    let ext = Path::new(archive)
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();

    let output = match ext.as_str() {
        "zip" => {
            let tool = resolve_john_tool("zip2john", john_dir)?;
            Command::new(tool)
                .arg(archive)
                .output()
                .map_err(to_err)?
        }
        "rar" => {
            let tool = resolve_john_tool("rar2john", john_dir)?;
            Command::new(tool)
                .arg(archive)
                .output()
                .map_err(to_err)?
        }
        "7z" => {
            let script = resolve_john_tool("7z2john.pl", john_dir)?;
            let perl_exec = perl.unwrap_or("perl");
            Command::new(perl_exec)
                .arg(script)
                .arg(archive)
                .output()
                .map_err(to_err)?
        }
        _ => {
            return Err("僅支援 zip/rar/7z".to_string());
        }
    };

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("提取 hash 失敗: {stderr}"));
    }

    if output.stdout.is_empty() {
        return Err("提取結果為空".to_string());
    }

    fs::write(out_file, output.stdout).map_err(to_err)?;
    println!("status: hash_extracted");
    println!("hash_file: {out_file}");
    Ok(())
}

fn run_john_crack(hash_file: &str, wordlist: Option<&str>, john: Option<&str>) -> Result<(), String> {
    if !Path::new(hash_file).exists() {
        return Err(format!("找不到 hash 檔案: {hash_file}"));
    }

    let john_exec = john.unwrap_or("john");
    let mut cmd = Command::new(john_exec);

    if let Some(list) = wordlist {
        cmd.arg(format!("--wordlist={list}"));
    }

    let status = cmd
        .arg(hash_file)
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .map_err(to_err)?;

    if !status.success() {
        return Err("john 破解失敗".to_string());
    }

    println!("status: john_done");
    Ok(())
}

fn run_hashcat_crack(
    hash_file: &str,
    mode: &str,
    attack: &str,
    mask: Option<&str>,
    wordlist: Option<&str>,
    hashcat: Option<&str>,
    extra: &[String],
) -> Result<(), String> {
    if !Path::new(hash_file).exists() {
        return Err(format!("找不到 hash 檔案: {hash_file}"));
    }

    let hashcat_exec = hashcat.unwrap_or("hashcat");
    let mut cmd = Command::new(hashcat_exec);
    cmd.arg("-m").arg(mode).arg("-a").arg(attack).arg(hash_file);

    if let Some(list) = wordlist {
        cmd.arg(list);
    }

    if let Some(m) = mask {
        cmd.arg(m);
    }

    for item in extra {
        cmd.arg(item);
    }

    let status = cmd
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .map_err(to_err)?;

    if !status.success() {
        return Err("hashcat 破解失敗".to_string());
    }

    println!("status: hashcat_done");
    Ok(())
}

fn resolve_john_tool(name: &str, john_dir: Option<&str>) -> Result<String, String> {
    if let Some(dir) = john_dir {
        let direct = Path::new(dir).join(name);
        if direct.exists() {
            return Ok(path_to_string(&direct));
        }

        if !name.ends_with(".pl") {
            let exe = Path::new(dir).join(format!("{name}.exe"));
            if exe.exists() {
                return Ok(path_to_string(&exe));
            }
        }

        return Err(format!("在 --john-dir 找不到工具: {name}"));
    }

    Ok(name.to_string())
}

fn path_to_string(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

fn archive_exists(path: &str) -> bool {
    Path::new(path).exists()
}

fn has_7z() -> bool {
    Command::new("7z")
        .arg("-h")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success() || s.code().is_some())
        .unwrap_or(false)
}

fn run_dictionary_attack(
    archive: &str,
    dictionary_file: &str,
    threads: usize,
) -> Result<Option<String>, String> {
    let file = File::open(dictionary_file).map_err(to_err)?;
    let reader = BufReader::new(file);
    let words: Vec<String> = reader
        .lines()
        .map_while(Result::ok)
        .filter(|line| !line.is_empty())
        .collect();

    if words.is_empty() {
        return Ok(None);
    }

    let words = Arc::new(words);
    let stop = Arc::new(AtomicBool::new(false));
    let (tx, rx) = mpsc::channel::<String>();
    let mut workers = Vec::with_capacity(threads);

    for worker_id in 0..threads {
        let words = Arc::clone(&words);
        let stop = Arc::clone(&stop);
        let tx = tx.clone();
        let archive = archive.to_string();

        workers.push(thread::spawn(move || {
            let mut idx = worker_id;
            while idx < words.len() {
                if stop.load(Ordering::Relaxed) {
                    return;
                }
                let candidate = &words[idx];
                if let Ok(true) = test_password(&archive, candidate) {
                    stop.store(true, Ordering::Relaxed);
                    let _ = tx.send(candidate.clone());
                    return;
                }
                idx += threads;
            }
        }));
    }

    drop(tx);

    let found = rx.recv().ok();
    stop.store(true, Ordering::Relaxed);

    for worker in workers {
        let _ = worker.join();
    }

    Ok(found)
}

fn run_mask_attack(archive: &str, mask: &str, threads: usize) -> Result<Option<String>, String> {
    let charsets = parse_mask(mask)?;
    if charsets.is_empty() {
        return Err("empty mask".to_string());
    }

    let mut total: u128 = 1;
    for set in &charsets {
        total = total
            .checked_mul(set.len() as u128)
            .ok_or_else(|| "search space overflow".to_string())?;
    }

    let charsets = Arc::new(charsets);
    let stop = Arc::new(AtomicBool::new(false));
    let (tx, rx) = mpsc::channel::<String>();
    let mut workers = Vec::with_capacity(threads);

    for worker_id in 0..threads {
        let charsets = Arc::clone(&charsets);
        let stop = Arc::clone(&stop);
        let tx = tx.clone();
        let archive = archive.to_string();

        workers.push(thread::spawn(move || {
            let mut index = worker_id as u128;
            while index < total {
                if stop.load(Ordering::Relaxed) {
                    return;
                }

                let candidate = candidate_from_index(index, &charsets);
                if let Ok(true) = test_password(&archive, &candidate) {
                    stop.store(true, Ordering::Relaxed);
                    let _ = tx.send(candidate);
                    return;
                }

                index += threads as u128;
            }
        }));
    }

    drop(tx);

    let found = rx.recv().ok();
    stop.store(true, Ordering::Relaxed);

    for worker in workers {
        let _ = worker.join();
    }

    Ok(found)
}

fn parse_mask(mask: &str) -> Result<Vec<Vec<char>>, String> {
    let mut result = Vec::new();
    let chars: Vec<char> = mask.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        let ch = chars[i];
        if ch == '?' {
            let token = chars
                .get(i + 1)
                .copied()
                .ok_or_else(|| "mask ends with '?'".to_string())?;
            result.push(token_to_charset(token)?);
            i += 2;
        } else {
            result.push(vec![ch]);
            i += 1;
        }
    }

    Ok(result)
}

fn token_to_charset(token: char) -> Result<Vec<char>, String> {
    match token {
        'd' => Ok(('0'..='9').collect()),
        'l' => Ok(('a'..='z').collect()),
        'u' => Ok(('A'..='Z').collect()),
        's' => Ok(SYMBOLS.chars().collect()),
        'a' => {
            let mut v: Vec<char> = ('0'..='9').collect();
            v.extend('a'..='z');
            v.extend('A'..='Z');
            v.extend(SYMBOLS.chars());
            Ok(v)
        }
        _ => Err(format!("unsupported mask token: ?{token}")),
    }
}

fn candidate_from_index(mut index: u128, charsets: &[Vec<char>]) -> String {
    let mut out = vec![' '; charsets.len()];

    for pos in (0..charsets.len()).rev() {
        let set = &charsets[pos];
        let base = set.len() as u128;
        let pick = (index % base) as usize;
        out[pos] = set[pick];
        index /= base;
    }

    out.into_iter().collect()
}

fn test_password(archive: &str, password: &str) -> Result<bool, String> {
    let pwd = format!("-p{password}");
    let status = Command::new("7z")
        .arg("t")
        .arg("-y")
        .arg(pwd)
        .arg(archive)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(to_err)?;

    Ok(status.success())
}

fn to_err(err: io::Error) -> String {
    err.to_string()
}
