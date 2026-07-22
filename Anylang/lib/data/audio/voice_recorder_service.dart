import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';

import 'waveform_utils.dart';

class VoiceRecordResult {
  final String path;
  final Duration duration;
  final List<double> samples;

  const VoiceRecordResult({
    required this.path,
    required this.duration,
    required this.samples,
  });
}

/// Mikrofon yozish + live amplitude (chat / jonli uchun).
class VoiceRecorderService extends GetxService {
  static const int barIntervalMs = 100;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _tickTimer;
  Timer? _secondTimer;
  final Stopwatch _sw = Stopwatch();

  double _recordTarget = 0;
  DateTime _lastBarWall = DateTime.now();

  final RxBool isRecording = false.obs;
  final RxString elapsedLabel = '0:00'.obs;
  final RxList<double> liveSamples = <double>[].obs;

  /// Yumshoq pulse (0..1) — UI ring / waveform uchun.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  /// Keyingi bar tomon glide (0..1).
  final ValueNotifier<double> liveScroll = ValueNotifier<double>(0);

  Duration get elapsed => _sw.elapsed;

  Future<bool> ensurePermission() => _recorder.hasPermission();

  Future<bool> start() async {
    if (isRecording.value) return true;
    final granted = await _recorder.hasPermission();
    if (!granted) return false;

    final path =
        '${Directory.systemTemp.path}/anylang_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );

    liveSamples.clear();
    liveScroll.value = 0;
    level.value = 0;
    _recordTarget = 0;
    _lastBarWall = DateTime.now();
    _sw
      ..reset()
      ..start();
    elapsedLabel.value = '0:00';

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen((amp) => _recordTarget = WaveformUtils.normalizeDb(amp.current));

    _tickTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => _onTick());
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedLabel.value = WaveformUtils.formatDuration(_sw.elapsed);
    });

    isRecording.value = true;
    return true;
  }

  Future<VoiceRecordResult?> stop({bool discard = false}) async {
    if (!isRecording.value) return null;

    _secondTimer?.cancel();
    _tickTimer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    _sw.stop();

    final path = await _recorder.stop();
    final duration = _sw.elapsed;
    final samples = List<double>.of(liveSamples);

    _recordTarget = 0;
    level.value = 0;
    liveScroll.value = 0;
    isRecording.value = false;
    elapsedLabel.value = '0:00';

    if (discard || path == null || duration.inMilliseconds < 700) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      liveSamples.clear();
      return null;
    }

    return VoiceRecordResult(path: path, duration: duration, samples: samples);
  }

  Future<void> cancel() async {
    await stop(discard: true);
  }

  void _onTick() {
    if (!isRecording.value) return;
    final c = level.value;
    level.value = c + (_recordTarget - c) * 0.18;

    final elapsed = DateTime.now().difference(_lastBarWall).inMilliseconds;
    if (elapsed >= barIntervalMs) {
      final steps = elapsed ~/ barIntervalMs;
      for (var i = 0; i < steps; i++) {
        liveSamples.add(level.value);
      }
      _lastBarWall =
          _lastBarWall.add(Duration(milliseconds: barIntervalMs * steps));
      liveScroll.value = 0;
    } else {
      liveScroll.value = elapsed / barIntervalMs;
    }
  }

  @override
  void onClose() {
    _secondTimer?.cancel();
    _tickTimer?.cancel();
    _ampSub?.cancel();
    level.dispose();
    liveScroll.dispose();
    _recorder.dispose();
    super.onClose();
  }
}
