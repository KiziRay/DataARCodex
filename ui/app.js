(() => {
  'use strict';

  const invoke = window.__TAURI__?.core?.invoke;
  const SETTINGS_KEY = 'cipherbreak-settings';

  const $ = (id) => document.getElementById(id);
  const logBox = $('log');
  const overlay = $('resultOverlay');
  const resultPwd = $('resultPassword');
  const envBadge = $('envBadge');
  const envBadgeText = envBadge?.querySelector('.badge-text');
  const envBadgeDot = envBadge?.querySelector('.badge-dot');
  const settingsModal = $('settingsModal');

  if (!invoke) {
    setEnvBadge('error', '非 Tauri 環境');
  }

  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((t) => t.classList.remove('active'));
      document.querySelectorAll('.panel').forEach((p) => p.classList.remove('active'));
      tab.classList.add('active');
      const panel = $('panel-' + tab.dataset.tab);
      if (panel) panel.classList.add('active');
    });
  });

  document.querySelectorAll('.mode-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.mode-btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      const m = btn.dataset.mode;
      const dictEl = $('quickDictFields');
      const maskEl = $('quickMaskFields');
      if (dictEl) dictEl.classList.toggle('hidden', m !== 'dict');
      if (maskEl) maskEl.classList.toggle('hidden', m !== 'mask');
    });
  });

  const hcModeEl = $('hcMode');
  const hcModeCustomWrap = $('hcModeCustomWrap');
  if (hcModeEl && hcModeCustomWrap) {
    const syncHcCustom = () => {
      hcModeCustomWrap.classList.toggle('hidden', hcModeEl.value !== 'custom');
    };
    hcModeEl.addEventListener('change', syncHcCustom);
    syncHcCustom();
  }

  const LOG_MAX = 600;
  const ICONS = { info: '\u25b8', success: '\u2713', error: '\u2717', warning: '\u26a0', plain: '\u00b7' };

  function log(message, type) {
    type = type || 'plain';
    if (!logBox) return;
    while (logBox.childElementCount > LOG_MAX) logBox.removeChild(logBox.firstChild);

    const time = new Date().toLocaleTimeString('zh-TW', { hour12: false });
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML =
      '<span class="log-time">' +
      esc(time) +
      '</span>' +
      '<span class="log-msg ' +
      esc(type) +
      '">' +
      (ICONS[type] ? esc(ICONS[type]) + ' ' : '') +
      esc(message) +
      '</span>';
    logBox.appendChild(entry);
    logBox.scrollTop = logBox.scrollHeight;
  }

  function esc(s) {
    const d = document.createElement('span');
    d.textContent = s;
    return d.innerHTML;
  }

  function setEnvBadge(state, text) {
    if (!envBadge || !envBadgeText || !envBadgeDot) return;
    envBadgeText.textContent = text;
    const map = {
      success: { color: '#10b981', bg: 'rgba(16,185,129,.1)', border: 'rgba(16,185,129,.22)' },
      warning: { color: '#f59e0b', bg: 'rgba(245,158,11,.1)', border: 'rgba(245,158,11,.22)' },
      error: { color: '#ef4444', bg: 'rgba(239,68,68,.1)', border: 'rgba(239,68,68,.22)' },
      idle: { color: '#94a3b8', bg: 'rgba(148,163,184,.08)', border: 'rgba(148,163,184,.18)' }
    };
    const style = map[state] || map.idle;
    envBadge.style.color = style.color;
    envBadge.style.background = style.bg;
    envBadge.style.borderColor = style.border;
    envBadgeDot.style.background = style.color;
  }

  function effectivePath(a, b) {
    if (a && a.trim()) return a.trim();
    if (b && b.trim()) return b.trim();
    return null;
  }

  async function checkEnvironment() {
    if (!invoke) return;

    setEnvBadge('idle', '檢查中…');
    try {
      const payload = {
        johnDir: effectivePath($('johnDir')?.value, $('setJohnDir')?.value),
        john: effectivePath($('johnExe')?.value, $('setJohnExe')?.value),
        hashcat: effectivePath($('hcExe')?.value, $('setHashcatExe')?.value),
        perl: effectivePath($('perl')?.value, $('setPerl')?.value)
      };

      const checks = await invoke('cmd_check_environment', { payload });
      if (!Array.isArray(checks) || checks.length === 0) {
        setEnvBadge('warning', '狀態未知');
        log('環境檢查未回傳有效結果', 'warning');
        return;
      }

      const coreKeys = ['seven_zip', 'john'];
      const coreFailures = checks.filter((item) => coreKeys.includes(item.key) && !item.available);
      const available = checks.filter((item) => item.available).length;
      const total = checks.length;

      if (coreFailures.length > 0) {
        setEnvBadge('error', `核心缺失 ${available}/${total}`);
      } else if (available < total) {
        setEnvBadge('warning', `部分可用 ${available}/${total}`);
      } else {
        setEnvBadge('success', `環境就緒 ${available}/${total}`);
      }

      const summary = checks.map((item) => `${item.available ? 'OK' : '—'} ${item.label}`).join(' · ');
      log(`環境：${summary}`, coreFailures.length ? 'warning' : 'success');
    } catch (err) {
      setEnvBadge('error', '檢查失敗');
      log('環境檢查失敗: ' + err, 'error');
    }
  }

  async function run(cmd, payload, btn) {
    if (!invoke) {
      log('目前不在 Tauri 環境中，無法執行', 'error');
      return null;
    }

    if (btn) btn.classList.add('loading');
    log('執行 ' + cmd + ' …', 'info');

    try {
      const result = await invoke(cmd, { payload: payload || {} });

      if (result && result.indexOf('password:') !== -1) {
        const pwd = result.split('password:')[1].trim().split('\n')[0];
        log('密碼已找到: ' + pwd, 'success');
        showOverlay(pwd);
      } else if (result && result.indexOf('not_found') !== -1) {
        log('搜尋完畢，未找到密碼', 'warning');
      } else {
        log(result || '完成', 'success');
      }
      return result;
    } catch (err) {
      log('失敗: ' + err, 'error');
      return null;
    } finally {
      if (btn) btn.classList.remove('loading');
    }
  }

  function showOverlay(pwd) {
    if (!overlay || !resultPwd) return;
    resultPwd.textContent = pwd;
    overlay.classList.remove('hidden');
  }

  $('btnCloseOverlay')?.addEventListener('click', () => overlay?.classList.add('hidden'));

  $('btnCopyPwd')?.addEventListener('click', () => {
    if (resultPwd?.textContent) {
      navigator.clipboard.writeText(resultPwd.textContent);
      log('密碼已複製到剪貼簿', 'success');
    }
  });

  overlay?.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.classList.add('hidden');
  });

  $('btnClearLog')?.addEventListener('click', () => {
    if (logBox) logBox.innerHTML = '';
    log('日誌已清除');
  });

  $('btnCopyLog')?.addEventListener('click', () => {
    if (logBox) {
      navigator.clipboard.writeText(logBox.innerText);
      log('日誌已複製', 'success');
    }
  });

  function openSettings() {
    settingsModal?.classList.remove('hidden');
  }
  function closeSettings() {
    settingsModal?.classList.add('hidden');
  }

  $('btnSettings')?.addEventListener('click', openSettings);
  $('btnCloseSettings')?.addEventListener('click', closeSettings);
  settingsModal?.querySelector('.modal-backdrop')?.addEventListener('click', closeSettings);

  function loadSettings() {
    try {
      return JSON.parse(localStorage.getItem(SETTINGS_KEY)) || {};
    } catch {
      return {};
    }
  }

  function saveSettings(obj) {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(obj));
  }

  function applySettings() {
    const s = loadSettings();
    const fill = (settingsId, targetId) => {
      const val = s[settingsId];
      if (!val) return;
      const setEl = $(settingsId);
      if (setEl) setEl.value = val;
      const tgt = $(targetId);
      if (tgt && !tgt.value) tgt.value = val;
    };

    fill('setJohnDir', 'johnDir');
    fill('setJohnExe', 'johnExe');
    fill('setHashcatExe', 'hcExe');
    fill('setPerl', 'perl');

    if (s.setThreads) {
      const st = $('setThreads');
      const qt = $('quickThreads');
      if (st) st.value = s.setThreads;
      if (qt && (!qt.value || qt.value === '8')) qt.value = s.setThreads;
    }
  }

  $('btnSaveSettings')?.addEventListener('click', () => {
    const obj = {
      setJohnDir: $('setJohnDir')?.value || '',
      setJohnExe: $('setJohnExe')?.value || '',
      setHashcatExe: $('setHashcatExe')?.value || '',
      setPerl: $('setPerl')?.value || '',
      setThreads: $('setThreads')?.value || '8'
    };
    saveSettings(obj);
    applySettings();
    log('設定已儲存', 'success');
    closeSettings();
    checkEnvironment();
  });

  async function pickFileInto(inputId) {
    if (!invoke) return;
    try {
      const path = await invoke('cmd_pick_file', {});
      if (path && $(inputId)) $(inputId).value = path;
    } catch (e) {
      log('選擇檔案失敗: ' + e, 'error');
    }
  }

  async function pickFolderInto(inputId) {
    if (!invoke) return;
    try {
      const path = await invoke('cmd_pick_folder', {});
      if (path && $(inputId)) $(inputId).value = path;
    } catch (e) {
      log('選擇資料夾失敗: ' + e, 'error');
    }
  }

  async function pickSaveHash() {
    if (!invoke) return;
    try {
      const path = await invoke('cmd_pick_save_file', {});
      if (path && $('hashOut')) $('hashOut').value = path;
    } catch (e) {
      log('另存失敗: ' + e, 'error');
    }
  }

  const browseMap = [
    ['btnBrowseArchive', () => pickFileInto('archive')],
    ['btnBrowseHashOut', () => pickSaveHash()],
    ['btnBrowseJohnDir', () => pickFolderInto('johnDir')],
    ['btnBrowsePerl', () => pickFileInto('perl')],
    ['btnBrowseJohnHash', () => pickFileInto('johnHashFile')],
    ['btnBrowseJohnWordlist', () => pickFileInto('johnWordlist')],
    ['btnBrowseJohnExe', () => pickFileInto('johnExe')],
    ['btnBrowseHcHash', () => pickFileInto('hcHashFile')],
    ['btnBrowseHcWordlist', () => pickFileInto('hcWordlist')],
    ['btnBrowseHcExe', () => pickFileInto('hcExe')],
    ['btnBrowseQuickArchive', () => pickFileInto('quickArchive')],
    ['btnBrowseQuickDict', () => pickFileInto('quickDict')]
  ];

  browseMap.forEach(([id, fn]) => {
    $(id)?.addEventListener('click', fn);
  });

  $('btnExtract')?.addEventListener('click', async () => {
    const archive = $('archive')?.value.trim();
    if (!archive) {
      log('請輸入或選擇壓縮檔', 'error');
      return;
    }

    const result = await run(
      'cmd_extract_hash',
      {
        archive: archive,
        outFile: $('hashOut')?.value.trim() || 'hash.txt',
        johnDir: $('johnDir')?.value.trim() || null,
        perl: $('perl')?.value.trim() || null
      },
      $('btnExtract')
    );

    if (result && result.indexOf('hash_file:') !== -1) {
      const hf = result.split('hash_file:')[1].trim().split('\n')[0];
      if (!$('johnHashFile')?.value) $('johnHashFile').value = hf;
      if (!$('hcHashFile')?.value) $('hcHashFile').value = hf;
      log('已自動填入 John / Hashcat 的 Hash 路徑', 'info');
    }
  });

  $('btnJohn')?.addEventListener('click', () => {
    const hashFile = $('johnHashFile')?.value.trim();
    if (!hashFile) {
      log('請輸入 Hash 檔案路徑', 'error');
      return;
    }

    run(
      'cmd_john_crack',
      {
        hashFile: hashFile,
        wordlist: $('johnWordlist')?.value.trim() || null,
        john: $('johnExe')?.value.trim() || null
      },
      $('btnJohn')
    );
  });

  $('btnHashcat')?.addEventListener('click', () => {
    const hashFile = $('hcHashFile')?.value.trim();
    if (!hashFile) {
      log('請輸入 Hash 檔案路徑', 'error');
      return;
    }

    let mode = $('hcMode')?.value;
    if (mode === 'custom') {
      mode = $('hcModeCustom')?.value.trim();
      if (!mode) {
        log('請輸入自訂模式編號', 'error');
        return;
      }
    }

    run(
      'cmd_hashcat_crack',
      {
        hash_file: hashFile,
        mode: mode,
        attack: $('hcAttack')?.value,
        mask: $('hcMask')?.value.trim() || null,
        wordlist: $('hcWordlist')?.value.trim() || null,
        hashcat: $('hcExe')?.value.trim() || null,
        extra: []
      },
      $('btnHashcat')
    );
  });

  $('btnQuick')?.addEventListener('click', () => {
    const archive = $('quickArchive')?.value.trim();
    if (!archive) {
      log('請輸入壓縮檔路徑', 'error');
      return;
    }

    const isDict = document.querySelector('.mode-btn.active')?.dataset.mode === 'dict';

    if (isDict) {
      const dict = $('quickDict')?.value.trim();
      if (!dict) {
        log('請輸入字典檔路徑', 'error');
        return;
      }
      run(
        'cmd_recover_dict',
        {
          archive: archive,
          dictionaryFile: dict,
          threads: Number($('quickThreads')?.value) || 8
        },
        $('btnQuick')
      );
    } else {
      const mask = $('quickMask')?.value.trim();
      if (!mask) {
        log('請輸入遮罩', 'error');
        return;
      }
      run(
        'cmd_recover_mask',
        {
          archive: archive,
          mask: mask,
          threads: Number($('quickThreads')?.value) || 8
        },
        $('btnQuick')
      );
    }
  });

  if (envBadge) {
    envBadge.style.cursor = 'pointer';
    envBadge.title = '點擊重新檢查工具環境';
    envBadge.addEventListener('click', checkEnvironment);
  }

  applySettings();
  checkEnvironment();
  log('CipherBreak 已就緒', 'success');
})();
