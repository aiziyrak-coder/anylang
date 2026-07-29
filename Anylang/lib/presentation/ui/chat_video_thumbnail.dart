import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/core/buildNetwork/api_config.dart';
import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Bir xil URL uchun controller qayta ochilmasin.
final _readyUrls = LinkedHashSet<String>();

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

/// Chat video bubble: videoning boshidagi kadr rasmi (`video_player`).
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
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _failed = false;
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
      _disposeCtrl();
      _ready = false;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final gen = ++_gen;
    final path = _absoluteVideoPath(widget.url);
    if (path.isEmpty) {
      if (!mounted || gen != _gen) return;
      setState(() => _failed = true);
      return;
    }
    final isNet = path.startsWith('http://') || path.startsWith('https://');
    if (!isNet && !File(path).existsSync()) {
      if (!mounted || gen != _gen) return;
      setState(() => _failed = true);
      return;
    }
    try {
      final ctrl = isNet
          ? VideoPlayerController.networkUrl(Uri.parse(path))
          : VideoPlayerController.file(File(path));
      _ctrl = ctrl;
      await ctrl.initialize();
      await ctrl.setVolume(0);
      // Ba'zi kodeklar 0ms da qora — biroz oldinga.
      final target = ctrl.value.duration.inMilliseconds > 400
          ? const Duration(milliseconds: 200)
          : Duration.zero;
      await ctrl.seekTo(target);
      await ctrl.pause();
      if (!mounted || gen != _gen) {
        await ctrl.dispose();
        return;
      }
      _readyUrls.add(path);
      setState(() {
        _ready = true;
        _failed = false;
      });
    } catch (e, st) {
      debugPrint('ChatVideoThumbnail: $e\n$st');
      if (!mounted || gen != _gen) return;
      setState(() {
        _ready = false;
        _failed = true;
      });
    }
  }

  void _disposeCtrl() {
    _ctrl?.dispose();
    _ctrl = null;
  }

  @override
  void dispose() {
    _disposeCtrl();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    Widget content;
    if (_ready && _ctrl != null) {
      content = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _ctrl!.value.size.width,
          height: _ctrl!.value.size.height,
          child: VideoPlayer(_ctrl!),
        ),
      );
    } else if (_failed) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _failed = false;
              _ready = false;
            });
            _disposeCtrl();
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
    } else {
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
