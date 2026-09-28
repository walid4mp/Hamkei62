import 'package:flutter/material.dart';
import '../../core/api.dart';

class ConversationModerationCenterPage extends StatefulWidget {
  const ConversationModerationCenterPage({super.key});
  @override
  State<ConversationModerationCenterPage> createState() => _ConversationModerationCenterPageState();
}

class _ConversationModerationCenterPageState extends State<ConversationModerationCenterPage> {
  final user = TextEditingController();
  final peer = TextEditingController();
  bool busy = false;
  Map<String, dynamic>? data;
  String? error;

  Future<void> load() async {
    if (user.text.trim().isEmpty || peer.text.trim().isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final result = await Api.adminConversation(user.text.trim(), peer.text.trim());
      if (!mounted) return;
      setState(() => data = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { user.dispose(); peer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final messages = List<dynamic>.from(data?['messages'] ?? const []);
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation Moderation Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💬 مراجعة محادثة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('الوصول مخصص للمشرفين المصرح لهم، وكل عملية فتح تُسجل في Audit Log.'),
            const SizedBox(height: 14),
            TextField(controller: user, decoration: const InputDecoration(labelText: 'User ID', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 10),
            TextField(controller: peer, decoration: const InputDecoration(labelText: 'Peer User ID', prefixIcon: Icon(Icons.person_search_outlined))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : load, icon: const Icon(Icons.search), label: Text(busy ? 'جارٍ التحميل...' : 'عرض المحادثة'))),
          ]))),
          if (error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline), title: const Text('تعذر تحميل المحادثة'), subtitle: Text(error!))),
          if (data != null) ...[
            const SizedBox(height: 8),
            Card(child: ListTile(leading: const Icon(Icons.security), title: Text('${messages.length} رسالة'), subtitle: const Text('وضع مراجعة فقط • لا يمكن إرسال أو تعديل الرسائل'))),
            const SizedBox(height: 8),
            for (final m in messages) Card(
              child: ListTile(
                leading: Icon(m['secret'] == true ? Icons.lock_outline : Icons.chat_bubble_outline),
                title: Text('${m['senderId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${m['body'] ?? ''}'),
                trailing: Text('${m['createdAt'] ?? ''}', style: const TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
