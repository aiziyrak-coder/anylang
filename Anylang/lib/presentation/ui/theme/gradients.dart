import 'package:flutter/material.dart';

final purpleBlueGradient = LinearGradient(
  colors: [
    Color(0xFF7C5CFA), // violet
    Color(0xFF327CF6), // blue
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Primary lime — light fonda ham ko'rinadigan to'qroq yashil.
const LinearGradient limeButtonGradient = LinearGradient(
  colors: [Color(0xFF8BC21A), Color(0xFF6FA00F)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ---------------------------------------------------------------------------
// Avatar fon gradientlari (suhbat ro'yxati). Temaga bog'liq emas — avatar har
// doim to'q fonli, ustida ochiq harf. Har foydalanuvchi bittasini oladi.
// ---------------------------------------------------------------------------
const LinearGradient avatarTealGradient = LinearGradient(
  colors: [Color(0xFF3B5C7A), Color(0xFF0B2545)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient avatarOliveGradient = LinearGradient(
  colors: [Color(0xFF5A6B3E), Color(0xFF2E3A22)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient avatarMaroonGradient = LinearGradient(
  colors: [Color(0xFF7A3B5C), Color(0xFF45152E)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient avatarGreenGradient = LinearGradient(
  colors: [Color(0xFF3E6B5A), Color(0xFF1A3A2E)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient avatarSlateGradient = LinearGradient(
  colors: [Color(0xFF4A5A7A), Color(0xFF1E2A45)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient avatarBrownGradient = LinearGradient(
  colors: [Color(0xFF6B5A3E), Color(0xFF3A2E1A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Jonli muloqot — suhbatdosh gapirganda mikrofon/tugma ko'k gradienti.
const LinearGradient speakingBlueGradient = LinearGradient(
  colors: [Color(0xFF8FD0F7), Color(0xFF5AA8E8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Profil foni — nozik yashil–ko‘k.
const LinearGradient profilePageGradientLight = LinearGradient(
  colors: [Color(0xFFE8F7F0), Color(0xFFE8F1FA), Color(0xFFF5F6F8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient profilePageGradientDark = LinearGradient(
  colors: [Color(0xFF0A1A18), Color(0xFF0A1520), Color(0xFF0A121C)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Chat canvas (rasmsiz) — tiniq, o‘qiladigan fon.
const LinearGradient chatCanvasGradientLight = LinearGradient(
  colors: [Color(0xFFF4F7FA), Color(0xFFEEF2F6), Color(0xFFF6F8FA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient chatCanvasGradientDark = LinearGradient(
  colors: [Color(0xFF0C1520), Color(0xFF101B28), Color(0xFF0A121C)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

/// Statistika kartalari — yengil gradientlar.
const LinearGradient profileStatGradientA = LinearGradient(
  colors: [Color(0x338BC21A), Color(0x225AA8E8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient profileStatGradientB = LinearGradient(
  colors: [Color(0x335AA8E8), Color(0x228BC21A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient profileStatGradientC = LinearGradient(
  colors: [Color(0x33F5C542), Color(0x228BC21A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient profileIdCardGradient = LinearGradient(
  colors: [Color(0xFF1B6B3A), Color(0xFF175CD3)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Bozor promo banner — slayd gradientlari.
const LinearGradient marketBannerGradientA = LinearGradient(
  colors: [Color(0xFF1B6B3A), Color(0xFF0F3D24)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient marketBannerGradientB = LinearGradient(
  colors: [Color(0xFFB42318), Color(0xFF7A160F)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient marketBannerGradientC = LinearGradient(
  colors: [Color(0xFFB54708), Color(0xFF7A2E05)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient marketBannerGradientD = LinearGradient(
  colors: [Color(0xFF175CD3), Color(0xFF0B3B8C)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ---------------------------------------------------------------------------
// Mahsulot kartasi (Bozor) fon tile gradientlari. Rasm o'rniga placeholder
// sifatida. Temaga bog'liq emas.
// ---------------------------------------------------------------------------
const LinearGradient prodBrownGradient = LinearGradient(
  colors: [Color(0xFF6B4A2E), Color(0xFF3A2A18)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient prodTealGradient = LinearGradient(
  colors: [Color(0xFF2E5647), Color(0xFF16324A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient prodBlueGradient = LinearGradient(
  colors: [Color(0xFF3E5A6B), Color(0xFF1A2E3A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient prodPurpleGradient = LinearGradient(
  colors: [Color(0xFF5A4A6B), Color(0xFF2E1A3A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient prodOliveGradient = LinearGradient(
  colors: [Color(0xFF6B5A3E), Color(0xFF3A2E18)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient prodMaroonGradient = LinearGradient(
  colors: [Color(0xFF6B3E4A), Color(0xFF3A181E)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
