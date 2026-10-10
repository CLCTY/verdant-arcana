import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:emerald_tarot/ai.dart';
import 'package:emerald_tarot/main.dart';
import 'package:emerald_tarot/models.dart';
import 'package:emerald_tarot/pages.dart';
import 'package:emerald_tarot/settings.dart';
import 'package:emerald_tarot/spreads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'provider credentials stay separate and journal notes are not uploaded',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final settings = AiSettings();
      await settings.save(AiProvider.deepseek, 'ds-test-key', 'deepseek-flash');
      await settings.save(
        AiProvider.opencode,
        'go-test-key',
        'deepseek-v4.1-flash',
      );
      final restored = AiSettings();
      await restored.load();
      expect(restored.keyFor(AiProvider.deepseek), 'ds-test-key');
      expect(restored.keyFor(AiProvider.opencode), 'go-test-key');
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        expect(prefs.get(key).toString(), isNot(contains('test-key')));
      }
      final reading = Reading(
        id: 'private',
        created: DateTime(2026),
        question: '当前问题',
        spread: '单张指引',
        spreadId: 'single',
        cards: [DrawnCard(deck.first)],
        note: '私密日记内容',
      );
      final service = AiService(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer go-test-key');
          expect(request.body, contains('当前问题'));
          expect(request.body, isNot(contains('私密日记内容')));
          return http.Response(
            '{"choices":[{"message":{"content":"OK"}}]}',
            200,
          );
        }),
      );
      expect(await service.interpret(reading, restored), 'OK');
      service.close();
      await restored.save(AiProvider.opencode, '', 'deepseek-v4.1-flash');
      expect(restored.ready, isFalse);
      expect(restored.keyFor(AiProvider.deepseek), 'ds-test-key');
    },
  );
  test('full deck contains 78 unique complete cards with real assets', () {
    expect(deck.length, 78);
    expect(deck.map((c) => c.id).toSet().length, 78);
    expect(deck.where((c) => c.category == '大阿卡纳').length, 22);
    for (final suit in ['权杖', '圣杯', '宝剑', '星币']) {
      expect(deck.where((c) => c.category == suit).length, 14);
    }
    for (final card in deck) {
      expect(card.meaning, isNotEmpty);
      expect(card.reverse, isNotEmpty);
      expect(card.keywords.length, 3);
      expect(File(card.image).existsSync(), isTrue, reason: card.id);
      expect(
        File(card.image).lengthSync(),
        greaterThan(10000),
        reason: card.id,
      );
    }
    expect(drawCards(78, Random(9)).map((c) => c.card.id).toSet().length, 78);
  });
  test(
    'all spread positions match card counts and persist; old entries migrate',
    () {
      for (final spread in spreads) {
        final reading = Reading(
          id: spread.id,
          created: DateTime(2026, 10, 10),
          question: '问题',
          spread: spread.name,
          spreadId: spread.id,
          cards: drawCards(spread.count, Random(1)),
        );
        expect(reading.positions, spread.positions);
        expect(spread.points.length, spread.count);
        final restored = Reading.fromJson(reading.toJson());
        expect(restored.positions, spread.positions);
      }
      final legacy = Reading.fromJson({
        'id': 'old',
        'created': '2026-10-10T10:00:00',
        'question': '旧记录',
        'spread': '三张牌阵',
        'cards': drawCards(3, Random()).map((c) => c.toJson()).toList(),
        'note': '保留',
      });
      expect(legacy.positions.length, 3);
      expect(legacy.note, '保留');
      expect(legacy.aiText, '');
    },
  );
  test('delete is durable, undo restores notes and AI attribution', () async {
    final reading = Reading(
      id: 'delete',
      created: DateTime(2026, 10, 10),
      question: '问题',
      spread: '单张指引',
      spreadId: 'single',
      cards: [DrawnCard(deck.first)],
      aiText: 'AI 解读正文',
      aiProvider: 'DeepSeek 官方',
    );
    final store = JournalStore();
    await store.load();
    await store.save(reading, '保留感受');
    final removed = await store.delete({'delete'});
    expect(store.readings, isEmpty);
    final reloaded = JournalStore();
    await reloaded.load();
    expect(reloaded.readings, isEmpty);
    await store.restore(removed);
    await store.restore(removed);
    expect(store.readings.length, 1);
    final restored = JournalStore();
    await restored.load();
    expect(restored.readings.single.note, '保留感受');
    expect(restored.readings.single.aiText, 'AI 解读正文');
  });
  for (final provider in AiProvider.values) {
    test(
      '${provider.name} uses correct endpoint, key, model and session header',
      () async {
        final service = AiService(
          client: MockClient((request) async {
            expect(request.url.toString(), provider.endpoint);
            expect(request.headers['authorization'], 'Bearer test-only-key');
            final body = jsonDecode(request.body) as Map;
            expect(body['model'], provider.defaultModel);
            expect(body['stream'], false);
            if (provider == AiProvider.opencode) {
              expect(
                request.headers['x-opencode-session'],
                'emerald-tarot-reading-1',
              );
            }
            expect(request.body, contains('当前问题'));
            expect(request.body, isNot(contains('私密日记内容')));
            return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '这是一段测试解读。'},
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        final answer = await service.complete(
          provider: provider,
          key: 'test-only-key',
          model: provider.defaultModel,
          session: 'reading-1',
          prompt: '当前问题',
        );
        expect(answer, '这是一段测试解读。');
        service.close();
      },
    );
  }
  test(
    'errors are actionable, do not expose raw server response or key',
    () async {
      for (final status in [401, 402, 403, 404, 429, 500]) {
        final service = AiService(
          client: MockClient(
            (_) async => http.Response('secret-key-error-body', status),
          ),
        );
        try {
          await service.complete(
            provider: AiProvider.deepseek,
            key: 'secret-key',
            model: 'deepseek-flash',
            session: 'test',
            prompt: '测试',
          );
          fail('Should fail');
        } on AiException catch (e) {
          expect(e.message, isNot(contains('secret-key')));
          expect(e.message, isNotEmpty);
        }
        service.close();
      }
      final empty = AiService(
        client: MockClient(
          (_) async => http.Response(
            '{"choices":[{"message":{"reasoning_content":"do not show"}}]}',
            200,
          ),
        ),
      );
      await expectLater(
        empty.complete(
          provider: AiProvider.deepseek,
          key: 'test',
          model: 'deepseek-flash',
          session: 'test',
          prompt: '测试',
        ),
        throwsA(isA<AiException>()),
      );
      empty.close();
    },
  );
  testWidgets('ten-card spread scrolls and only unlocks after all ten flips', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final reading = Reading(
      id: 'ten',
      created: DateTime(2026),
      question: '测试完整十牌阵',
      spread: '凯尔特十字',
      spreadId: 'celtic',
      cards: deck.take(10).map((c) => DrawnCard(c)).toList(),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: tarotTheme(),
        home: DrawPage(reading: reading, journal: JournalStore()),
      ),
    );
    await t.pumpAndSettle();
    final button = find.byKey(const ValueKey('view-reading'));
    await t.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('flip-0')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    for (var i = 0; i < 10; i++) {
      final card = find.byKey(ValueKey('flip-$i'));
      await t.ensureVisible(card);
      await t.pumpAndSettle();
      await t.tap(card);
      await t.pumpAndSettle();
    }
    await t.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(t.widget<FilledButton>(button).onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('AI settings fits small screens and enlarged text', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: tarotTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const AiSettingsPage(),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('OpenCode Go'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('save-ai')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('save-ai')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'settings opens as page, AI entry is reachable, journal supports long press delete/undo',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final journal = JournalStore();
      await journal.load();
      await journal.save(
        Reading(
          id: 'one',
          created: DateTime(2026, 10, 10),
          question: '测试记录',
          spread: '每日一牌',
          cards: [DrawnCard(deck.first)],
        ),
        '测试感受',
      );
      await t.pumpWidget(TarotApp(journal: journal));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('设置'));
      await t.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await t.tap(find.text('AI 接入'));
      await t.pumpAndSettle();
      expect(find.byType(AiSettingsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('api-key')), findsOneWidget);
      await t.tap(find.text('OpenCode Go'));
      await t.pumpAndSettle();
      expect(find.text('deepseek-v4.1-flash'), findsWidgets);
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      await t.tap(find.text('日记').last);
      await t.pumpAndSettle();
      await t.longPress(find.byKey(const ValueKey('journal-one')));
      await t.pumpAndSettle();
      expect(find.text('已选 1 条'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('delete-selected')));
      await t.pumpAndSettle();
      expect(journal.readings, isEmpty);
      await t.tap(find.text('撤销'));
      await t.pumpAndSettle();
      expect(journal.readings.single.note, '测试感受');
      expect(t.takeException(), isNull);
    },
  );
}
