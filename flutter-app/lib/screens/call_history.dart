import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Formats a call duration as m:ss (or h:mm:ss). Zero means unanswered.
String formatCallDuration(int seconds) {
  if (seconds <= 0) return '—';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// SocialNova V93 — real call history.
///
/// Reads `GET /api/calls/history`, which is backed by the `Call` table written
/// by both the socket signals and the REST lifecycle. Shows direction,
/// outcome (answered / rejected / missed), duration and the peer, and can call
/// back with one tap.
class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.callHistory();
  }

  Future<void> _reload() async {
    setState(() => _future = Api.callHistory());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SN.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('سجل المكالمات'),
        actions: [
          IconButton(tooltip: 'تحديث', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        color: SN.violet,
        onRefresh: _reload,
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', '')),
                ],
              );
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  const EmptyState(text: 'لا توجد مكالمات بعد'),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final c = Map<String, dynamic>.from(rows[i] as Map);
                final peer = c['peer'] is Map ? Map<String, dynamic>.from(c['peer'] as Map) : <String, dynamic>{};
                final outgoing = '${c['direction']}' == 'OUTGOING';
                final missed = c['missed'] == true || '${c['status']}' == 'MISSED';
                final rejected = '${c['status']}' == 'REJECTED';
                final video = '${c['kind']}' == 'VIDEO';
                final duration = (c['durationSec'] as num?)?.toInt() ?? 0;
                final color = missed ? SN.red : (outgoing ? SN.cyan : SN.violet);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: .18),
                    child: Icon(
                      video ? Icons.videocam_rounded : Icons.call_rounded,
                      color: color,
                    ),
                  ),
                  title: Row(
                    children: [
                      Icon(outgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
                          size: 14, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${peer['displayName'] ?? peer['username'] ?? 'مستخدم'}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${missed ? 'مكالمة فائتة' : rejected ? 'مرفوضة' : (outgoing ? 'صادرة' : 'واردة')}'
                    '${duration > 0 ? '  •  ${formatCallDuration(duration)}' : ''}',
                    style: TextStyle(color: missed ? SN.red : SN.textMut, fontSize: 12),
                  ),
                  trailing: peer.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'إعادة الاتصال',
                          icon: const Icon(Icons.phone_in_talk_rounded),
                          onPressed: () async {
                            try {
                              final call = await Api.startCall(
                                receiverId: '${peer['id']}',
                                kind: video ? 'VIDEO' : 'AUDIO',
                              );
                              if (!context.mounted) return;
                              _toast(context, 'تم بدء مكالمة: ${call['roomName']}');
                              await _reload();
                            } catch (e) {
                              if (context.mounted) {
                                _toast(context, 'تعذّر بدء المكالمة: ${e.toString().replaceFirst('Exception: ', '')}');
                              }
                            }
                          },
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}
