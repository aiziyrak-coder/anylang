/// Sozlamalar ekrani qaysi bo'limni ochishi.
enum SettingsFocus {
  /// Til, tema, bildirishnomalar — dasturni sozlash.
  app,
  /// Maxfiylik, parol, blok, chiqish — akkauntni sozlash.
  account,
}

class SettingsPayload {
  final SettingsFocus focus;
  const SettingsPayload({this.focus = SettingsFocus.app});
}
