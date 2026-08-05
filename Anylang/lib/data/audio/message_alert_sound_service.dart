import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';

/// AnyLang maxsus qisqa xabar tovushi (foreground).
///
/// Bir vaqtda kelgan ko‘p xabar (catch-up) uchun bitta tovush;
/// oralig‘i uzun bo‘lsa (jonli yozish) — har biriga chaladi.
class MessageAlertSoundService extends GetxService {
  AudioPlayer? _player;
  DateTime? _lastPlayAt;

  static const _asset = 'sounds/anylang_message.wav';
  /// Shu vaqt ichidagi keyingi chaqiriqlar o‘tkazib yuboriladi.
  static const _coalesceGap = Duration(milliseconds: 1600);

  Future<void> play() async {
    final now = DateTime.now();
    // Sync check+set: parallel unawaited(play()) poygasini oldini oladi.
    final last = _lastPlayAt;
    if (last != null && now.difference(last) < _coalesceGap) {
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

  /// App resume / socket reconnect: keyingi burstda birinchi tovush o‘tsin.
  void markBurstWindow() {
    _lastPlayAt = null;
  }

  @override
  void onClose() {
    _player?.dispose();
    _player = null;
    super.onClose();
  }
}
