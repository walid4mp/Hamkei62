import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Nova TV — the entertainment hub: Movies, Series (with seasons & episodes)
/// and Continue Watching. All data comes from the existing content API.
class NovaTvPage extends StatefulWidget {
  const NovaTvPage({super.key});
  @override
  State<NovaTvPage> createState() => _NovaTvPageState();
}

class _NovaTvPageState extends State<NovaTvPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova TV', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: SN.violet,
          tabs: const [Tab(text: 'أفلام'), Tab(text: 'مسلسلات'), Tab(text: 'متابعة')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_MoviesTab(), _SeriesTab(), _ContinueTab()],
      ),
    );
  }
}

class _MoviesTab extends StatelessWidget {
  const _MoviesTab();
  @override
  Widget build(BuildContext context) => _ContentGrid(
        loader: () async => List<dynamic>.from(await Api.movies()),
        emptyText: 'لا توجد أفلام منشورة بعد',
        onTap: (row) => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(id: '${row['id']}'))),
      );
}

class _SeriesTab extends StatelessWidget {
  const _SeriesTab();
  @override
  Widget build(BuildContext context) => _ContentGrid(
        loader: () async => List<dynamic>.from(await Api.series()),
        emptyText: 'لا توجد مسلسلات منشورة بعد',
        onTap: (row) => Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailPage(id: '${row['id']}'))),
      );
}

class _ContentGrid extends StatefulWidget {
  const _ContentGrid({required this.loader, required this.emptyText, required this.onTap});
  final Future<List<dynamic>> Function() loader;
  final String emptyText;
  final void Function(Map<String, dynamic> row) onTap;
  @override
  State<_ContentGrid> createState() => _ContentGridState();
}

class _ContentGridState extends State<_ContentGrid> with AutomaticKeepAliveClientMixin {
  late Future<List<dynamic>> _future = widget.loader();
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = widget.loader()),
            child: ListView(children: [SizedBox(height: 180, child: Center(child: Text(widget.emptyText, style: TextStyle(color: SN.textMut))))]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = widget.loader()),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .62),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final row = Map<String, dynamic>.from(rows[i] as Map);
              final poster = '${row['posterUrl'] ?? row['poster'] ?? ''}';
              return GestureDetector(
                onTap: () => widget.onTap(row),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: poster.isEmpty
                          ? Container(color: SN.bg2, alignment: Alignment.center, child: const Icon(Icons.movie_outlined, color: Colors.white24, size: 34))
                          : Image.network(poster, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: SN.bg2, alignment: Alignment.center, child: const Icon(Icons.movie_outlined, color: Colors.white24, size: 34))),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${row['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(_meta(row), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: SN.textMut, fontSize: 10)),
                ]),
              );
            },
          ),
        );
      },
    );
  }

  String _meta(Map<String, dynamic> row) {
    final year = '${row['year'] ?? ''}';
    final rating = row['rating'];
    final parts = <String>[];
    if (year.isNotEmpty && year != 'null') parts.add(year);
    if (rating != null && '$rating' != 'null') parts.add('★ $rating');
    return parts.isEmpty ? 'Nova TV' : parts.join(' • ');
  }
}

class _ContinueTab extends StatefulWidget {
  const _ContinueTab();
  @override
  State<_ContinueTab> createState() => _ContinueTabState();
}

