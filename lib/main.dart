import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'pages.dart';
import 'spreads.dart';
import 'settings.dart';
import 'ai.dart';
import 'journal.dart' as diary;

const emerald = Color(0xFF0C2923),
    rose = Color(0xFFD2AA8D),
    ivory = Color(0xFFF3EDDD),
    sage = Color(0xFFBFD5BE),
    muted = Color(0xFF9EB5A6);
const motion = Duration(milliseconds: 380);
bool reducedMotion(BuildContext c) => MediaQuery.disableAnimationsOf(c);
String shortDate(DateTime d) => '${d.month}月${d.day}日';
String longDate(DateTime d) =>
    '${shortDate(d)}  ${const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][d.weekday - 1]}';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final journal = JournalStore();
  await journal.load();
  await aiSettings.load();
  runApp(TarotApp(journal: journal));
}

ThemeData tarotTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF417B60),
        brightness: Brightness.dark,
      ).copyWith(
        primary: sage,
        onPrimary: emerald,
        primaryContainer: const Color(0xFF345E49),
        onPrimaryContainer: ivory,
        secondary: rose,
        onSecondary: emerald,
        secondaryContainer: const Color(0xFF345542),
        onSecondaryContainer: ivory,
        surface: emerald,
        onSurface: ivory,
        onSurfaceVariant: muted,
        surfaceContainerLowest: const Color(0xFF08201B),
        surfaceContainerLow: const Color(0xFF103027),
        surfaceContainer: const Color(0xFF13362D),
        surfaceContainerHigh: const Color(0xFF1C4135),
        surfaceContainerHighest: const Color(0xFF294D3F),
        outline: const Color(0xFF7A9485),
        outlineVariant: const Color(0xFF355347),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NotoSansSC',
  );
  return base.copyWith(
    scaffoldBackgroundColor: emerald,
    textTheme: base.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: emerald,
      foregroundColor: ivory,
      centerTitle: true,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF13362D),
      indicatorColor: Color(0xFF345E49),
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

