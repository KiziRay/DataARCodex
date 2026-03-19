use std::env;
use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc};
use std::thread;
use std::time::Instant;

const SYMBOLS: &str = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";

#[derive(Debug, Clone)]
struct Config {
    archive: String,
    dictionary: Option<String>,
    mask: Option<String>,
    threads: usize,
}

fn main() {
    let start = Instant::now();
    let config = match parse_args(env::args().skip(1).collect()) {
        Ok(cfg) => cfg,
        Err(msg) => {
            eprintln!("{msg}\n");
            print_usage();
            std::process::exit(1);
        }
    };

    if !archive_exists(&config.archive) {
        eprintln!("archive not found: {}", config.archive);
        std::process::exit(1);
    }

    if !has_7z() {
        eprintln!("7z executable was not found in PATH");
        std::process::exit(1);
    }

    let found = if let Some(dict) = config.dictionary.as_ref() {
        match run_dictionary_attack(&config.archive, dict, config.threads) {
            Ok(v) => v,
            Err(err) => {
                eprintln!("dictionary attack failed: {err}");
                std::process::exit(1);
            }
        }
    } else if let Some(mask) = config.mask.as_ref() {
        match run_mask_attack(&config.archive, mask, config.threads) {
            Ok(v) => v,
            Err(err) => {
                eprintln!("mask attack failed: {err}");
                std::process::exit(1);
            }
        }
    } else {
        eprintln!("either --dict or --mask is required");
        print_usage();
        std::process::exit(1);
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

    println!("elapsed_sec: {:.3}", start.elapsed().as_secs_f64());
}

fn parse_args(args: Vec<String>) -> Result<Config, String> {
    if args.is_empty() {
        return Err("missing arguments".to_string());
    }

    let mut archive: Option<String> = None;
    let mut dictionary: Option<String> = None;
    let mut mask: Option<String> = None;
    let mut threads = thread::available_parallelism().map_or(4, usize::from);

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "recover" => {
                i += 1;
            }
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
                    .map_err(|_| "--threads must be an integer".to_string())?;
                if threads == 0 {
                    return Err("--threads must be > 0".to_string());
                }
                i += 2;
            }
            "--help" | "-h" => {
                print_usage();
                std::process::exit(0);
            }
            unknown => {
                return Err(format!("unknown argument: {unknown}"));
            }
        }
    }

    if dictionary.is_some() && mask.is_some() {
        return Err("use either --dict or --mask, not both".to_string());
    }

    let archive = archive.ok_or_else(|| "--archive is required".to_string())?;

    Ok(Config {
        archive,
        dictionary,
        mask,
        threads,
    })
}

fn next_arg(args: &[String], idx: usize, flag: &str) -> Result<String, String> {
    args.get(idx + 1)
        .cloned()
        .ok_or_else(|| format!("missing value for {flag}"))
}

fn print_usage() {
    println!(
        "Usage:\n  password_recovery_rust recover --archive <file> --dict <wordlist.txt> [--threads N]\n  password_recovery_rust recover --archive <file> --mask <mask> [--threads N]\n\nMask Tokens:\n  ?d digits 0-9\n  ?l lowercase a-z\n  ?u uppercase A-Z\n  ?s symbols\n  ?a all above"
    );
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
        .filter_map(|line| line.ok())
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
