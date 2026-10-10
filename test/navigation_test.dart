import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emerald_tarot/main.dart';
import 'package:emerald_tarot/models.dart';
import 'package:emerald_tarot/localization.dart';

void main() {
  testWidgets(
    'tab taps slide horizontally, swipes synchronize navigation and preserve input',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      await appPreferences.setLanguage('zh');
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(TarotApp(journal: JournalStore()));
      await t.pumpAndSettle();
      expect(find.text('星笺'), findsOneWidget);
      final pages = find.byKey(const ValueKey('main-pages'));
      await t.tap(find.text('占卜').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      final position = t.widget<PageView>(pages).controller!.page!;
      expect(position, greaterThan(0));
      expect(position, lessThan(1));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, '保留这段问题');
      await t.drag(pages, const Offset(-320, 0));
      await t.pumpAndSettle();
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      await t.drag(pages, const Offset(320, 0), kind: PointerDeviceKind.mouse);
      await t.pumpAndSettle();
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('保留这段问题'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