class _ContinueTabState extends State<_ContinueTab> with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _future = _load();
  @override
  bool get wantKeepAlive => true;

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Api.continueWatching();
    final out = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final p = Map<String, dynamic>.from(raw as Map);
      try {
        final meta = p['kind'] == 'MOVIE' ? await Api.movie('${p['contentId']}') : await Api.episode('${p['episodeId']}');
        out.add({...p, 'meta': meta});
      } catch (_) {
        out.add(p);
      }
    }
    return out;
  }

  String _progressLabel(Map<String, dynamic> p) {
    final pos = (p['positionSec'] as num?)?.toInt() ?? 0;
    final dur = (p['durationSec'] as num?)?.toInt() ?? 0;
    String fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    if (dur > 0) {
      final pct = ((pos / dur) * 100).clamp(0, 100).toInt();
      return '${fmt(pos)} / ${fmt(dur)} • $pct%';
    }
    return fmt(pos);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return Center(child: Text('لا يوجد محتوى قيد المتابعة', style: TextStyle(color: SN.textMut)));
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final p = rows[i];
              final meta = p['meta'] is Map ? Map<String, dynamic>.from(p['meta'] as Map) : <String, dynamic>{};
              final title = '${meta['title'] ?? 'محتوى'}';
              final poster = '${meta['posterUrl'] ?? meta['thumbnailUrl'] ?? ''}';
              return Card(
                color: SN.bg2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: poster.isEmpty ? Container(width: 46, height: 62, color: SN.bg3, child: const Icon(Icons.play_circle_outline, color: Colors.white38)) : Image.network(poster, width: 46, height: 62, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 46, height: 62, color: SN.bg3, child: const Icon(Icons.play_circle_outline, color: Colors.white38)))),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_progressLabel(p), style: TextStyle(color: SN.textMut, fontSize: 11)),
                  trailing: const Icon(Icons.play_arrow_rounded, color: SN.violet),
                  onTap: () {
                    final kind = '${p['kind']}';
                    final id = kind == 'MOVIE' ? '${p['contentId']}' : '${p['episodeId']}';
                    Navigator.push(context, MaterialPageRoute(builder: (_) => _PlayerPage(kind: kind, id: id, title: title, startAtSec: (p['positionSec'] as num?)?.toInt() ?? 0))).then((_) => setState(() => _future = _load()));
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({super.key, required this.id});
  final String id;
  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late Future<Map<String, dynamic>> _future = Api.movie(widget.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          final m = snap.data ?? const <String, dynamic>{};
          final backdrop = '${m['backdropUrl'] ?? m['backdrop'] ?? m['posterUrl'] ?? ''}';
          final poster = '${m['posterUrl'] ?? ''}';
          final duration = (m['durationSec'] as num?)?.toInt() ?? 0;
          final genres = (m['genres'] is List) ? (m['genres'] as List).join(' • ') : '${m['genres'] ?? ''}';
          final cast = (m['cast'] is List) ? (m['cast'] as List).join('، ') : '${m['cast'] ?? ''}';
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: backdrop.isEmpty
                    ? Container(color: SN.bg2)
                    : Image.network(backdrop, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: SN.bg2)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate([
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (poster.isNotEmpty)
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(poster, width: 92, height: 132, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['title'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text([if ('${m['year'] ?? ''}'.isNotEmpty) '${m['year']}', if (duration > 0) '${duration ~/ 60} د', if ('${m['rating'] ?? ''}' != 'null' && '${m['rating'] ?? ''}'.isNotEmpty) '★ ${m['rating']}'].join(' • '), style: TextStyle(color: SN.textMut, fontSize: 12)),
                    if (genres.isNotEmpty) ...[const SizedBox(height: 6), Text(genres, style: TextStyle(color: SN.cyan, fontSize: 12))],
                  ])),
                ]),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PlayerPage(kind: 'MOVIE', id: widget.id, title: '${m['title'] ?? ''}'))),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('مشاهدة'),
                ),
                if ('${m['description'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('القصة', style: TextStyle(color: SN.textMut, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${m['description']}', style: const TextStyle(height: 1.6)),
                ],
                if (cast.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('طاقم العمل', style: TextStyle(color: SN.textMut, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(cast),
                ],
              ])),
            ),
          ]);
        },
      ),
    );
  }
}

