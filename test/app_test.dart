import 'dart:math';
import 'package:emerald_tarot/main.dart';
import 'package:emerald_tarot/models.dart';
import 'package:emerald_tarot/pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('draws are unique, orientations survive serialization', () {
    for (var seed = 0; seed < 100; seed++) {
      final cards = drawCards(3, Random(seed));
      expect(cards.map((c) => c.card.id).toSet().length, 3);
      for (final c in cards) {
        final restored = DrawnCard.fromJson(c.toJson());
        expect(restored.card.id, c.card.id);
        expect(restored.reversed, c.reversed);
      }
    }
    expect(() => drawCards(79, Random()), throwsRangeError);
  });

  test(
    'journal persists, updates by id, and reloads notes and orientations',
    () async {
      final reading = Reading(
        id: 'test',
        created: DateTime(2026, 10, 10),
        question: '我可以如何面对变化？',
        spread: '三张牌',
        cards: drawCards(3, Random(7)),
      );
      final store = JournalStore();
      await store.load();
      await store.save(reading, '第一条想法');
      await store.save(reading, '一个可以尝试的小行动');
      final restored = JournalStore();
      await restored.load();
      expect(restored.readings.length, 1);
      expect(restored.readings.single.note, '一个可以尝试的小行动');
      expect(
        restored.readings.single.cards.map((c) => c.toJson()),
        reading.cards.map((c) => c.toJson()),
      );
      expect(restored.loadError, isNull);
    },
  );

  testWidgets(
    'mobile MD3 flow reveals all cards before reading and saves a journal',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final journal = JournalStore();
      await journal.load();
      await t.pumpWidget(TarotApp(journal: journal));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(NavigationBar))).useMaterial3,
        isTrue,
      );
      expect(
        Theme.of(t.element(find.byType(NavigationBar))).brightness,
        Brightness.dark,
      );
      await t.tap(find.text('占卜').last);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('question')), '我可以如何面对变化？');
      await t.ensureVisible(find.byKey(const ValueKey('start-reading')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('start-reading')));
      await t.pumpAndSettle();
      expect(find.byType(DrawPage), findsOneWidget);
      final button = find.byKey(const ValueKey('view-reading'));
      expect(t.widget<FilledButton>(button).onPressed, isNull);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(ValueKey('flip-$i')));
        await t.pumpAndSettle();
      }
      expect(t.widget<FilledButton>(button).onPressed, isNotNull);
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.byType(ReadingPage), findsOneWidget);
      final note = find.byKey(const ValueKey('journal-note'));
      await t.scrollUntilVisible(
        note,
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await t.enterText(note, '今天先完成一个小行动。');
      final save = find.byKey(const ValueKey('save-journal'));
      await t.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(save);
      await t.pumpAndSettle();
      expect(journal.readings.single.note, '今天先完成一个小行动。');
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await t.tap(find.text('日记').last);
      await t.pumpAndSettle();
      expect(find.text('我可以如何面对变化？'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('small screen and enlarged text keep navigation usable', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final journal = JournalStore();
    await journal.load();
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: TarotApp(journal: journal),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await t.tap(find.text('牌库').last);
    await t.pumpAndSettle();
    expect(find.byType(SearchBar), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.enterText(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(TextField),
      ),
      '不存在',
    );
    await t.pumpAndSettle();
    expect(find.text('没有找到这张牌，试试其他关键词。'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
