import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/localization.dart';

/// In-app music catalog picker. Only tracks that the SocialNova backend marks
/// as licensed/available are playable and selectable.
Future<Map<String, dynamic>?> openMusicPicker(BuildContext context, {String? selectedId}) async {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SN.bg1,
    builder: (_) => _MusicPicker(selectedId: selectedId),
  );
}

class _MusicPicker extends StatefulWidget {
  const _MusicPicker({this.selectedId});
  final String? selectedId;
  @override State<_MusicPicker> createState() => _MusicPickerState();
}

class _MusicPickerState extends State<_MusicPicker> {
  final search = TextEditingController();
  final player = AudioPlayer();
  List<Map<String, dynamic>> tracks = [];
  bool loading = true;
  String? playingId;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await Api.music(search: search.text.trim());
      if (!mounted) return;
      setState(() {
        tracks = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _preview(Map<String, dynamic> t) async {
    final id = '${t['id'] ?? ''}';
    final url = '${t['audioUrl'] ?? ''}'.trim();
    if (url.isEmpty || t['licensed'] != true) return;
    try {
      if (playingId == id) {
        await player.stop();
        if (mounted) setState(() => playingId = null);
        return;
      }
      await player.setUrl(url);
      await player.play();
      if (mounted) setState(() => playingId = id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.t('تعذر تشغيل المعاينة'))));
    }
  }

  @override
  void dispose() {
    search.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(L10n.t('🎵 موسيقى SocialNova'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(hintText: 'ابحث عن أغنية أو فنان', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded))),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (final x in ['الأكثر استخدامًا', 'جزائرية', 'عربية', 'أجنبية'])
                Padding(padding: const EdgeInsetsDirectional.only(end: 7), child: ActionChip(label: Text(x), onPressed: () { search.text = x == 'الأكثر استخدامًا' ? '' : x; _load(); })),
            ])),
            const SizedBox(height: 8),
            Expanded(child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 10), FilledButton(onPressed: _load, child: const Text('إعادة المحاولة'))]))
                    : tracks.isEmpty
                        ? Center(child: Text(L10n.t('لا توجد موسيقى متاحة حاليًا.\nسيظهر هنا الكتالوج المرخّص عند إضافته.'), textAlign: TextAlign.center))
                        : ListView.separated(
                            itemCount: tracks.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final t = tracks[i];
                              final id = '${t['id'] ?? ''}';
                              final available = t['licensed'] == true && '${t['audioUrl'] ?? ''}'.isNotEmpty;
                              final selected = widget.selectedId == id;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: CircleAvatar(backgroundImage: '${t['coverUrl'] ?? ''}'.isNotEmpty ? NetworkImage('${t['coverUrl']}') : null, child: '${t['coverUrl'] ?? ''}'.isEmpty ? const Icon(Icons.music_note) : null),
                                title: Text('${t['title'] ?? 'بدون عنوان'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${t['artist'] ?? 'SocialNova'}${t['category'] != null && '${t['category']}'.isNotEmpty ? ' • ${t['category']}' : ''}'),
                                trailing: available
                                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(onPressed: () => _preview(t), icon: Icon(playingId == id ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded)),
                                        IconButton(onPressed: () { player.stop(); Navigator.pop(context, t); }, icon: Icon(selected ? Icons.check_circle : Icons.add_circle_outline, color: selected ? SN.cyan : null)),
                                      ])
                                    : const Text('غير متاح', style: TextStyle(fontSize: 11, color: Colors.white54)),
                              );
                            },
                          ),
            ),
            const SizedBox(height: 5),
            const Text('الموسيقى داخل التطبيق متاحة فقط عندما تكون مرخّصة أو مملوكة لـ SocialNova.', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
