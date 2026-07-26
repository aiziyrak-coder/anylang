/// Sozlamalar ekrani qaysi bo'limni ochishi / avto-action.
enum SettingsFocus {
  /// Til, tema, bildirishnomalar — to‘liq app sozlamalari.
  app,

  /// Maxfiylik, parol, blok, chiqish.
  account,

  /// Til tanlash sheet’ini ochadi.
  language,

  /// Ko‘rinish / tema bo‘limi.
  theme,

  /// Bildirishnomalar bo‘limi.
  notifications,

  /// Maxfiylik (profil ko‘rinishi).
  privacy,

  /// Parolni o‘zgartirish (ForgotPassword).
  security,

  /// Smart Translation domain sheet.
  translation,
}

class SettingsPayload {
  final SettingsFocus focus;
  const SettingsPayload({this.focus = SettingsFocus.app});
}
