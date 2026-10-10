import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:emerald_tarot/ai.dart';
import 'package:emerald_tarot/localization.dart';
import 'package:emerald_tarot/main.dart';
import 'package:emerald_tarot/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appPreferences.language = 'zh';
  });
  tearDown(() {
    appPreferences.language = 'zh';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DynamicColorPlugin.channel, null);
  });

  test(
    'all 78 cards have complete English and Japanese content; language persists',
    () async {
      for (final language in ['en', 'ja']) {
        await appPreferences.setLanguage(language);
        for (final card in deck) {
          final values = [
            card.name,
            ...card.keywords,
            card.meaning,
            card.reverse,
            card.reflection,
          ];
          expect(
            values.every((v) => v.isNotEmpty && !v.contains('null')),
            isTrue,
            reason: card.id,
          );
          if (language == 'en') {
            expect(
              values.any((v) => RegExp(r'[\u4e00-\u9fff]').hasMatch(v)),
              isFalse,
              reason: card.id,
            );
          }
        }
      }
      final reloaded = AppPreferences();
      await reloaded.load();
      expect(reloaded.language, 'ja');
      appPreferences.language = 'zh';
      expect(tr('Celtic Cross'), '凯尔特十字');
    },
  );

  testWidgets(
    'language menu updates an existing settings route and preserves journal text',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final journal = JournalStore();
      await journal.load();
      await journal.save(
        Reading(
          id: 'keep',
          created: DateTime(2026),
          question: '我的原文',
          spread: '每日一牌',
          cards: [DrawnCard(deck.first)],
        ),
        '記録 / original',
      );
      final before = (await SharedPreferences.getInstance()).getString(
        JournalStore.storageKey,
      );
      await t.pumpWidget(TarotApp(journal: journal));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('设置'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('language-zh')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('language-zh')),
          matching: find.byType(TextField),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('English').last);
      await t.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      await appPreferences.setLanguage('ja');
      await t.pumpAndSettle();
      expect(find.text('設定'), findsOneWidget);
      expect(find.text('言語'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          JournalStore.storageKey,
        ),
        before,
      );
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('星 · 正位置'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'system palette updates on resume without losing a typed question; background remains black',
    (t) async {
      var accent = Colors.purple;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            DynamicColorPlugin.channel,
            (call) async =>
                call.method == 'getAccentColor' ? accent.toARGB32() : null,
          );
      final journal = JournalStore();
      await journal.load();
      await t.pumpWidget(TarotApp(journal: journal));
      await t.pumpAndSettle();
      ColorScheme palette() =>
          Theme.of(t.element(find.byType(AppShell))).colorScheme;
      expect(palette().surface, Colors.black);
      expect(
        Theme.of(
          t.element(find.byType(AppShell)),
        ).navigationBarTheme.backgroundColor,
        palette().surfaceContainer,
      );
      expect(palette().surfaceContainer, isNot(Colors.black));
      expect(
        palette().primary,
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ).primary,
      );
      await t.tap(find.text('占卜').last);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('question')),
        'keep my unfinished question',
      );
      accent = Colors.red;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(
        palette().primary,
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ).primary,
      );
      expect(find.text('keep my unfinished question'), findsOneWidget);
      expect(
        Theme.of(t.element(find.byType(AppShell))).scaffoldBackgroundColor,
        Colors.black,
      );
      expect(t.takeException(), isNull);
    },
  );

  test('AI response language follows the selected app language', () async {
    appPreferences.language = 'ja';
    final service = AiService(
      client: MockClient((request) async {
        final messages = (jsonDecode(request.body) as Map)['messages'] as List;
        expect(
          messages.first['content'],
          contains('Respond exclusively in Japanese'),
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'テスト'},
                },
              ],
            }),
          ),
          200,
        );
      }),
    );
    expect(
      await service.complete(
        provider: AiProvider.deepseek,
        key: 'mock',
        model: 'deepseek-flash',
        session: 'test',
        prompt: 'question',
      ),
      'テスト',
    );
    service.close();
  });
}
