import 'localization.dart';
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models.dart';
import 'pages.dart';
import 'spreads.dart';
import 'settings.dart';
import 'ai.dart';
import 'journal.dart' as diary;

const motion = Duration(milliseconds: 380);
bool reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);
String shortDate(DateTime d) => localizedDate(d);
String longDate(DateTime d) => localizedDate(d, weekday: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final journal = JournalStore();
  await journal.load();
  await aiSettings.load();
  await appPreferences.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(TarotApp(journal: journal));
}

ThemeData tarotTheme([ColorScheme? dynamicScheme]) {
  final scheme =
      (dynamicScheme ??
              ColorScheme.fromSeed(
                seedColor: const Color(0xFF417B60),
                brightness: Brightness.dark,
              ))
          .copyWith(
            surface: Colors.black,
            surfaceContainerLowest: Colors.black,
          );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appPreferences.language == 'ja' ? null : 'NotoSansSC',
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: scheme.onSurface,
      centerTitle: true,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
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

class TarotApp extends StatefulWidget {
  const TarotApp({super.key, required this.journal});
  final JournalStore journal;
  @override
  State<TarotApp> createState() => _TarotAppState();
}

class _TarotAppState extends State<TarotApp> with WidgetsBindingObserver {
  final paletteKey = GlobalKey<DynamicColorBuilderState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      paletteKey.currentState?.initPlatformState();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appPreferences,
    builder: (context, _) => DynamicColorBuilder(
      key: paletteKey,
      builder: (_, dark) => MaterialApp(
        title: '星笺 · Arcana Notes',
        debugShowCheckedModeBanner: false,
        locale: Locale(appPreferences.language),
        supportedLocales: [Locale('zh'), Locale('en'), Locale('ja')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: tarotTheme(dark),
        darkTheme: tarotTheme(dark),
        themeMode: ThemeMode.dark,
        builder: (context, child) => AppLocaleScope(
          child: ColoredBox(
            color: Colors.black,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520),
                child: child!,
              ),
            ),
          ),
        ),
        home: AppShell(journal: widget.journal),
      ),
    ),
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
  final pageController = PageController();
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
        (deck.indexWhere((context) => context.id == 'star') +
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translateUi(widget.journal.loadError!, context)),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    pageController.dispose();
    question.dispose();
    super.dispose();
  }

  void select(int value) {
    if (selected == value) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => selected = value);
    if (reducedMotion(context)) {
      pageController.jumpToPage(value);
    } else {
      pageController.animateToPage(
        value,
        duration: motion,
        curve: Curves.easeOutCubic,
      );
    }
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
        title: Text(translateUi(['星笺', '占卜', '牌库', '日记'][selected], context)),
        actions: [
          IconButton(
            tooltip: translateUi('设置', context),
            icon: Icon(
              Icons.settings_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () => settings(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              ...ScrollConfiguration.of(context).dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: PageView(
            key: const ValueKey('main-pages'),
            controller: pageController,
            onPageChanged: (value) => setState(() => selected = value),
            children: [for (final page in pages) _RetainedPage(child: page)],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: select,
        animationDuration: reducedMotion(context) ? Duration.zero : motion,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: translateUi('今日', context),
          ),
          NavigationDestination(
            icon: Icon(Icons.nights_stay_outlined),
            selectedIcon: Icon(Icons.nights_stay),
            label: translateUi('占卜', context),
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: translateUi('牌库', context),
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: translateUi('日记', context),
          ),
        ],
      ),
    );
  }

  Widget home(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      key: PageStorageKey('home'),
      padding: EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Column(
        children: [
          Text(
            translateUi(longDate(DateTime.now()), context),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20),
          Text(
            translateUi('今日，听见内心', context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: appPreferences.language == 'ja'
                  ? null
                  : 'NotoSerifSC',
              fontSize: 28,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8),
          Text(
            translateUi('留一点时间，给自己。', context),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          SizedBox(height: 22),
          SizedBox(
            width: (box.maxHeight * .32).clamp(156.0, 198.0),
            child: CardArt(
              card: daily.cards.first.card,
              heroTag: 'daily-card',
              label: translateUi('查看今日牌义', context),
              onTap: () => openReading(daily),
            ),
          ),
          SizedBox(height: 14),
          Chip(
            label: Text(translateUi('今日一牌', context)),
            avatar: Icon(Icons.auto_awesome, size: 16),
          ),
          SizedBox(height: 4),
          Text(
            translateUi('${daily.cards.first.card.name} · 正位', context),
            style: TextStyle(
              fontFamily: appPreferences.language == 'ja'
                  ? null
                  : 'NotoSerifSC',
              fontSize: 24,
              height: 1.3,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            translateUi(
              daily.cards.first.card.id == 'star'
                  ? '为新的可能，留一盏灯。'
                  : daily.cards.first.card.reflection,
              context,
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: ValueKey('daily-reading'),
              onPressed: () => openReading(daily),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(translateUi('查看今日指引', context)),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () => select(1),
            child: Text(
              translateUi('带着问题来？  开始一次占卜 →', context),
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
        ],
      ),
    ),
  );
  Widget form(BuildContext context) => ListView(
    padding: EdgeInsets.all(24),
    children: [
      Text(
        translateUi('此刻，你想问什么？', context),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      SizedBox(height: 8),
      Text(
        translateUi('把问题留在这里，让牌成为一次思考的开始。', context),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      SizedBox(height: 24),
      TextField(
        key: ValueKey('question'),
        controller: question,
        maxLength: 200,
        minLines: 3,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: translateUi('你的问题', context),
          hintText: translateUi('我可以怎样看待眼前的变化？', context),
          alignLabelWithHint: true,
        ),
      ),
      SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: ['关系', '工作', '自我']
            .map(
              (t) => ChoiceChip(
                label: Text(translateUi(t, context)),
                selected: topic == t,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => topic = t);
                },
              ),
            )
            .toList(),
      ),
      SizedBox(height: 28),
      Text(
        translateUi('选择牌阵', context),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      SizedBox(height: 16),
      SpreadPicker(
        selectedId: spreadId,
        onChanged: (s) {
          HapticFeedback.selectionClick();
          setState(() => spreadId = s.id);
        },
      ),
      SizedBox(height: 20),
      AnimatedSwitcher(
        duration: motion,
        child: Card.filled(
          key: ValueKey(spreadId),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateUi(spreadById(spreadId).name, context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 12),
                Text(
                  translateUi(spreadById(spreadId).description, context),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(height: 32),
      FilledButton.icon(
        key: ValueKey('start-reading'),
        icon: Icon(Icons.auto_awesome),
        label: Text(translateUi('开始占卜', context)),
        onPressed: () {
          FocusScope.of(context).unfocus();
          final now = DateTime.now();
          final reading = Reading(
            id: 'reading-${now.microsecondsSinceEpoch}',
            created: now,
            question: question.text.trim().isEmpty
                ? tr('关于$topic，我现在可以关注什么？')
                : question.text.trim(),
            spread: spreadById(spreadId).name,
            spreadId: spreadId,
            cards: drawCards(spreadSize, Random()),
          );
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  DrawPage(reading: reading, journal: widget.journal),
            ),
          );
        },
      ),
      SizedBox(height: 16),
      Text(
        translateUi('给问题一点空间，也给自己一点时间。', context),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    ],
  );
  void settings(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SettingsPage()));
}

class _RetainedPage extends StatefulWidget {
  const _RetainedPage({required this.child});
  final Widget child;
  @override
  State<_RetainedPage> createState() => _RetainedPageState();
}

class _RetainedPageState extends State<_RetainedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
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
  Widget build(BuildContext context) {
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
      label: label ?? tr('${card.name}，${reversed ? '逆位' : '正位'}', context),
      button: onTap != null,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: .45),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(aspectRatio: 936 / 1681, child: art),
        ),
      ),
    );
  }
}
