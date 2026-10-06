import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';

class AdminCenterView extends StatefulWidget {
  const AdminCenterView({super.key});

  @override
  State<AdminCenterView> createState() => _AdminCenterViewState();
}

class _AdminCenterViewState extends State<AdminCenterView> {
  final api = AdminApiService.instance;
  bool loading = true;
  bool signedIn = false;
  String? error;
  Map<String, dynamic>? overview;
  List<dynamic> users = [];
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await api.restore();
    try {
      await api.status();
      signedIn = true;
      await _loadOverview();
    } catch (_) {
      signedIn = false;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadOverview() async {
    final data = await api.get('/api/admin/overview');
    overview = Map<String, dynamic>.from(data as Map);
  }

  Future<void> _login(String login, String password) async {
    setState(() { loading = true; error = null; });
    try {
      await api.login(login, password);
      signedIn = true;
      await _loadOverview();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      signedIn = false;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _logout() async {
    await api.logout();
    if (mounted) setState(() { signedIn = false; overview = null; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return signedIn ? _dashboard() : _loginView();
  }

  Widget _loginView() {
    final login = TextEditingController();
    final password = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('مركز الإدارة')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.admin_panel_settings, size: 64),
                  const SizedBox(height: 14),
                  const Text('SocialNova Admin Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('استخدم حساب الإدارة أو DEVELOPER للدخول.'),
                  const SizedBox(height: 20),
                  TextField(controller: login, decoration: const InputDecoration(labelText: 'البريد أو اسم المستخدم')),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: () => _login(login.text, password.text),
                    icon: const Icon(Icons.login), label: const Text('دخول الإدارة'),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboard() {
    final pages = <Widget>[
      _overviewPage(),
      _usersPage(),
      _contentPage('المنشورات', '/api/admin/posts', 'posts'),
      _contentPage('Reels', '/api/admin/reels', 'reels'),
      _contentPage('Stories', '/api/admin/stories', 'stories'),
      _contentPage('المجموعات', '/api/admin/groups', 'groups'),
      _moderationPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('SocialNova — مركز الإدارة'),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
      ),
      body: Row(children: [
        NavigationRail(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('الرئيسية')),
            NavigationRailDestination(icon: Icon(Icons.people), label: Text('المستخدمون')),
            NavigationRailDestination(icon: Icon(Icons.article), label: Text('المنشورات')),
            NavigationRailDestination(icon: Icon(Icons.movie), label: Text('Reels')),
            NavigationRailDestination(icon: Icon(Icons.circle), label: Text('Stories')),
            NavigationRailDestination(icon: Icon(Icons.groups), label: Text('المجموعات')),
            NavigationRailDestination(icon: Icon(Icons.security), label: Text('الأمان')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: IndexedStack(index: tab, children: pages)),
      ]),
    );
  }

  Widget _overviewPage() {
    final o = overview ?? {};
    return RefreshIndicator(
      onRefresh: () async { await _loadOverview(); if (mounted) setState(() {}); },
      child: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('لوحة المعلومات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _stat('المستخدمون', o['users'] ?? o['userCount'] ?? '—', Icons.people),
          _stat('المنشورات', o['posts'] ?? o['postCount'] ?? '—', Icons.article),
          _stat('Stories', o['stories'] ?? o['storyCount'] ?? '—', Icons.circle),
          _stat('Reels', o['reels'] ?? o['reelCount'] ?? '—', Icons.movie),
          _stat('Live', o['live'] ?? o['liveCount'] ?? '—', Icons.live_tv),
        ]),
        const SizedBox(height: 18),
        Card(child: ListTile(leading: const Icon(Icons.check_circle), title: const Text('الخادم الإداري متصل'), subtitle: Text('${o['serverTime'] ?? ''}'))),
      ]),
    );
  }

  Widget _stat(String title, dynamic value, IconData icon) => SizedBox(
    width: 180, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 28), const SizedBox(height: 12), Text(title), Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]))),
  );

  Future<void> _loadUsers() async {
    final data = await api.get('/api/admin/users');
    users = data is List ? data : [];
  }

  Widget _usersPage() {
    return FutureBuilder<void>(
      future: _loadUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        return RefreshIndicator(onRefresh: () async { await _loadUsers(); if (mounted) setState(() {}); }, child: ListView.builder(
          padding: const EdgeInsets.all(12), itemCount: users.length,
          itemBuilder: (_, i) {
            final u = Map<String, dynamic>.from(users[i] as Map);
            final id = '${u['id'] ?? ''}';
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text((u['displayName'] ?? u['username'] ?? '?').toString().substring(0, 1).toUpperCase())),
              title: Text('${u['displayName'] ?? ''} @${u['username'] ?? ''}'),
              subtitle: Text('${u['email'] ?? ''}\nالدور: ${u['role'] ?? 'USER'}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(onSelected: (action) => _userAction(id, action), itemBuilder: (_) => const [
                PopupMenuItem(value: 'BAN', child: Text('حظر/فك الحظر')),
                PopupMenuItem(value: 'VERIFY', child: Text('توثيق')),
                PopupMenuItem(value: 'FEATURE', child: Text('حساب مميز')),
              ]),
            ));
          },
        ));
      },
    );
  }

  Future<void> _userAction(String id, String action) async {
    try {
      Map<String, dynamic>? current;
      for (final raw in users) {
        final u = Map<String, dynamic>.from(raw as Map);
        if ('${u['id'] ?? ''}' == id) {
          current = u;
          break;
        }
      }
      final value = action == 'BAN' ? !(current?['isBanned'] == true) : true;
      await api.post('/api/admin/managed-users/$id/action', data: {'action': action, 'value': value});
      await _loadUsers();
      if (mounted) setState(() {});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Widget _contentPage(String title, String endpoint, String type) {
    return FutureBuilder<dynamic>(
      future: api.get(endpoint),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final rows = snapshot.data is List ? snapshot.data as List : const [];
        return RefreshIndicator(onRefresh: () async { if (mounted) setState(() {}); }, child: ListView(padding: const EdgeInsets.all(12), children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...rows.map((raw) { final x = Map<String, dynamic>.from(raw as Map); final id = '${x['id']}'; final author = Map<String, dynamic>.from((x['author'] ?? {}) as Map); return Card(child: ListTile(
            title: Text('${author['displayName'] ?? author['username'] ?? ''}'),
            subtitle: Text('${x['caption'] ?? x['name'] ?? x['title'] ?? x['mediaUrl'] ?? ''}'),
            trailing: type == 'reels' ? IconButton(icon: const Icon(Icons.star), onPressed: () => api.patch('/api/admin/reels/$id/feature', data: {'featured': true, 'priority': 100})) : IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await api.delete('/api/admin/$type/$id'); if (mounted) setState(() {}); }),
          )); }).toList(),
        ]));
      },
    );
  }

  Widget _moderationPage() => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('الأمان والإدارة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    _adminAction('طلبات التوثيق', Icons.verified, () => _openList('/api/admin/verification', 'التوثيق')),
    _adminAction('طلبات السحب والمحفظة', Icons.account_balance_wallet, () => _openList('/api/admin/wallet/withdrawals', 'السحب')),
    _adminAction('حالة التخزين والوسائط', Icons.cloud, () => _openStorage()),
    _adminAction('الصلاحيات والحسابات الخاصة', Icons.admin_panel_settings, () => _openList('/api/admin/users', 'الحسابات والصلاحيات')),
  ]);

  Widget _adminAction(String title, IconData icon, VoidCallback onTap) => Card(child: ListTile(leading: Icon(icon), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: onTap));

  Future<void> _openList(String endpoint, String title) async {
    try {
      final data = await api.get(endpoint);
      if (!mounted) return;
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .75, child: ListView(padding: const EdgeInsets.all(18), children: [Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Text(data.toString())]))));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _openStorage() => _openList('/api/admin/storage', 'التخزين والوسائط');
}