class SeriesDetailPage extends StatefulWidget {
  const SeriesDetailPage({super.key, required this.id});
  final String id;
  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  late Future<Map<String, dynamic>> _future = Api.seriesOne(widget.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسلسل')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          final s = snap.data ?? const <String, dynamic>{};
          final seasons = (s['seasons'] as List?) ?? const [];
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${s['title'] ?? ''}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text([if ('${s['year'] ?? ''}'.isNotEmpty) '${s['year']}', if ('${s['rating'] ?? ''}' != 'null' && '${s['rating'] ?? ''}'.isNotEmpty) '★ ${s['rating']}'].join(' • '), style: TextStyle(color: SN.textMut, fontSize: 12)),
            if ('${s['description'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 10), Text('${s['description']}', style: const TextStyle(height: 1.6))],
            const SizedBox(height: 16),
            Text('المواسم', style: TextStyle(color: SN.textMut, fontWeight: FontWeight.w800)),
            for (final raw in seasons)
              if (raw is Map)
                _SeasonBlock(season: Map<String, dynamic>.from(raw), seriesTitle: '${s['title'] ?? ''}'),
          ]);
        },
      ),
    );
  }
}

class _SeasonBlock extends StatefulWidget {
  const _SeasonBlock({required this.season, required this.seriesTitle});
  final Map<String, dynamic> season;
  final String seriesTitle;
  @override
  State<_SeasonBlock> createState() => _SeasonBlockState();
}

class _SeasonBlockState extends State<_SeasonBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final episodes = (widget.season['episodes'] as List?) ?? const [];
    return Card(
      color: SN.bg2,
      margin: const EdgeInsets.only(top: 10),
      child: Column(children: [
        ListTile(
          title: Text('الموسم ${widget.season['number'] ?? ''}${'${widget.season['title'] ?? ''}'.isEmpty ? '' : ' — ${widget.season['title']}'} ', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${episodes.length} حلقة', style: TextStyle(color: SN.textMut, fontSize: 11)),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          for (final raw in episodes)
            if (raw is Map)
              ListTile(
                dense: true,
                leading: Text('${raw['number'] ?? ''}', style: TextStyle(color: SN.textMut)),
                title: Text('${raw['title'] ?? 'حلقة'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.play_circle_outline, color: SN.violet, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PlayerPage(kind: 'EPISODE', id: '${raw['id']}', title: '${raw['title'] ?? widget.seriesTitle}'))),
              ),
      ]),
    );
  }
}

/// Simple player that resumes from the saved position and writes progress back
/// so "Continue watching" restarts exactly where the user left off.
class _PlayerPage extends StatefulWidget {
  const _PlayerPage({required this.kind, required this.id, required this.title, this.startAtSec = 0});
  final String kind;
  final String id;
  final String title;
  final int startAtSec;
  @override
  State<_PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<_PlayerPage> {
  VideoPlayerController? _controller;
  Timer? _ticker;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final access = await Api.contentView(widget.kind, widget.id);
      final url = '${access['videoUrl'] ?? ''}';
      if (url.isEmpty) throw 'VIDEO_UNAVAILABLE';
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (widget.startAtSec > 0) await c.seekTo(Duration(seconds: widget.startAtSec));
      await c.play();
      if (!mounted) { c.dispose(); return; }
      setState(() => _controller = c);
      _ticker = Timer.periodic(const Duration(seconds: 8), (_) => _save());
      c.addListener(() {
        if (!_saved && c.value.isInitialized && c.value.duration.inSeconds > 0 && c.value.position.inSeconds >= c.value.duration.inSeconds - 2) {
          _saved = true;
          Api.saveProgress(kind: widget.kind, contentId: widget.kind == 'MOVIE' ? widget.id : '', episodeId: widget.kind == 'EPISODE' ? widget.id : '', positionSec: c.value.duration.inSeconds, durationSec: c.value.duration.inSeconds, completed: true).catchError((_) {});
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _save() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    Api.saveProgress(
      kind: widget.kind,
      contentId: widget.kind == 'MOVIE' ? widget.id : '',
      episodeId: widget.kind == 'EPISODE' ? widget.id : '',
      positionSec: c.value.position.inSeconds,
      durationSec: c.value.duration.inSeconds,
      completed: false,
    ).catchError((_) {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _save();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: _error != null
            ? Padding(padding: const EdgeInsets.all(24), child: Text('تعذّر تشغيل الفيديو: $_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)))
            : c == null
                ? const CircularProgressIndicator(color: SN.violet)
                : AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c)),
      ),
    );
  }
}
