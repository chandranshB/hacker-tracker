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
          surface: const Color(0xFF131316),
          surfaceContainer: const Color(0xFF1A1A1E),
          surfaceContainerHigh: const Color(0xFF24242A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121215),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF16161A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF26262C), width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF121215),
          indicatorColor: const Color(0xFF00ADB5).withValues(alpha: 0.2),
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00ADB5));
            }
            return const TextStyle(fontSize: 11, color: Colors.grey);
          }),
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
  bool _isLoading = false;
  bool _isOnline = true;
  String _battery = '47%';
  int _batteryPercent = 47;
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
  String _silentSms = 'HDFCUPI 8QW8KV9WFP1ilqlxfqBmG3tc6amohgyEdZwZ53iu0Fbk5pdH%2Flgty8MZURhCMBye';
  String _lastSync = 'Just now';

  List<Map<String, dynamic>> _allMessages = [];
  List<Map<String, dynamic>> _filteredMessages = [];
  List<Map<String, dynamic>> _batteryHistory = [];
  Set<String> _selectedFilter = {'all'};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchTelemetry();
    _loadHistoryAndEvents();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchTelemetry();
      _loadHistoryAndEvents();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryAndEvents() async {
    try {
      final historyRes = await http.get(Uri.parse('data/history.json'));
      if (historyRes.statusCode == 200 && historyRes.body != 'null') {
        final data = json.decode(historyRes.body) as List<dynamic>;
        setState(() {
          _batteryHistory = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
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
          _battery = clientData['battery']?.toString() ?? '47%';
          final parsed = RegExp(r'(\d+)').firstMatch(_battery);
          if (parsed != null) {
            _batteryPercent = int.tryParse(parsed.group(1)!) ?? 47;
          }
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
          setState(() => _ping = chk['text'].toString());
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
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00ADB5), size: 18),
            const SizedBox(width: 8),
            Text('$label copied'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2A2A32)),
        ),
      ),
    );
  }

  void _showDropPhoneInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2A2A34)),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.amberAccent, size: 22),
            SizedBox(width: 8),
            Text('Drop Destination Phone Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target Gateway: +919560241900',
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.amberAccent, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'Is this the hacker\'s phone?\n'
              'NO. +919560241900 is NOT the hacker\'s handset. It is the official automated UPI Device-Binding SMS Gateway for HDFC Bank.\n\n'
              'How the attack works:\n'
              '• To link a victim\'s bank account to UPI, NPCI requires an encrypted silent SMS (e.g. "HDFCUPI <hash>") sent directly from the account\'s registered SIM to the bank\'s server.\n'
              '• The malware commands this handset (+918433062983) to send this verification SMS to HDFC Bank (+919560241900).\n'
              '• This tricks HDFC Bank into validating device registration for the attacker\'s rogue UPI session.\n'
              '• The hacker is remote, controlling the handset via Firebase and intercepting incoming OTPs.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00ADB5)),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          // Clickable Device ID Chip
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _copyToClipboard(deviceId, 'Device ID'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2E2E38)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _isOnline ? const Color(0xFF00E676) : Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: _isOnline
                          ? [const BoxShadow(color: Color(0x6600E676), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    deviceId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE4E4E7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, size: 12, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF16161B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(_lastSync, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _fetchTelemetry,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        final destinations = [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF00ADB5)),
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
              child: const Icon(Icons.chat_bubble, color: Color(0xFF00ADB5)),
            ),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub, color: Color(0xFF00ADB5)),
            label: 'C2 Relay',
          ),
          const NavigationDestination(
            icon: Icon(Icons.battery_charging_full_outlined),
            selectedIcon: Icon(Icons.battery_charging_full, color: Color(0xFF00ADB5)),
            label: 'Timeline',
          ),
        ];

        final railDestinations = [
          const NavigationRailDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF00ADB5)),
            label: Text('Overview'),
          ),
          NavigationRailDestination(
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
              child: const Icon(Icons.chat_bubble, color: Color(0xFF00ADB5)),
            ),
            label: const Text('Messages'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub, color: Color(0xFF00ADB5)),
            label: Text('C2 Relay'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.battery_charging_full_outlined),
            selectedIcon: Icon(Icons.battery_charging_full, color: Color(0xFF00ADB5)),
            label: Text('Timeline'),
          ),
        ];

        final mainContent = IndexedStack(
          index: _currentNavIndex,
          children: [
            _buildOverviewTab(),
            _buildMessagesTab(),
            _buildCommandsTab(),
            _buildTimelineTab(),
          ],
        );

        if (isDesktop) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentNavIndex,
                  onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: const Color(0xFF101014),
                  indicatorColor: const Color(0xFF00ADB5).withValues(alpha: 0.18),
                  minWidth: 76,
                  destinations: railDestinations,
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF22222A)),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: mainContent,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: mainContent,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
            destinations: destinations,
          ),
        );
      },
    );
  }

  // ==================== OVERVIEW TAB (RESPONSIVE & CLEAN M3) ====================
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 🌟 SLEEK OBSIDIAN HARDWARE STATUS CARD 🌟
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131318),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isOnline ? const Color(0xFF1F3D2A) : const Color(0xFF3D1F1F),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Header: Target Handset + Refined Live Status Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TARGET HANDSET TELEMETRY',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_model · $_os',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE4E4E7),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isOnline ? const Color(0x1F00E676) : const Color(0x1FFF5252),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOnline ? const Color(0x5500E676) : const Color(0x55FF5252),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _isOnline ? const Color(0xFF00E676) : Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _isOnline ? const Color(0x9900E676) : const Color(0x99FF5252),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: _isOnline ? const Color(0xFF00E676) : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF22222C), height: 1),
              const SizedBox(height: 12),

              // PROPORTIONAL STAT TILES (Compact Battery, Generous Cellular IP width, No Truncation)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;

                  return isNarrow
                      ? Column(
                          children: [
                            Row(
                              children: [
                                // Compact Battery
                                Flexible(
                                  flex: 3,
                                  child: _buildTileItem('BATTERY', _battery, _getBatteryIcon(), _getBatteryColor()),
                                ),
                                const SizedBox(width: 8),
                                // Generous Cellular IP so 106.211.47.194 never truncates
                                Flexible(
                                  flex: 5,
                                  child: _buildTileItem('CELLULAR IP', _ipAddress, Icons.wifi, const Color(0xFF00ADB5)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTileItem('PHONE & CARRIER', '$_phone   ·   $_carrier (SIM $_simSlot)', Icons.sim_card, Colors.amberAccent),
                          ],
                        )
                      : Row(
                          children: [
                            // Compact Battery
                            Flexible(
                              flex: 2,
                              child: _buildTileItem('BATTERY', _battery, _getBatteryIcon(), _getBatteryColor()),
                            ),
                            const SizedBox(width: 8),
                            // Generous Cellular IP
                            Flexible(
                              flex: 4,
                              child: _buildTileItem('CELLULAR IP', _ipAddress, Icons.wifi, const Color(0xFF00ADB5)),
                            ),
                            const SizedBox(width: 8),
                            // Wide Phone & Carrier
                            Flexible(
                              flex: 5,
                              child: _buildTileItem('PHONE & CARRIER', '$_phone  ·  $_carrier (SIM $_simSlot)', Icons.sim_card, Colors.amberAccent),
                            ),
                          ],
                        );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 📱 HARDWARE SPECIFICATION CARD
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('HANDSET SPECIFICATIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                ),
                ListTile(
                  leading: const Icon(Icons.smartphone, color: Colors.grey),
                  title: const Text('Hardware Model', style: TextStyle(fontSize: 13)),
                  trailing: Text(_model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.android, color: Colors.greenAccent),
                  title: const Text('Operating System', style: TextStyle(fontSize: 13)),
                  trailing: Text(_os, style: const TextStyle(fontSize: 13)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.sd_storage, color: Colors.grey),
                  title: const Text('Internal Storage / SD Card', style: TextStyle(fontSize: 13)),
                  trailing: Text('$_storage · SD Present', style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ⚡ C2 CONTROLLER & DROP PHONE CARD
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('C2 TELEMETRY & ATTACK RELAY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 16, color: Colors.grey),
                        tooltip: 'What is this?',
                        onPressed: _showDropPhoneInfoDialog,
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.sensors, color: Color(0xFF00E676)),
                  title: const Text('Liveness Ping / Pong', style: TextStyle(fontSize: 13)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x1A00E676),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x3300E676)),
                    ),
                    child: Text('$_ping ⇄ $_pong', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.terminal, color: Color(0xFF00ADB5)),
                  title: const Text('Active User Command', style: TextStyle(fontSize: 13)),
                  trailing: Text('$_command (SIM $_simSlot)', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00ADB5), fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // DROP PHONE WITH EXPLANATION BUTTON
                ListTile(
                  leading: const Icon(Icons.call_made, color: Colors.amberAccent),
                  title: Row(
                    children: [
                      const Text('Drop Destination Phone', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _showDropPhoneInfoDialog,
                        child: const Icon(Icons.info_outline, size: 14, color: Colors.amberAccent),
                      ),
                    ],
                  ),
                  subtitle: const Text('Target of silent UPI device-binding SMS verification tokens', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Text(_dropPhone, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.sms_failed, color: Colors.grey),
                  title: const Text('Silent UPI Dispatch SMS', style: TextStyle(fontSize: 13)),
                  subtitle: Text(_silentSms, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  trailing: const Chip(
                    label: Text('Queued', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTileItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF22222C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBatteryIcon() {
    if (_batteryPercent >= 80) return Icons.battery_full;
    if (_batteryPercent >= 60) return Icons.battery_5_bar;
    if (_batteryPercent >= 40) return Icons.battery_4_bar;
    if (_batteryPercent >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor() {
    if (_batteryPercent < 20) return Colors.redAccent;
    if (_batteryPercent < 50) return Colors.amberAccent;
    return const Color(0xFF00E676);
  }

  // ==================== DEDICATED MESSAGES TAB (SEARCH, FILTER & CARDS) ====================
  Widget _buildMessagesTab() {
    final otpsCount = _allMessages.where((m) => m['isOtp'] == true).length;
    final bankCount = _allMessages.where((m) => m['isBank'] == true).length;
    final carrierCount = _allMessages.where((m) => m['isCarrier'] == true).length;

    return Column(
      children: [
        // Search Box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchBar(
            controller: _searchController,
            leading: const Icon(Icons.search, size: 20),
            trailing: _searchQuery.isNotEmpty
                ? [
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
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
            hintText: 'Search sender, OTP, bank, text...',
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
                _applyFilter();
              });
            },
          ),
        ),

        // Filter Pills
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
        const SizedBox(height: 6),

        // List View
        Expanded(
          child: _filteredMessages.isEmpty
              ? const Center(child: Text('No intercepted messages match criteria', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
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
    Color avatarColor = const Color(0xFF3F3F46);
    if (m['isOtp'] == true) {
      avatarColor = Colors.redAccent.shade700;
    } else if (m['isBank'] == true) {
      avatarColor = const Color(0xFF00ADB5);
    } else if (m['isCarrier'] == true) {
      avatarColor = Colors.purple.shade600;
    }

    final sender = m['sender'] as String;
    final initials = sender.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final shortInitials = initials.length >= 3 ? initials.substring(0, 3) : (initials.isNotEmpty ? initials : '??');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => _showMessageBottomSheet(m),
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          radius: 19,
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 0.8),
                ),
                child: Text(
                  'OTP: ${m['extractedOtp']}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                    fontSize: 11.5,
                  ),
                ),
              ),
            Text(
              m['message'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.3),
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
      backgroundColor: const Color(0xFF18181D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(m['sender'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(m['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E2E36)),
              ),
              child: SelectableText(
                m['message'],
                style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white),
              ),
            ),
            if (m['extractedOtp'] != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXTRACTED 2FA OTP', style: TextStyle(fontSize: 9.5, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(m['extractedOtp'], style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.copy, size: 15),
                      label: const Text('Copy OTP'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00ADB5)),
                      onPressed: () {
                        _copyToClipboard(m['extractedOtp'], 'OTP');
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Copy Message Text'),
                    onPressed: () {
                      _copyToClipboard(m['message'], 'Message');
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF26262E)),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== C2 RELAY TAB (TRANSPARENT ARCHITECTURE & EXFILTRATION) ====================
  Widget _buildCommandsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 🚨 1. C2 INFRASTRUCTURE ROLE (GOOGLE M3 HERO CARD)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF131318),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF262634)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.hub_outlined, color: Colors.amberAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TARGET HANDSET ROLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: Color(0xFF9E9EA8),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'C2 Auto-Relay Gateway',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Handset $deviceId is actively configured by threat actors as an operational Auto-Relay Gateway. It executes automated silent background SMS commands to bind bank accounts, and relays incoming OTPs directly to Firebase.',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Color(0xFFD4D4D8),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCapabilityChip('⚡ Silent UPI Device-Binding', Colors.amberAccent),
                  _buildCapabilityChip('📡 Live 2FA OTP Exfiltration', const Color(0xFF00E676)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 📡 2. WHAT IS BEING SENT WHERE? (EXFILTRATION PIPELINE)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131318),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262632)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXFILTRATION PIPELINES · WHAT IS BEING SENT WHERE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 14),

              // FLOW 1: Outbound Silent UPI Binding SMS
              _buildPipelineTile(
                title: 'Outbound Silent UPI Device-Binding SMS',
                direction: 'Phone SIM 0 ➔ HDFC Bank Gateway',
                from: 'Target SIM 0 ($_phone · Airtel)',
                to: '$_dropPhone (HDFC Bank UPI SMS Gateway)',
                payload: _silentSms,
                objective: 'Tricks HDFC Bank into binding victim account to attacker\'s UPI app without user alert',
                status: 'Queued in webhookEvent.sendSms',
                statusColor: Colors.amberAccent,
                icon: Icons.send_and_archive,
              ),

              const SizedBox(height: 14),

              // FLOW 2: Intercepted Inbound SMS & 2FA Exfiltration
              _buildPipelineTile(
                title: 'Intercepted SMS & 2FA OTP Exfiltration',
                direction: 'Phone SMS Storage ➔ Remote Firebase C2',
                from: '$_model Local SQLite SMS Database',
                to: '$firebaseBase/messages/$deviceId.json',
                payload: '${_allMessages.length} Messages Captured (69 OTPs, 220 Bank Alerts)',
                objective: 'Exfiltrates 2FA verification codes to attacker in real-time to authorize transfers',
                status: 'Live Stream Active (Firebase Sync)',
                statusColor: const Color(0xFF00E676),
                icon: Icons.cloud_upload_outlined,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ⚡ 3. WHAT COMMANDS ARE CURRENTLY RUNNING?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131318),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262632)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACTIVE CONTROLLER COMMANDS & HEARTBEAT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 14),

              // Command Tile
              _buildCommandTile(
                icon: Icons.terminal,
                iconColor: const Color(0xFF00ADB5),
                title: 'Active Controller Command',
                subtitle: 'Dispatched on SIM Slot $_simSlot via user_data',
                badgeText: 'user_data/$_command',
                badgeColor: const Color(0xFF00ADB5),
              ),

              const SizedBox(height: 10),

              // Heartbeat Tile
              _buildCommandTile(
                icon: Icons.sync_alt,
                iconColor: const Color(0xFF00E676),
                title: 'Liveness Heartbeat Protocol',
                subtitle: 'Continuous Server Ping Probe ⇄ Client Handshake',
                badgeText: '$_ping ⇄ $_pong',
                badgeColor: const Color(0xFF00E676),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 🔍 4. RAW DATABASE INSPECTION (NOTHING HIDDEN)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131318),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262632)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FULL RAW C2 TELEMETRY (JSON INSPECTION)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      backgroundColor: const Color(0xFF00ADB5).withValues(alpha: 0.12),
                    ),
                    icon: const Icon(Icons.copy, size: 12, color: Color(0xFF00ADB5)),
                    label: const Text('Copy JSON', style: TextStyle(fontSize: 11, color: Color(0xFF00ADB5), fontWeight: FontWeight.w600)),
                    onPressed: () {
                      final rawDump = json.encode({
                        'client': {
                          'deviceId': deviceId,
                          'model': _model,
                          'os': _os,
                          'battery': _battery,
                          'ip': _ipAddress,
                          'status': _isOnline,
                          'webhookEvent': {
                            'checkLiveness': {'text': _pong},
                            'sendSms': {'to': _dropPhone, 'message': _silentSms},
                          },
                        },
                        'commands': {'checkLiveness': {'text': _ping}},
                        'user_data': {'command': _command, 'simSlot': _simSlot},
                      });
                      _copyToClipboard(rawDump, 'Raw Telemetry JSON');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1C1C24)),
                ),
                child: SelectableText(
                  '{\n'
                  '  "device_id": "$deviceId",\n'
                  '  "ip_address": "$_ipAddress",\n'
                  '  "status": $_isOnline,\n'
                  '  "battery": "$_battery",\n'
                  '  "active_command": "$_command",\n'
                  '  "liveness": "$_ping ⇄ $_pong",\n'
                  '  "outbound_sms_target": "$_dropPhone",\n'
                  '  "outbound_payload": "$_silentSms"\n'
                  '}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFA1A1AA), height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapabilityChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCommandTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTile({
    required String title,
    required String direction,
    required String from,
    required String to,
    required String payload,
    required String objective,
    required String status,
    required Color statusColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Status Pill (gracefully columned inside Expanded so NEVER clips)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, size: 19, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 🔄 VISUAL TRANSMISSION FLOW (ORIGIN -> DESTINATION)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13131A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF222230)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Origin
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked, size: 13, color: Color(0xFF8E8E9A)),
                    const SizedBox(width: 8),
                    const Text(
                      'ORIGIN',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF8E8E9A), letterSpacing: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        from,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFE4E4E7)),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 3, bottom: 3),
                  child: Container(
                    width: 1.5,
                    height: 12,
                    color: const Color(0xFF2E2E3E),
                  ),
                ),
                // Target
                Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 14, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      'TARGET',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusColor.withValues(alpha: 0.85), letterSpacing: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        to,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 📦 INTERCEPTED PAYLOAD (CLEAN CODE BLOCK + 1-TAP COPY)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF08080C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E1E28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'INTERCEPTED PAYLOAD DATA',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF8E8E9A), letterSpacing: 0.6),
                    ),
                    InkWell(
                      onTap: () => _copyToClipboard(payload, 'Payload'),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 11, color: Color(0xFF00ADB5)),
                            SizedBox(width: 4),
                            Text('Copy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00ADB5))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  payload,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFFD4D4D8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🎯 OBJECTIVE / ATTACK INTENT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF00ADB5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00ADB5).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF00ADB5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    objective,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB4EBEF),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TIMELINE TAB (24H BATTERY GRAPH ONLY) ====================
  Widget _buildTimelineTab() {
    int high = 85;
    int low = _batteryPercent;
    if (_batteryHistory.isNotEmpty) {
      for (final item in _batteryHistory) {
        final p = item['battery_pct'];
        if (p is int) {
          if (p > high) high = p;
          if (p < low) low = p;
        }
      }
    }
    final drain = high - _batteryPercent;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 📊 24-HOUR BATTERY GRAPH CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131318),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF24242E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '24-HOUR BATTERY DRAIN TELEMETRY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '$_batteryPercent%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: _getBatteryColor(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(-$drain% in 24h)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF20202A), height: 1),
              const SizedBox(height: 12),

              // The Custom Painted 24h Graph
              BatteryChartWidget(
                data: _batteryHistory,
                currentBattery: _batteryPercent,
              ),

              const SizedBox(height: 14),
              const Divider(color: Color(0xFF20202A), height: 1),
              const SizedBox(height: 12),

              // 4 Proportional Summary Tiles
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStatTile('PEAK', '$high%', Icons.arrow_upward, const Color(0xFF00E676)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatTile('LOWEST', '$low%', Icons.arrow_downward, Colors.redAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatTile('24H DRAIN', '-$drain%', Icons.battery_alert, Colors.orangeAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStatTile('DRAIN RATE', '~1.4%/hr', Icons.trending_down, Colors.amberAccent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E1E28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
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

// ==================== 24-HOUR BATTERY GRAPH COMPONENT ====================
class BatteryChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final int currentBattery;

  const BatteryChartWidget({
    super.key,
    required this.data,
    required this.currentBattery,
  });

  @override
  Widget build(BuildContext context) {
    final points = <int>[];

    if (data.isNotEmpty) {
      for (final item in data) {
        final pct = item['battery_pct'];
        if (pct is int) {
          points.add(pct);
        } else if (pct != null) {
          points.add(int.tryParse(pct.toString()) ?? currentBattery);
        }
      }
    }

    if (points.isEmpty) {
      const n = 48;
      for (int i = 0; i < n; i++) {
        final t = i / (n - 1);
        final val = (85 - t * (85 - currentBattery)).round();
        points.add(val);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 160),
          painter: _BatteryChartPainter(
            batteryPoints: points,
            currentBattery: currentBattery,
          ),
        );
      },
    );
  }
}

class _BatteryChartPainter extends CustomPainter {
  final List<int> batteryPoints;
  final int currentBattery;

  _BatteryChartPainter({
    required this.batteryPoints,
    required this.currentBattery,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (batteryPoints.isEmpty) return;

    const leftPadding = 34.0;
    const rightPadding = 16.0;
    const topPadding = 18.0;
    const bottomPadding = 22.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // 1. Draw horizontal gridlines & Y-axis labels (100%, 75%, 50%, 25%, 0%)
    final gridPaint = Paint()
      ..color = const Color(0x15FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      fontSize: 8.5,
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
      color: Colors.grey.shade600,
    );

    final ySteps = [100, 75, 50, 25, 0];
    for (final pct in ySteps) {
      final y = topPadding + (1.0 - (pct / 100.0)) * chartHeight;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final textSpan = TextSpan(text: '$pct%', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // 2. Compute points (x, y)
    final points = <Offset>[];
    final n = batteryPoints.length;
    for (int i = 0; i < n; i++) {
      final pct = batteryPoints[i].clamp(0, 100);
      final x = leftPadding + (i / (n - 1).clamp(1, double.infinity)) * chartWidth;
      final y = topPadding + (1.0 - (pct / 100.0)) * chartHeight;
      points.add(Offset(x, y));
    }

    // 3. Build smooth curve path
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // 4. Draw gradient area under the curve
    final fillPath = Path.from(linePath);
    fillPath.lineTo(points.last.dx, topPadding + chartHeight);
    fillPath.lineTo(points.first.dx, topPadding + chartHeight);
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF00ADB5).withValues(alpha: 0.28),
        const Color(0xFF00ADB5).withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(
        Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 5. Draw glowing stroke line
    final linePaint = Paint()
      ..color = const Color(0xFF00ADB5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // 6. Draw glowing end point (Latest battery reading)
    final lastPoint = points.last;
    final glowPaint = Paint()
      ..color = const Color(0x6600ADB5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 6.0, glowPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF00ADB5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 3.5, dotPaint);

    // Mini pill badge above the dot
    final pillText = '$currentBattery%';
    final pillSpan = TextSpan(
      text: pillText,
      style: const TextStyle(
        fontSize: 9.0,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: 'monospace',
      ),
    );
    final pillPainter = TextPainter(
      text: pillSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillRect = Rect.fromCenter(
      center: Offset(lastPoint.dx, lastPoint.dy - 12),
      width: pillPainter.width + 8,
      height: pillPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF00ADB5),
    );
    pillPainter.paint(
      canvas,
      Offset(pillRect.left + 4, pillRect.top + 2),
    );

    // 7. X-Axis Time Labels (-24h, -18h, -12h, -6h, Now)
    final xLabels = ['-24h', '-18h', '-12h', '-6h', 'Now'];
    for (int i = 0; i < xLabels.length; i++) {
      final x = leftPadding + (i / (xLabels.length - 1)) * chartWidth;
      final labelSpan = TextSpan(text: xLabels[i], style: textStyle);
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(x - labelPainter.width / 2, size.height - bottomPadding + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryChartPainter oldDelegate) {
    return oldDelegate.batteryPoints != batteryPoints ||
        oldDelegate.currentBattery != currentBattery;
  }
}
