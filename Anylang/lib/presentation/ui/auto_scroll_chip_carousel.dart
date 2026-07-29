import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/size_controller.dart';

/// Bir qatorli chip karusel: sekin avtomatik aylanadi, qo‘l bilan surish mumkin.
class AutoScrollChipCarousel extends StatefulWidget {
  final List<Widget> children;
  final double spacing;
  /// Sekundiga piksel (kichik = sekin).
  final double speedPxPerSec;

  const AutoScrollChipCarousel({
    super.key,
    required this.children,
    this.spacing = 8,
    this.speedPxPerSec = 22,
  });

  @override
  State<AutoScrollChipCarousel> createState() => _AutoScrollChipCarouselState();
}

class _AutoScrollChipCarouselState extends State<AutoScrollChipCarousel> {
  final ScrollController _ctrl = ScrollController();
  final GlobalKey _measureKey = GlobalKey();
  Timer? _timer;
  bool _paused = false;
  double _loopWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  @override
  void didUpdateWidget(covariant AutoScrollChipCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _measureAndStart() {
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _loopWidth = box.size.width + widget.spacing.dp;
    }
    _timer?.cancel();
    if (widget.children.length < 2 || _loopWidth <= 0) return;
    if (_ctrl.hasClients) {
      final start = _loopWidth;
      final max = _ctrl.position.maxScrollExtent;
      if (max > 0 && (_ctrl.offset - start).abs() > 1) {
        _ctrl.jumpTo(start.clamp(0.0, max));
      }
    }
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (_paused || !_ctrl.hasClients || _loopWidth <= 0) return;
    final max = _ctrl.position.maxScrollExtent;
    if (max <= 0) return;
    // Bitta to‘plam ekranga sig‘sa — aylantirmaymiz.
    if (_loopWidth <= _ctrl.position.viewportDimension + 1) return;

    final step = widget.speedPxPerSec * 0.016;
    var next = _ctrl.offset + step;
    if (next >= _loopWidth * 2) {
      next -= _loopWidth;
      _ctrl.jumpTo(next);
    } else {
      _ctrl.jumpTo(next.clamp(0.0, max));
    }
  }

  Widget _strip({Key? key}) {
    final gap = widget.spacing.dp;
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          widget.children[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    if (widget.children.length == 1) {
      return Align(
        alignment: Alignment.centerLeft,
        child: widget.children.first,
      );
    }

    final gap = widget.spacing.dp;

    return SizedBox(
      height: 42.dp,
      child: Listener(
        onPointerDown: (_) => _paused = true,
        onPointerUp: (_) => _paused = false,
        onPointerCancel: (_) => _paused = false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _paused = true;
            } else if (n is ScrollEndNotification) {
              _paused = false;
            }
            return false;
          },
          child: ListView(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _strip(key: _measureKey),
              SizedBox(width: gap),
              _strip(),
              SizedBox(width: gap),
              _strip(),
            ],
          ),
        ),
      ),
    );
  }
}
