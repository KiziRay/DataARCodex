use password_recovery_rust::{
    extract_hash_api, hashcat_crack_api, john_crack_api, recover_with_dict, recover_with_mask,
};
use serde::Deserialize;

#[derive(Deserialize)]
struct HashcatPayload {
    hash_file: String,
    mode: String,
    attack: String,
    mask: Option<String>,
    wordlist: Option<String>,
    hashcat: Option<String>,
    extra: Vec<String>,
}

#[tauri::command]
fn cmd_extract_hash(
    archive: String,
    out_file: String,
    john_dir: Option<String>,
    perl: Option<String>,
) -> Result<String, String> {
    extract_hash_api(&archive, &out_file, john_dir.as_deref(), perl.as_deref())
}

#[tauri::command]
fn cmd_john_crack(
    hash_file: String,
    wordlist: Option<String>,
    john: Option<String>,
) -> Result<String, String> {
    john_crack_api(&hash_file, wordlist.as_deref(), john.as_deref())
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
fn cmd_recover_dict(archive: String, dictionary_file: String, threads: u32) -> Result<String, String> {
    recover_with_dict(&archive, &dictionary_file, threads as usize)
}

#[tauri::command]
fn cmd_recover_mask(archive: String, mask: String, threads: u32) -> Result<String, String> {
    recover_with_mask(&archive, &mask, threads as usize)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            cmd_extract_hash,
            cmd_john_crack,
            cmd_hashcat_crack,
            cmd_recover_dict,
            cmd_recover_mask
        ])
        .run(tauri::generate_context!())
        .expect("啟動 Tauri 失敗");
}
