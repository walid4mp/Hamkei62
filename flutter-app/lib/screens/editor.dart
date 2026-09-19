import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'music_picker.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Shared pre-publish editor for posts and reels. It keeps the original media
/// intact and stores the presentation choices (rotation, title, overlays,
/// music and hashtags) with the publication.
Future<Map<String, dynamic>?> openPublishEditor(
  BuildContext context, {
  required String mediaPath,
  required String mediaType,
  String initialCaption = '',
  String initialTitle = '',
  String initialMusic = '',
  String initialMusicUrl = '',
  String initialOverlayText = '',
  String initialOverlayEmoji = '',
  String initialOverlayImageUrl = '',
  int initialRotation = 0,
  String? existingId,
  bool reel = false,
}) async {
  final caption = TextEditingController(text: initialCaption);
  final title = TextEditingController(text: initialTitle);
  final music = TextEditingController(text: initialMusic);
  var musicUrl = initialMusicUrl;
  String? musicId;
  final overlayText = TextEditingController(text: initialOverlayText);
  final hashtag = TextEditingController();
  var rotation = initialRotation;
  var emoji = initialOverlayEmoji;
  var overlayImageUrl = initialOverlayImageUrl;
  var busy = false;
  String url = mediaPath;
  var uploaded = mediaPath.startsWith('http');

  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SN.bg1,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        Future<void> upload() async {
          if (uploaded) return;
          setLocal(() => busy = true);
          try {
            final up = await Api.uploadMedia(mediaPath, kind: mediaType);
            url = '${up['url']}';
            uploaded = true;
          } catch (e) {
            if (ctx.mounted) toast(ctx, e.toString().replaceFirst('Exception: ', ''));
          } finally {
            if (ctx.mounted) setLocal(() => busy = false);
          }
        }

        Future<void> addImageSticker() async {
          final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
          if (f == null) return;
          setLocal(() => busy = true);
          try { final up = await Api.uploadMedia(f.path, kind: 'IMAGE'); setLocal(() => overlayImageUrl = '${up['url']}'); } catch (e) { if (ctx.mounted) toast(ctx, e.toString().replaceFirst('Exception: ', '')); } finally { if (ctx.mounted) setLocal(() => busy = false); }
        }

        Widget preview() {
          final child = mediaType == 'IMAGE'
              ? (mediaPath.startsWith('http') ? Image.network(mediaPath, fit: BoxFit.contain) : Image.file(File(mediaPath), fit: BoxFit.contain))
              : Container(
                  height: 230,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 68),
                );
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 230,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(angle: rotation * 3.141592653589793 / 180, child: child),
                  if (overlayText.text.trim().isNotEmpty)
                    Positioned(
                      bottom: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: Text(overlayText.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  if (emoji.isNotEmpty) Positioned(top: 16, right: 16, child: Text(emoji, style: const TextStyle(fontSize: 36))),
                  if (overlayImageUrl.isNotEmpty) Positioned(top: 12, left: 12, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(overlayImageUrl, width: 70, height: 70, fit: BoxFit.cover))),
                ],
              ),
            ),
          );
        }

        void publish() async {
          if (busy) return;
          setLocal(() => busy = true);
          try {
            await upload();
            if (!uploaded) return;
            // Merge reel video audio + selected music into one MP4 on the server.
            // This avoids Android audio-focus conflicts and keeps both tracks synchronized.
            if (reel && mediaType == 'VIDEO' && musicUrl.trim().isNotEmpty && existingId == null) {
              final mixed = await Api.mixMedia(url, musicUrl);
              url = '${mixed['url'] ?? url}';
              musicUrl = '';
            }
            final tags = hashtag.text.trim();
            final cap = tags.isEmpty ? caption.text.trim() : '${caption.text.trim()}\n$tags';
            final payload = {
              'url': url,
              'caption': cap,
              'title': title.text.trim(),
              'musicTitle': music.text.trim(),
              'musicUrl': musicUrl,
              'rotationDegrees': rotation,
              'overlayText': overlayText.text.trim(),
              'overlayEmoji': emoji,
              'overlayImageUrl': overlayImageUrl,
            };
            if (existingId != null) {
              if (reel) {
                await Api.updateReel(existingId, payload);
              } else {
                await Api.updatePost(existingId, payload);
              }
            } else {
              if (reel) {
                await Api.createReel(url, cap, music.text.trim(), musicUrl: musicUrl, title: title.text.trim(), rotationDegrees: rotation, overlayText: overlayText.text.trim(), overlayEmoji: emoji, overlayImageUrl: overlayImageUrl);
              } else {
                await Api.post(cap, media: url, type: mediaType, visibility: 'PUBLIC', title: title.text.trim(), rotationDegrees: rotation, overlayText: overlayText.text.trim(), overlayEmoji: emoji);
              }
            }
            if (ctx.mounted) Navigator.pop(ctx, payload);
          } catch (e) {
            if (ctx.mounted) toast(ctx, e.toString().replaceFirst('Exception: ', ''));
          } finally {
            if (ctx.mounted) setLocal(() => busy = false);
          }
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 12),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('تعديل قبل النشر', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                  IconButton(onPressed: () => setLocal(() => rotation = (rotation + 90) % 360), icon: const Icon(Icons.rotate_right)),
                  IconButton(onPressed: () => setLocal(() => emoji = emoji.isEmpty ? '✨' : ''), icon: const Icon(Icons.emoji_emotions_outlined)),
                ]),
                const SizedBox(height: 8),
                preview(),
                const SizedBox(height: 12),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان')),
                const SizedBox(height: 10),
                TextField(controller: caption, maxLines: 3, decoration: const InputDecoration(labelText: 'النص والوصف')),
                const SizedBox(height: 10),
                TextField(controller: hashtag, decoration: const InputDecoration(labelText: 'هاشتاق', hintText: '#SocialNova #ذكريات')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: music, decoration: const InputDecoration(labelText: 'الصوت / الموسيقى', prefixIcon: Icon(Icons.music_note)))),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'اختيار من موسيقى SocialNova',
                    onPressed: () async {
                      final picked = await openMusicPicker(ctx, selectedId: musicId);
                      if (picked == null) return;
                      setLocal(() {
                        musicId = '${picked['id'] ?? ''}';
                        music.text = '${picked['title'] ?? ''} — ${picked['artist'] ?? ''}';
                        musicUrl = '${picked['audioUrl'] ?? ''}';
                      });
                    },
                    icon: const Icon(Icons.library_music_rounded),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(controller: overlayText, onChanged: (_) => setLocal(() {}), decoration: const InputDecoration(labelText: 'نص فوق الصورة/الفيديو')),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  ActionChip(label: const Text('✨'), onPressed: () => setLocal(() => emoji = '✨')),
                  ActionChip(label: const Text('❤️'), onPressed: () => setLocal(() => emoji = '❤️')),
                  ActionChip(label: const Text('🔥'), onPressed: () => setLocal(() => emoji = '🔥')),
                  ActionChip(label: const Text('😂'), onPressed: () => setLocal(() => emoji = '😂')),
                  ActionChip(label: const Text('صورة إضافية'), onPressed: addImageSticker),
                ]),
                const SizedBox(height: 14),
                GradButton(label: existingId == null ? 'نشر الآن' : 'حفظ التعديل', icon: Icons.check_rounded, busy: busy, onTap: publish),
              ]),
            ),
          ),
        );
      },
    ),
  );
  caption.dispose(); title.dispose(); music.dispose(); overlayText.dispose(); hashtag.dispose();
  return result;
}
