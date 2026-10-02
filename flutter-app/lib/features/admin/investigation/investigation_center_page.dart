import 'package:flutter/material.dart';

class InvestigationCenterPage extends StatelessWidget {
  const InvestigationCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Investigation Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('🚨 Suspicious Activity', ['Review security alerts', 'Review recent sign-ins', 'Review active sessions', 'Review account changes']),
          _section('👁️ Evidence (Read-only)', ['Account profile and verification status', 'Allowed security/event logs', 'Reported content', 'Transaction and gift events']),
          _section('🔒 Protective Actions', ['End all sessions', 'Temporarily restrict account', 'Freeze selected features', 'Preserve investigation evidence']),
          _section('📜 Audit Log', ['Record investigator identity', 'Record access time and case ID', 'Record evidence viewed', 'Record administrative actions']),
          const Card(child: ListTile(leading: Icon(Icons.gavel), title: Text('Legal Request'), subtitle: Text('External disclosure requires a verified authorized workflow.'))),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      children: [for (final item in items) ListTile(dense: true, leading: const Icon(Icons.chevron_right), title: Text(item))],
    ),
  );
}
