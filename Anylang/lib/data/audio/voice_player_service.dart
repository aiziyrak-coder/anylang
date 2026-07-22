import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'waveform_utils.dart';

/// Bitta faol ovoz ijrosi (Telegram uslubi: bir vaqtda bitta).
class VoicePlayerService extends GetxService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;
  Timer? _tickTimer;

  final RxnString activeId = RxnString();
  final RxBool isPlaying = false.obs;

  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  final ValueNotifier<double> pulse = ValueNotifier<double>(0);

  final Map<String, double> _positions = <String, double>{};
  List<double> _activeBars = const <double>[];
  Duration _activeDuration = Duration.zero;
  DateTime _anchorWall = DateTime.now();
  Duration _anchorPos = Duration.zero;
  bool _busy = false;

  @override
  void onInit() {
    super.onInit();
    _posSub = _player.onPositionChanged.listen(_onRealPosition);
    _durSub = _player.onDurationChanged.listen((d) {
      if (d > Duration.zero) _activeDuration = d;
    });
    _completeSub = _player.onPlayerComplete.listen((_) => _onComplete());
  }

  bool isActive(String id) => activeId.value == id;

  double restingProgress(String id) {
    if (activeId.value == id) return progress.value;
    return _positions[id] ?? 0;
  }

  Future<void> toggle({
    required String id,
    required String path,
    required Duration duration,
    List<double> samples = const [],
    int barCount = 22,
  }) async {
    if (_busy) return;
    _busy = true;
    try {
      if (activeId.value == id && isPlaying.value) {
        await _player.pause();
        _positions[id] = progress.value;
        isPlaying.value = false;
        _syncTicker();
        return;
      }
      if (activeId.value == id && !isPlaying.value) {
        _anchorPos = Duration(
          milliseconds: (progress.value * _activeDuration.inMilliseconds).round(),
        );
        _anchorWall = DateTime.now();
        await _player.resume();
        isPlaying.value = true;
        _syncTicker();
        return;
      }
      await _start(id, path, duration, samples, barCount, _positions[id] ?? 0);
    } finally {
      _busy = false;
    }
  }

  Future<void> seek({
    required String id,
    required String path,
    required Duration duration,
    required double frac,
    List<double> samples = const [],
    int barCount = 22,
  }) async {
    frac = frac.clamp(0.0, 1.0);
    if (activeId.value == id) {
      final pos = Duration(
        milliseconds: (frac * _activeDuration.inMilliseconds).round(),
      );
      _anchorPos = pos;
      _anchorWall = DateTime.now();
      progress.value = frac;
      await _player.seek(pos);
      if (!isPlaying.value) {
        await _player.resume();
        isPlaying.value = true;
        _syncTicker();
      }
    } else {
      await _start(id, path, duration, samples, barCount, frac);
    }
  }

  Future<void> stop({bool save = false}) async {
    if (save && activeId.value != null) {
      _positions[activeId.value!] = progress.value;
    }
    await _player.stop();
    isPlaying.value = false;
    _syncTicker();
  }

  Future<void> _start(
    String id,
    String path,
    Duration duration,
    List<double> samples,
    int barCount,
    double startFrac,
  ) async {
    if (activeId.value != null && activeId.value != id) {
      _positions[activeId.value!] = progress.value;
    }

    activeId.value = id;
    _activeBars = WaveformUtils.resampleBars(samples, barCount);
    _activeDuration =
        duration.inMilliseconds > 0 ? duration : const Duration(seconds: 1);

    final startPos = Duration(
      milliseconds: (startFrac * _activeDuration.inMilliseconds).round(),
    );
    _anchorPos = startPos;
    _anchorWall = DateTime.now();
    progress.value = startFrac;
    pulse.value = 0;
    isPlaying.value = true;
    _syncTicker();

    final source = path.startsWith('http')
        ? UrlSource(path)
        : DeviceFileSource(path);
    await _player.play(source, position: startPos);
  }

  void _onRealPosition(Duration pos) {
    if (!isPlaying.value) return;
    final now = DateTime.now();
    final virtual =
        _anchorPos.inMilliseconds + now.difference(_anchorWall).inMilliseconds;
    if ((pos.inMilliseconds - virtual).abs() > 300) {
      _anchorPos = pos;
      _anchorWall = now;
    }
  }

  void _onComplete() {
    final id = activeId.value;
    if (id != null) _positions[id] = 0;
    progress.value = 0;
    pulse.value = 0;
    isPlaying.value = false;
    activeId.value = null;
    _syncTicker();
  }

  void _syncTicker() {
    final shouldRun = isPlaying.value;
    if (shouldRun && !(_tickTimer?.isActive ?? false)) {
      _tickTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => _onTick());
    } else if (!shouldRun) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  void _onTick() {
    if (!isPlaying.value || _activeDuration.inMilliseconds <= 0) return;
    final now = DateTime.now();
    var posMs =
        _anchorPos.inMilliseconds + now.difference(_anchorWall).inMilliseconds;
    final totalMs = _activeDuration.inMilliseconds;
    if (posMs > totalMs) posMs = totalMs;
    final frac = (posMs / totalMs).clamp(0.0, 1.0);
    progress.value = frac;

    final target = _activeBars.isEmpty
        ? 0.0
        : _activeBars[(frac * _activeBars.length).floor().clamp(0, _activeBars.length - 1)];
    final c = pulse.value;
    pulse.value = c + (target - c) * 0.22;
  }

  /// Lokal fayl mavjudligini tekshiradi (remote URL uchun true).
  static bool canPlay(String? path) {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http')) return true;
    return File(path).existsSync();
  }

  @override
  void onClose() {
    _tickTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    progress.dispose();
    pulse.dispose();
    _player.dispose();
    super.onClose();
  }
}