class TarotApp extends StatelessWidget {
  const TarotApp({super.key, required this.journal});
  final JournalStore journal;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '翠启 · Verdant Arcana',
    debugShowCheckedModeBanner: false,
    theme: tarotTheme(),
    darkTheme: tarotTheme(),
    themeMode: ThemeMode.dark,
    builder: (context, child) => ColoredBox(
      color: const Color(0xFF061C17),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child!,
        ),
      ),
    ),
    home: AppShell(journal: journal),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.journal});
  final JournalStore journal;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  String spreadId = 'three';
  int get spreadSize => spreadById(spreadId).count;
  String topic = '自我';
  final question = TextEditingController();
  late final Reading daily;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now(), date = DateUtils.dateOnly(DateTime.now());
    final index =
        (deck.indexWhere((c) => c.id == 'star') +
            date.difference(DateTime(2026, 10, 10)).inDays) %
        deck.length;
    daily = Reading(
      id: 'daily-${date.toIso8601String()}',
      created: now,
      question: '今天，给自己的一个指引',
      spread: '每日一牌',
      cards: [DrawnCard(deck[index])],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.journal.loadError != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.journal.loadError!)));
      }
    });
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  void select(int value) {
    if (selected == value) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => selected = value);
  }

  void openReading(Reading reading) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReadingPage(reading: reading, journal: widget.journal),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final pages = [
      home(context),
      form(context),
      LibraryPage(
        onOpen: (card) => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => CardPage(card: card))),
      ),
      diary.JournalPage(journal: widget.journal, onOpen: openReading),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['翠启', '占卜', '牌库', '日记'][selected]),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined, color: rose),
            onPressed: () => settings(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: reducedMotion(context) ? Duration.zero : motion,
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .025),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(selected), child: pages[selected]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: select,
        animationDuration: reducedMotion(context) ? Duration.zero : motion,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.nights_stay_outlined),
            selectedIcon: Icon(Icons.nights_stay),
            label: '占卜',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: '牌库',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '日记',
          ),
        ],
      ),
    );
  }

  Widget home(BuildContext c) => LayoutBuilder(
    builder: (c, box) => SingleChildScrollView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Column(
        children: [
          Text(
            longDate(DateTime.now()),
            style: Theme.of(
              c,
            ).textTheme.labelLarge?.copyWith(color: muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          Text(
            '今日，听见内心',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSerifSC',
              fontSize: 28,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: ivory,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '留一点时间，给自己。',
            style: TextStyle(color: muted, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: (box.maxHeight * .32).clamp(156.0, 198.0),
            child: CardArt(
              card: daily.cards.first.card,
              heroTag: 'daily-card',
              label: '查看今日牌义',
              onTap: () => openReading(daily),
            ),
          ),
          const SizedBox(height: 14),
          const Chip(
            label: Text('今日一牌'),
            avatar: Icon(Icons.auto_awesome, size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${daily.cards.first.card.name} · 正位',
            style: const TextStyle(
              fontFamily: 'NotoSerifSC',
              fontSize: 24,
              height: 1.3,
              color: ivory,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            daily.cards.first.card.id == 'star'
                ? '为新的可能，留一盏灯。'
                : daily.cards.first.card.reflection,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: muted, height: 1.4),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('daily-reading'),
              onPressed: () => openReading(daily),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('查看今日指引'),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => select(1),
            child: const Text(
              '带着问题来？  开始一次占卜 →',
              style: TextStyle(color: rose),
            ),
          ),
        ],
      ),
    ),
  );
  Widget form(BuildContext c) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('此刻，你想问什么？', style: Theme.of(c).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('把问题留在这里，让牌成为一次思考的开始。', style: TextStyle(color: muted)),
      const SizedBox(height: 24),
      TextField(
        key: const ValueKey('question'),
        controller: question,
        maxLength: 200,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: '你的问题',
          hintText: '我可以怎样看待眼前的变化？',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: ['关系', '工作', '自我']
            .map(
              (t) => ChoiceChip(
                label: Text(t),
                selected: topic == t,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => topic = t);
                },
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 28),
      Text('选择牌阵', style: Theme.of(c).textTheme.titleLarge),
      const SizedBox(height: 16),
      SpreadPicker(
        selectedId: spreadId,
        onChanged: (s) {
          HapticFeedback.selectionClick();
          setState(() => spreadId = s.id);
        },
      ),
      const SizedBox(height: 20),
      AnimatedSwitcher(
        duration: motion,
        child: Card.filled(
          key: ValueKey(spreadId),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spreadById(spreadId).name,
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  spreadById(spreadId).description,
                  style: const TextStyle(color: muted, height: 1.7),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 32),
      FilledButton.icon(
        key: const ValueKey('start-reading'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始占卜'),
        onPressed: () {
          FocusScope.of(c).unfocus();
          final now = DateTime.now();
          final reading = Reading(
            id: 'reading-${now.microsecondsSinceEpoch}',
            created: now,
            question: question.text.trim().isEmpty
                ? '关于$topic，我现在可以关注什么？'
                : question.text.trim(),
            spread: spreadById(spreadId).name,
            spreadId: spreadId,
            cards: drawCards(spreadSize, Random()),
          );
          Navigator.of(c).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  DrawPage(reading: reading, journal: widget.journal),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      const Text(
        '给问题一点空间，也给自己一点时间。',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
  void settings(BuildContext c) => Navigator.of(
    c,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
}

class CardArt extends StatelessWidget {
  const CardArt({
    super.key,
    required this.card,
    this.onTap,
    this.heroTag,
    this.label,
    this.reversed = false,
  });
  final TarotCard card;
  final VoidCallback? onTap;
  final String? heroTag, label;
  final bool reversed;
  @override
  Widget build(BuildContext c) {
    Widget art = RotatedBox(
      quarterTurns: reversed ? 2 : 0,
      child: Image.asset(
        card.image,
        excludeFromSemantics: true,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
    if (heroTag != null) {
      art = Hero(tag: heroTag!, child: art);
    }
    return Semantics(
      label: label ?? '${card.name}，${reversed ? '逆位' : '正位'}',
      button: onTap != null,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: rose.withValues(alpha: .45)),
        ),
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(aspectRatio: 936 / 1681, child: art),
        ),
      ),
    );
  }
}
