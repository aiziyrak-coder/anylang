import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../data/core/buildNetwork/api_config.dart';
import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// LRU kesh — bir xil video uchun kadr qayta olinmasin.
final _thumbCache = LinkedHashMap<String, Uint8List>();
const _kMaxCache = 48;

String _absoluteVideoPath(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  if (t.startsWith('http://') ||
      t.startsWith('https://') ||
      t.startsWith('file://')) {
    return t;
  }
  if (t.startsWith('/') && File(t).existsSync()) {
    return t;
  }
  final base = kBaseUrl.endsWith('/')
      ? kBaseUrl.substring(0, kBaseUrl.length - 1)
      : kBaseUrl;
  if (t.startsWith('/')) return '$base$t';
  if (!File(t).existsSync()) return '$base/$t';
  return t;
}

Future<Uint8List?> _loadVideoFrame(String videoPath) async {
  final cached = _thumbCache[videoPath];
  if (cached != null) {
    _thumbCache.remove(videoPath);
    _thumbCache[videoPath] = cached;
    return cached;
  }

  try {
    Uint8List? bytes = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 480,
      quality: 72,
      timeMs: 200,
    );
    if (bytes == null || bytes.isEmpty) {
      bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 72,
        timeMs: 0,
      );
    }
    if (bytes == null || bytes.isEmpty) return null;
    _thumbCache[videoPath] = bytes;
    while (_thumbCache.length > _kMaxCache) {
      _thumbCache.remove(_thumbCache.keys.first);
    }
    return bytes;
  } catch (e, st) {
    debugPrint('ChatVideoThumbnail: $e\n$st');
    return null;
  }
}

/// Chat video bubble: videoning boshidagi kadr rasmi.
class ChatVideoThumbnail extends StatefulWidget {
  final String url;
  final bool round;
  final double width;
  final double height;
  final Widget? overlay;

  const ChatVideoThumbnail({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.round = false,
    this.overlay,
  });

  @override
  State<ChatVideoThumbnail> createState() => _ChatVideoThumbnailState();
}

class _ChatVideoThumbnailState extends State<ChatVideoThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ChatVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final gen = ++_gen;
    final raw = widget.url.trim();
    if (raw.isEmpty) {
      if (!mounted || gen != _gen) return;
      setState(() => _loading = false);
      return;
    }

    final path = _absoluteVideoPath(raw);
    final isNet = path.startsWith('http://') || path.startsWith('https://');
    if (!isNet && !File(path).existsSync()) {
      if (!mounted || gen != _gen) return;
      setState(() => _loading = false);
      return;
    }

    final bytes = await _loadVideoFrame(path);
    if (!mounted || gen != _gen) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    Widget content;
    if (_bytes != null) {
      content = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    } else if (_loading) {
      content = ColoredBox(
        color: c.isDark ? const Color(0xFF12263A) : const Color(0xFFE8EEF5),
        child: Center(
          child: SizedBox(
            width: 22.dp,
            height: 22.dp,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.accent,
            ),
          ),
        ),
      );
    } else {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _loading = true);
            _load();
          },
          child: ColoredBox(
            color: c.isDark ? const Color(0xFF12263A) : const Color(0xFFE8EEF5),
            child: Center(
              child: Icon(
                Icons.refresh_rounded,
                size: 36.dp,
                color: c.textFaint,
              ),
            ),
          ),
        ),
      );
    }

    Widget stack = Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (widget.overlay != null) widget.overlay!,
      ],
    );
    if (widget.round) {
      stack = ClipOval(child: stack);
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: stack,
    );
  }
}
