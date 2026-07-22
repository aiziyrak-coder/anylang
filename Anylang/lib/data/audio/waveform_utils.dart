import 'dart:math';

/// Amplitude / waveform yordamchilari — voice_pulse'dan ko'chirilgan mantiq.
abstract final class WaveformUtils {
  static const double minDb = -45;

  /// dBFS → 0..1.
  static double normalizeDb(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0;
    final clamped = dbfs.clamp(minDb, 0.0);
    return (clamped - minDb) / (0 - minDb);
  }

  /// Raw samples → [count] ta peak-normalize qilingan bar (0..1).
  static List<double> resampleBars(List<double> samples, int count) {
    if (count <= 0) return const [];
    if (samples.isEmpty) return List<double>.filled(count, 0.06);

    final out = List<double>.filled(count, 0);
    final bucket = samples.length / count;
    for (var i = 0; i < count; i++) {
      final start = (i * bucket).floor();
      final end = max(start + 1, ((i + 1) * bucket).floor());
      var sum = 0.0;
      var n = 0;
      for (var j = start; j < end && j < samples.length; j++) {
        sum += samples[j];
        n++;
      }
      out[i] = n > 0 ? sum / n : 0.0;
    }

    final peak = out.reduce(max);
    if (peak > 0) {
      for (var i = 0; i < count; i++) {
        out[i] = (out[i] / peak).clamp(0.06, 1.0);
      }
    }
    return out;
  }

  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
