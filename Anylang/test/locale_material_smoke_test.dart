import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anylang/presentation/utils/fallback_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locales = <Locale>[
    const Locale('uz', 'UZ'),
    const Locale('en', 'US'),
    const Locale('ru', 'RU'),
    const Locale('ku', 'TR'),
    const Locale('tg', 'TJ'),
    const Locale('tk', 'TM'),
    const Locale('ha', 'NG'),
    const Locale('yo', 'NG'),
    const Locale('mt', 'MT'),
    const Locale('so', 'SO'),
    const Locale('ig', 'NG'),
    const Locale('ps', 'AF'),
    const Locale('de', 'DE'),
    const Locale('ar', 'SA'),
    const Locale('ja', 'JP'),
  ];

  for (final locale in locales) {
    testWidgets('fallback Material shell builds for $locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: [locale, const Locale('en', 'US')],
          localizationsDelegates: appLocalizationDelegates,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('t'),
              actions: [
                IconButton(
                  tooltip: 'tip',
                  onPressed: () {},
                  icon: const Icon(Icons.favorite),
                ),
              ],
            ),
            body: Column(
              children: [
                const TextField(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {},
                    child: ListView(
                      children: const [SizedBox(height: 200, child: Text('x'))],
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              label: const Text('Add'),
              icon: const Icon(Icons.add),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(MaterialLocalizations.of(tester.element(find.byType(TextField))),
          isNotNull);
    });
  }
}
