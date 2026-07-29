import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';

/// AnyLang maxsus qisqa xabar tovushi (foreground).
class MessageAlertSoundService extends GetxService {
  AudioPlayer? _player;
  DateTime? _lastPlayAt;

  static const _asset = 'sounds/anylang_message.wav';
  static const _minGap = Duration(milliseconds: 450);

  Future<void> play() async {
    final now = DateTime.now();
    if (_lastPlayAt != null && now.difference(_lastPlayAt!) < _minGap) {
      return;
    }
    _lastPlayAt = now;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.85);
      await player.play(AssetSource(_asset));
    } catch (_) {
      // Tovush ixtiyoriy — xato UI ni to‘xtatmasin.
    }
  }

  @override
  void onClose() {
    _player?.dispose();
    _player = null;
    super.onClose();
  }
}
