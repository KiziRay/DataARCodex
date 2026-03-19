use std::fs::{self, File};
use std::io::{self, BufRead, BufReader};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc};
use std::thread;

const SYMBOLS: &str = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";

pub fn recover_with_dict(archive: &str, dictionary_file: &str, threads: usize) -> Result<String, String> {
    if !Path::new(archive).exists() {
        return Err(format!("找不到壓縮檔: {archive}"));
    }
    if !has_7z() {
        return Err("PATH 中找不到 7z".to_string());
    }
    let found = run_dictionary_attack(archive, dictionary_file, threads)?;
    Ok(match found {
        Some(pwd) => format!("status: found\npassword: {pwd}"),
        None => "status: not_found".to_string(),
    })
}

pub fn recover_with_mask(archive: &str, mask: &str, threads: usize) -> Result<String, String> {
    if !Path::new(archive).exists() {
        return Err(format!("找不到壓縮檔: {archive}"));
    }
    if !has_7z() {
        return Err("PATH 中找不到 7z".to_string());
    }
    let found = run_mask_attack(archive, mask, threads)?;
    Ok(match found {
        Some(pwd) => format!("status: found\npassword: {pwd}"),
        None => "status: not_found".to_string(),
    })
}

pub fn extract_hash_api(
    archive: &str,
    out_file: &str,
    john_dir: Option<&str>,
    perl: Option<&str>,
) -> Result<String, String> {
    if !Path::new(archive).exists() {
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
            Command::new(tool).arg(archive).output().map_err(to_err)?
        }
        "rar" => {
            let tool = resolve_john_tool("rar2john", john_dir)?;
            Command::new(tool).arg(archive).output().map_err(to_err)?
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
        _ => return Err("僅支援 zip/rar/7z".to_string()),
    };

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("提取 hash 失敗: {stderr}"));
    }

    if output.stdout.is_empty() {
        return Err("提取結果為空".to_string());
    }

    fs::write(out_file, output.stdout).map_err(to_err)?;
    Ok(format!("status: hash_extracted\nhash_file: {out_file}"))
}

pub fn john_crack_api(hash_file: &str, wordlist: Option<&str>, john: Option<&str>) -> Result<String, String> {
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

    Ok("status: john_done".to_string())
}

pub fn hashcat_crack_api(
    hash_file: &str,
    mode: &str,
    attack: &str,
    mask: Option<&str>,
    wordlist: Option<&str>,
    hashcat: Option<&str>,
    extra: &[String],
) -> Result<String, String> {
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

    Ok("status: hashcat_done".to_string())
}

fn resolve_john_tool(name: &str, john_dir: Option<&str>) -> Result<String, String> {
    if let Some(dir) = john_dir {
        let direct = Path::new(dir).join(name);
        if direct.exists() {
            return Ok(direct.to_string_lossy().into_owned());
        }
        if !name.ends_with(".pl") {
            let exe = Path::new(dir).join(format!("{name}.exe"));
            if exe.exists() {
                return Ok(exe.to_string_lossy().into_owned());
            }
        }
        return Err(format!("在 --john-dir 找不到工具: {name}"));
    }
    Ok(name.to_string())
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
