import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter Global*Localizations faqat cheklangan tillarni biladi.
/// AnyLang UI matnlari GetX orqali 80 tilda ishlaydi; Material/Cupertino
/// framework stringlari (TextField, RefreshIndicator, tooltip, …) uchun
/// qo‘llab-quvvatlanmagan locale → en_US fallback.
/// Aks holda: "No MaterialLocalizations found" → release’da kulrang ErrorWidget.

const Locale _kFallbackLocale = Locale('en', 'US');

class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final d = GlobalMaterialLocalizations.delegate;
    if (d.isSupported(locale)) return d.load(locale);
    return d.load(_kFallbackLocale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) =>
      false;
}

class FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    final d = GlobalWidgetsLocalizations.delegate;
    if (d.isSupported(locale)) return d.load(locale);
    return d.load(_kFallbackLocale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<WidgetsLocalizations> old) =>
      false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final d = GlobalCupertinoLocalizations.delegate;
    if (d.isSupported(locale)) return d.load(locale);
    return d.load(_kFallbackLocale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) =>
      false;
}

/// GetMaterialApp.localizationsDelegates uchun.
const List<LocalizationsDelegate<dynamic>> appLocalizationDelegates = [
  FallbackMaterialLocalizationsDelegate(),
  FallbackWidgetsLocalizationsDelegate(),
  FallbackCupertinoLocalizationsDelegate(),
];
