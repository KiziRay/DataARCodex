use password_recovery_rust::{
    extract_hash_api, hashcat_crack_api, john_crack_api, recover_with_dict, recover_with_mask,
};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

#[derive(Deserialize)]
struct ExtractHashPayload {
    archive: String,
    #[serde(alias = "outFile")]
    out_file: String,
    #[serde(default, alias = "johnDir")]
    john_dir: Option<String>,
    #[serde(default)]
    perl: Option<String>,
}

#[derive(Deserialize)]
struct JohnCrackPayload {
    #[serde(alias = "hashFile")]
    hash_file: String,
    #[serde(default)]
    wordlist: Option<String>,
    #[serde(default)]
    john: Option<String>,
}

#[derive(Deserialize)]
struct HashcatPayload {
    #[serde(alias = "hashFile")]
    hash_file: String,
    #[serde(default = "default_hashcat_mode")]
    mode: String,
    #[serde(default = "default_hashcat_attack")]
    attack: String,
    #[serde(default)]
    mask: Option<String>,
    #[serde(default)]
    wordlist: Option<String>,
    #[serde(default)]
    hashcat: Option<String>,
    #[serde(default)]
    extra: Vec<String>,
}

#[derive(Deserialize)]
struct RecoverDictPayload {
    archive: String,
    #[serde(alias = "dictionaryFile")]
    dictionary_file: String,
    #[serde(default = "default_threads")]
    threads: u32,
}

#[derive(Deserialize)]
struct RecoverMaskPayload {
    archive: String,
    mask: String,
    #[serde(default = "default_threads")]
    threads: u32,
}

#[derive(Deserialize, Default)]
struct EnvCheckPayload {
    #[serde(default, alias = "johnDir")]
    john_dir: Option<String>,
    #[serde(default)]
    john: Option<String>,
    #[serde(default)]
    hashcat: Option<String>,
    #[serde(default)]
    perl: Option<String>,
}

#[derive(Serialize)]
struct ToolCheck {
    key: String,
    label: String,
    available: bool,
    detail: String,
}

#[tauri::command]
fn cmd_extract_hash(payload: ExtractHashPayload) -> Result<String, String> {
    extract_hash_api(
        &payload.archive,
        &payload.out_file,
        payload.john_dir.as_deref(),
        payload.perl.as_deref(),
    )
}

#[tauri::command]
fn cmd_john_crack(payload: JohnCrackPayload) -> Result<String, String> {
    john_crack_api(
        &payload.hash_file,
        payload.wordlist.as_deref(),
        payload.john.as_deref(),
    )
}

#[tauri::command]
fn cmd_hashcat_crack(payload: HashcatPayload) -> Result<String, String> {
    hashcat_crack_api(
        &payload.hash_file,
        &payload.mode,
        &payload.attack,
        payload.mask.as_deref(),
        payload.wordlist.as_deref(),
        payload.hashcat.as_deref(),
        &payload.extra,
    )
}

#[tauri::command]
fn cmd_recover_dict(payload: RecoverDictPayload) -> Result<String, String> {
    recover_with_dict(
        &payload.archive,
        &payload.dictionary_file,
        payload.threads as usize,
    )
}

#[tauri::command]
fn cmd_recover_mask(payload: RecoverMaskPayload) -> Result<String, String> {
    recover_with_mask(&payload.archive, &payload.mask, payload.threads as usize)
}

#[tauri::command]
fn cmd_check_environment(payload: Option<EnvCheckPayload>) -> Vec<ToolCheck> {
    let payload = payload.unwrap_or_default();
    let john_dir = normalize_opt(payload.john_dir);
    let john_exec = normalize_opt(payload.john).unwrap_or_else(|| "john".to_string());
    let hashcat_exec = normalize_opt(payload.hashcat).unwrap_or_else(|| "hashcat".to_string());
    let perl_exec = normalize_opt(payload.perl).unwrap_or_else(|| "perl".to_string());

    let mut checks = vec![
        check_command("seven_zip", "7z", "7z", &["-h"]),
        check_command("john", "john", &john_exec, &["--help"]),
        check_command("hashcat", "hashcat", &hashcat_exec, &["--help"]),
        check_command("perl", "Perl", &perl_exec, &["-v"]),
    ];

    checks.extend(check_john_helpers(john_dir.as_deref()));
    checks
}

fn default_hashcat_mode() -> String {
    "13000".to_string()
}

fn default_hashcat_attack() -> String {
    "3".to_string()
}

fn default_threads() -> u32 {
    8
}

fn normalize_opt(value: Option<String>) -> Option<String> {
    value.and_then(|raw| {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        }
    })
}

fn check_command(key: &str, label: &str, executable: &str, args: &[&str]) -> ToolCheck {
    let available = Command::new(executable)
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success() || status.code().is_some())
        .unwrap_or(false);

    let detail = if available {
        format!("可執行：{executable}")
    } else {
        format!("無法執行：{executable}")
    };

    ToolCheck {
        key: key.to_string(),
        label: label.to_string(),
        available,
        detail,
    }
}

fn check_john_helpers(john_dir: Option<&str>) -> Vec<ToolCheck> {
    if let Some(dir) = john_dir {
        let base = Path::new(dir);
        let mut checks = Vec::new();
        checks.push(check_directory("john_dir", "John run 目錄", base));
        checks.push(check_candidates(
            "zip2john",
            "zip2john",
            &[base.join("zip2john"), base.join("zip2john.exe")],
        ));
        checks.push(check_candidates(
            "rar2john",
            "rar2john",
            &[base.join("rar2john"), base.join("rar2john.exe")],
        ));
        checks.push(check_candidates(
            "seven_zip_to_john",
            "7z2john.pl",
            &[base.join("7z2john.pl")],
        ));
        return checks;
    }

    vec![
        ToolCheck {
            key: "john_dir".to_string(),
            label: "John run 目錄".to_string(),
            available: false,
            detail: "未填寫，將使用 PATH".to_string(),
        },
        check_command("zip2john", "zip2john", "zip2john", &["--help"]),
        check_command("rar2john", "rar2john", "rar2john", &["--help"]),
        ToolCheck {
            key: "seven_zip_to_john".to_string(),
            label: "7z2john.pl".to_string(),
            available: false,
            detail: "建議指定 John run 目錄來支援 .7z".to_string(),
        },
    ]
}

fn check_directory(key: &str, label: &str, path: &Path) -> ToolCheck {
    let available = path.is_dir();
    let detail = if available {
        format!("目錄存在：{}", path.display())
    } else {
        format!("目錄不存在：{}", path.display())
    };

    ToolCheck {
        key: key.to_string(),
        label: label.to_string(),
        available,
        detail,
    }
}

fn check_candidates(key: &str, label: &str, candidates: &[PathBuf]) -> ToolCheck {
    if let Some(found) = candidates.iter().find(|path| path.exists()) {
        return ToolCheck {
            key: key.to_string(),
            label: label.to_string(),
            available: true,
            detail: format!("已找到：{}", found.display()),
        };
    }

    let checked = candidates
        .iter()
        .map(|p| p.display().to_string())
        .collect::<Vec<_>>()
        .join(" | ");

    ToolCheck {
        key: key.to_string(),
        label: label.to_string(),
        available: false,
        detail: format!("未找到：{checked}"),
    }
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            cmd_extract_hash,
            cmd_john_crack,
            cmd_hashcat_crack,
            cmd_recover_dict,
            cmd_recover_mask,
            cmd_check_environment
        ])
        .run(tauri::generate_context!())
        .expect("啟動 Tauri 失敗");
}
