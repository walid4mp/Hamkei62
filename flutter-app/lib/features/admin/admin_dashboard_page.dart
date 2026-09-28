import 'package:flutter/material.dart';

import 'admin_console_page.dart';
import 'conversation_moderation_center_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static const modules = <({String icon, String title, String subtitle})>[
    (icon: '📊', title: 'Dashboard', subtitle: 'Platform overview'),
    (icon: '👥', title: 'Users', subtitle: 'Accounts and support'),
    (icon: '👤', title: 'Creators', subtitle: 'Verification and controls'),
    (icon: '🎬', title: 'Movies & Series', subtitle: 'Catalog and publishing'),
    (icon: '📺', title: 'Episodes', subtitle: 'Seasons and episodes'),
    (icon: '🔴', title: 'Live', subtitle: 'Rooms and moderation'),
    (icon: '🎁', title: 'Gifts', subtitle: 'Catalog and abuse controls'),
    (icon: '💰', title: 'Payments', subtitle: 'Transactions and refunds'),
    (icon: '💳', title: 'Subscriptions', subtitle: 'Plans and entitlements'),
    (icon: '📢', title: 'Ads & Revenue', subtitle: 'Ads and creator revenue'),
    (icon: '🏆', title: 'XP & Achievements', subtitle: 'Progression'),
    (icon: '👥', title: 'Communities', subtitle: 'Community management'),
    (icon: '💬', title: 'Messenger', subtitle: 'Reports and moderation'),
    (icon: '🔎', title: 'Conversation Review', subtitle: 'Authorized read-only conversation review'),
    (icon: '🚨', title: 'Reports', subtitle: 'User and content reports'),
    (icon: '🛡️', title: 'Moderation', subtitle: 'Safety queues'),
    (icon: '🤖', title: 'AI Usage', subtitle: 'Usage and limits'),
    (icon: '📈', title: 'Analytics', subtitle: 'Platform analytics'),
    (icon: '💸', title: 'Creator Payouts', subtitle: 'Payout review'),
    (icon: '🎟️', title: 'Promotions', subtitle: 'Promotional campaigns'),
    (icon: '🔐', title: 'Admin Roles', subtitle: 'RBAC permissions'),
    (icon: '📜', title: 'Audit Logs', subtitle: 'Administrative activity'),
    (icon: '⚙️', title: 'System Settings', subtitle: 'Platform configuration'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('SocialNova Admin')),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.8,
          ),
          itemCount: modules.length,
          itemBuilder: (_, i) {
            final m = modules[i];
            return Card(
              child: ListTile(
                leading: Text(m.icon, style: const TextStyle(fontSize: 26)),
                title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(m.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (m.title == 'Conversation Review') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationModerationCenterPage()));
                    return;
                  }
                  // V93: the modules that have a real, permission-guarded
                  // backend now open the working console instead of doing
                  // nothing.
                  final tab = switch (m.title) {
                    'Gifts' => 0,
                    'Movies & Series' || 'Episodes' => 3,
                    'Creators' || 'XP & Achievements' => 2,
                    _ => -1,
                  };
                  if (tab < 0) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminConsolePage(initialTab: tab)));
                },
              ),
            );
          },
        ),
      );
}
