import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:anylang/presentation/screens/login/login_screen.dart';
import 'package:anylang/presentation/screens/main/main_screen.dart';
import 'package:anylang/presentation/screens/select_language/select_language_screen.dart';
import 'data/core/buildNetwork/api_config.dart';
import 'data/core/buildNetwork/api_service.dart';
import 'data/core/buildNetwork/token_refresher.dart';
import 'data/local/session_store.dart';
import 'di/main_module.dart';
import 'presentation/ui/theme/app_theme.dart';
import 'presentation/ui/theme/theme_controller.dart';
import 'presentation/utils/language_localizations.dart';
import 'presentation/utils/size_controller.dart';

const SystemUiOverlayStyle transparentSystemUi = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assertProductionApiConfig();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(transparentSystemUi);

  await Hive.initFlutter();
  await Hive.openBox('user');
  await MainModule().initModule();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Worker? _sessionWorker;

  @override
  void initState() {
    super.initState();
    _sessionWorker = ever<int>(Get.find<SessionExpiredBus>().tick, (_) async {
      await SessionStore.clear();
      Get.offAll(() => LoginScreen().build());
    });
  }

  @override
  void dispose() {
    _sessionWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: LanguageLocalizations(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: Get.find<ThemeController>().mode.value,
      locale: _getLanguage(),
      supportedLocales: const [
        Locale('uz'),
        Locale('en'),
        Locale('ru'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        SizeController.init(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: transparentSystemUi,
          child: child ?? const SizedBox.shrink(),
        );
      },
      fallbackLocale: const Locale('uz', 'UZ'),
      home: const _BootstrapHome(),
    );
  }

  Locale _getLanguage() {
    final box = Hive.box("user");
    final language = box.get("language", defaultValue: 'uz_UZ');
    final parts = language.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : 'UZ');
  }
}

/// Refresh token bor bo'lsa Main, aks holda Select Language.
class _BootstrapHome extends StatefulWidget {
  const _BootstrapHome();

  @override
  State<_BootstrapHome> createState() => _BootstrapHomeState();
}

class _BootstrapHomeState extends State<_BootstrapHome> {
  Widget? _child;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    if (!SessionStore.hasSession) {
      setState(() => _child = SelectLanguageScreen().build());
      return;
    }
    try {
      final token = await Get.find<TokenRefresher>().getNewToken();
      if (token != 'none' && token.isNotEmpty) {
        setState(() => _child = MainScreen().build());
        return;
      }
    } catch (_) {
      await SessionStore.clear();
    }
    setState(() => _child = SelectLanguageScreen().build());
  }

  @override
  Widget build(BuildContext context) {
    return _child ??
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
  }
}
