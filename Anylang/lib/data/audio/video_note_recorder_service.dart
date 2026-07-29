import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// Telegram uslubidagi dumaloq video-note yozish (kamera).
class VideoNoteRecorderService extends GetxService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  Timer? _tick;
  final Stopwatch _sw = Stopwatch();

  final RxBool ready = false.obs;
  final RxBool recording = false.obs;
  final RxString elapsedLabel = '0:00'.obs;
  /// 60s limitiga yetganda true — UI FinishRecording chaqirishi mumkin.
  final RxBool hitMaxDuration = false.obs;
  VoidCallback? onHitMaxDuration;

  CameraController? get controller => _controller;

  Future<bool> prepare({bool preferFront = true}) async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) return false;

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;
      _cameraIndex = preferFront
          ? _cameras.indexWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
            )
          : _cameras.indexWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
            );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _openCamera(_cameras[_cameraIndex]);
      return ready.value;
    } catch (e, st) {
      debugPrint('VideoNoteRecorder.prepare: $e\n$st');
      return false;
    }
  }

  Future<void> _openCamera(CameraDescription desc) async {
    await _controller?.dispose();
    ready.value = false;
    final ctrl = CameraController(
      desc,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = ctrl;
    await ctrl.initialize();
    ready.value = ctrl.value.isInitialized;
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2 || recording.value) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(_cameras[_cameraIndex]);
  }

  Future<bool> start() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      final ok = await prepare();
      if (!ok) return false;
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) {
      return false;
    }
    await c.startVideoRecording();
    recording.value = true;
    hitMaxDuration.value = false;
    _sw
      ..reset()
      ..start();
    elapsedLabel.value = '0:00';
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final s = _sw.elapsed.inSeconds;
      final m = (s ~/ 60).toString().padLeft(1, '0');
      final r = (s % 60).toString().padLeft(2, '0');
      elapsedLabel.value = '$m:$r';
      if (s >= 60 && !hitMaxDuration.value) {
        hitMaxDuration.value = true;
        onHitMaxDuration?.call();
      }
    });
    return true;
  }

  Future<XFile?> stop() async {
    final ctrl = _controller;
    _tick?.cancel();
    _tick = null;
    _sw.stop();
    if (ctrl == null || !ctrl.value.isRecordingVideo) {
      recording.value = false;
      return null;
    }
    try {
      final file = await ctrl.stopVideoRecording();
      recording.value = false;
      return file;
    } catch (e, st) {
      debugPrint('VideoNoteRecorder.stop: $e\n$st');
      recording.value = false;
      return null;
    }
  }

  Future<void> cancel() async {
    final ctrl = _controller;
    _tick?.cancel();
    _tick = null;
    _sw.stop();
    if (ctrl != null && ctrl.value.isRecordingVideo) {
      try {
        final file = await ctrl.stopVideoRecording();
        // Discard temp file path — OS cleans cache; we ignore it.
        debugPrint('VideoNoteRecorder.cancel discarded ${file.path}');
      } catch (_) {}
    }
    recording.value = false;
    elapsedLabel.value = '0:00';
  }

  Future<void> release() async {
    await cancel();
    await _controller?.dispose();
    _controller = null;
    ready.value = false;
  }

  @override
  void onClose() {
    unawaited(release());
    super.onClose();
  }
}
