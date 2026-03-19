const invoke = window.__TAURI__?.core?.invoke;
const logBox = document.getElementById('log');

function log(message) {
  const now = new Date().toLocaleTimeString('zh-TW', { hour12: false });
  logBox.textContent += `[${now}] ${message}\n`;
  logBox.scrollTop = logBox.scrollHeight;
}

async function call(cmd, payload) {
  if (!invoke) {
    log('錯誤：目前不是 Tauri 環境');
    return;
  }
  try {
    log(`執行 ${cmd}...`);
    const result = await invoke(cmd, payload);
    log(result);
  } catch (err) {
    log(`失敗：${err}`);
  }
}

document.getElementById('btnExtract').addEventListener('click', () => {
  call('cmd_extract_hash', {
    archive: document.getElementById('archive').value,
    outFile: document.getElementById('hashOut').value,
    johnDir: document.getElementById('johnDir').value || null,
    perl: document.getElementById('perl').value || null,
  });
});

document.getElementById('btnJohn').addEventListener('click', () => {
  call('cmd_john_crack', {
    hashFile: document.getElementById('johnHashFile').value,
    wordlist: document.getElementById('johnWordlist').value || null,
    john: document.getElementById('johnExe').value || null,
  });
});

document.getElementById('btnHashcat').addEventListener('click', () => {
  call('cmd_hashcat_crack', {
    payload: {
      hash_file: document.getElementById('hcHashFile').value,
      mode: document.getElementById('hcMode').value,
      attack: document.getElementById('hcAttack').value,
      mask: document.getElementById('hcMask').value || null,
      wordlist: document.getElementById('hcWordlist').value || null,
      hashcat: document.getElementById('hcExe').value || null,
      extra: []
    }
  });
});

document.getElementById('btnQuickDict').addEventListener('click', () => {
  call('cmd_recover_dict', {
    archive: document.getElementById('quickArchive').value,
    dictionaryFile: document.getElementById('quickDict').value,
    threads: Number(document.getElementById('quickThreads').value || '8')
  });
});

document.getElementById('btnQuickMask').addEventListener('click', () => {
  call('cmd_recover_mask', {
    archive: document.getElementById('quickArchive').value,
    mask: document.getElementById('quickMask').value,
    threads: Number(document.getElementById('quickThreads').value || '8')
  });
});

log('介面已就緒。');
