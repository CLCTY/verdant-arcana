import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spreads.dart';
import 'localization.dart';
part 'deck.dart';

class TarotCard {
  const TarotCard(
    this.id,
    this.number,
    this._name,
    this.english,
    this._keywords,
    this._meaning,
    this._reverse,
    this._reflection, {
    this.category = '大阿卡纳',
  });
  final String id, number, _name, english, _meaning, _reverse, _reflection;
  final String category;
  final List<String> _keywords;
  String get name => cardName(id, _name, english);
  List<String> get keywords => cardWords(id, _keywords);
  String get meaning => cardCopy(id, 'meaning', _meaning);
  String get reverse => cardCopy(id, 'reverse', _reverse);
  String get reflection => cardCopy(id, 'reflection', _reflection);
  String get image => 'assets/cards/$id.png';
}

const previewDeck = <TarotCard>[
  TarotCard(
    'star',
    'XVII',
    '星星',
    'THE STAR',
    ['希望', '疗愈', '信任'],
    '星星象征经历变化后重新建立的希望。它邀请你把注意力放在可以慢慢恢复的事物上，让一个小小的行动成为新的起点。',
    '你可能暂时难以相信自己的方向。允许疲惫存在，把期待缩小到今天可以完成的一件事。',
    '今天，你愿意为哪一个新的可能留一盏灯？',
  ),
  TarotCard(
    'moon',
    'XVIII',
    '月亮',
    'THE MOON',
    ['觉察', '直觉', '未知'],
    '月亮提醒你，感受与事实有时会交织在一起。先承认自己的不安，再为尚未清晰的事情寻找具体信息。此刻可以容纳未知，不必急着下结论。',
    '模糊的感受可能正在变得清晰。整理你已经知道的事实，给自己一点时间分辨担忧与真实的需要。',
    '有什么尚未确定的事情，值得你温柔地面对？',
  ),
  TarotCard(
    'sun',
    'XIX',
    '太阳',
    'THE SUN',
    ['清晰', '喜悦', '成长'],
    '太阳象征清晰、活力与坦诚。留意生活里已经发生的进展，也可以把想法说得更直接一点，让行动和真实的感受保持一致。',
    '快乐可能被过高的期待遮住了。暂停比较，看见已经拥有的支持，让计划回到适合自己的节奏。',
    '今天哪一个微小的进展，值得被你看见？',
  ),
];

class DrawnCard {
  const DrawnCard(this.card, {this.reversed = false});
  final TarotCard card;
  final bool reversed;
  String get orientation => tr(reversed ? '逆位' : '正位');
  String get meaning => reversed ? card.reverse : card.meaning;
  Map<String, Object> toJson() => {'id': card.id, 'reversed': reversed};
  factory DrawnCard.fromJson(Map<String, dynamic> json) => DrawnCard(
    deck.firstWhere((card) => card.id == json['id']),
    reversed: json['reversed'] == true,
  );
}

List<DrawnCard> drawCards(int count, Random random) {
  if (count < 1 || count > deck.length) {
    throw RangeError.range(count, 1, deck.length);
  }
  final shuffled = List<TarotCard>.of(deck)..shuffle(random);
  return shuffled
      .take(count)
      .map((card) => DrawnCard(card, reversed: random.nextBool()))
      .toList();
}

class Reading {
  Reading({
    required this.id,
    required this.created,
    required this.question,
    required this.spread,
    required this.cards,
    this.note = '',
    this.spreadId = '',
    this.aiText = '',
    this.aiProvider = '',
  });
  final String id, question, spread, spreadId;
  final DateTime created;
  final List<DrawnCard> cards;
  String note;
  String aiText, aiProvider;
  List<String> get positions {
    if (spreadId.isNotEmpty) {
      final definition = spreadById(spreadId);
      if (definition.count == cards.length) return definition.positions;
    }
    return cards.length == 1
        ? [tr('今日指引')]
        : cards.length == 3
        ? ['当下的状态', '需要留意', '可以尝试'].map(tr).toList()
        : List.generate(cards.length, (i) => '${tr('位置')} ${i + 1}');
  }

  Map<String, Object> toJson() => {
    'id': id,
    'created': created.toIso8601String(),
    'question': question,
    'spread': spread,
    'cards': cards.map((c) => c.toJson()).toList(),
    'note': note,
    'spreadId': spreadId,
    'aiText': aiText,
    'aiProvider': aiProvider,
  };
  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
    id: json['id'] as String,
    created: DateTime.parse(json['created'] as String),
    question: json['question'] as String,
    spread: json['spread'] as String,
    note: json['note'] as String? ?? '',
    spreadId: json['spreadId'] as String? ?? '',
    aiText: json['aiText'] as String? ?? '',
    aiProvider: json['aiProvider'] as String? ?? '',
    cards: (json['cards'] as List)
        .map((c) => DrawnCard.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(),
  );
}

class JournalStore extends ChangeNotifier {
  static const storageKey = 'emerald_tarot_readings_v1';
  final List<Reading> _readings = [];
  List<Reading> get readings => List.unmodifiable(_readings);
  String? loadError;
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        _readings.addAll(
          (jsonDecode(raw) as List).map(
            (r) => Reading.fromJson(Map<String, dynamic>.from(r as Map)),
          ),
        );
        _readings.sort((a, b) => b.created.compareTo(a.created));
      }
    } catch (_) {
      loadError = '暂时无法读取日记，请稍后重试。';
    }
    notifyListeners();
  }

  bool contains(String id) => _readings.any((r) => r.id == id);
  Future<void> save(Reading reading, String note) async {
    final replacement = Reading(
      id: reading.id,
      created: reading.created,
      question: reading.question,
      spread: reading.spread,
      cards: reading.cards,
      note: note,
      spreadId: reading.spreadId,
      aiText: reading.aiText,
      aiProvider: reading.aiProvider,
    );
    final updated = List<Reading>.of(_readings);
    final index = updated.indexWhere((r) => r.id == reading.id);
    if (index >= 0) {
      updated[index] = replacement;
    } else {
      updated.insert(0, replacement);
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey,
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    )) {
      throw StateError('Could not save journal');
    }
    _readings
      ..clear()
      ..addAll(updated);
    reading.note = note;
    notifyListeners();
  }

  Future<List<Reading>> delete(Set<String> ids) async {
    final removed = _readings.where((r) => ids.contains(r.id)).toList();
    final remaining = _readings.where((r) => !ids.contains(r.id)).toList();
    await _persist(remaining);
    _readings
      ..clear()
      ..addAll(remaining);
    notifyListeners();
    return removed;
  }

  Future<void> restore(List<Reading> removed) async {
    final updated = [..._readings, ...removed.where((r) => !contains(r.id))]
      ..sort((a, b) => b.created.compareTo(a.created));
    await _persist(updated);
    _readings
      ..clear()
      ..addAll(updated);
    notifyListeners();
  }

  Future<void> _persist(List<Reading> readings) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey,
      jsonEncode(readings.map((r) => r.toJson()).toList()),
    )) {
      throw StateError('Could not save journal');
    }
  }
}
