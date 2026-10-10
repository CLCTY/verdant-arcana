import 'localization.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'models.dart';
import 'ai_panel.dart';
import 'spreads.dart';

class DrawPage extends StatefulWidget {
  const DrawPage({super.key, required this.reading, required this.journal});
  final Reading reading;
  final JournalStore journal;
  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final revealed = <int>{};
  bool shuffling = false;
  int shuffleKey = 0;
  Widget expandedSpread(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = MediaQuery.textScalerOf(context).scale(16) > 21 ? 2 : 3;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Column(
        children: [
          if (widget.reading.spreadId.isNotEmpty)
            SizedBox(
              height: 90,
              width: 170,
              child: SpreadDiagram(spread: spreadById(widget.reading.spreadId)),
            ),
          SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: widget.reading.cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              mainAxisExtent:
                  width / (936 / 1681) +
                  MediaQuery.textScalerOf(context).scale(90),
            ),
            itemBuilder: (context, i) => Column(
              children: [
                FlipCard(
                  drawn: widget.reading.cards[i],
                  index: i,
                  revealed: revealed.contains(i),
                  onTap: () {
                    if (revealed.contains(i)) return;
                    HapticFeedback.lightImpact();
                    setState(() => revealed.add(i));
                  },
                ),
                SizedBox(height: 10),
                Text(
                  translateUi(
                    '${i + 1}. ${widget.reading.positions[i]}',
                    context,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  translateUi(
                    revealed.contains(i)
                        ? widget.reading.cards[i].card.name
                        : '轻触展开',
                    context,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(translateUi(widget.reading.spread, context))),
    body: SafeArea(
      child: ListView(
        padding: EdgeInsets.all(24),
        children: [
          Text(
            widget.reading.id.startsWith('daily-')
                ? tr(widget.reading.question, context)
                : widget.reading.question,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(height: 1.5),
          ),
          SizedBox(height: 16),
          Text(
            translateUi(
              revealed.length == widget.reading.cards.length
                  ? '牌面已展开，听听它们的故事。'
                  : '深呼吸，点击牌背，让牌面慢慢展开。',
              context,
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 26),
          LinearProgressIndicator(
            value: revealed.length / widget.reading.cards.length,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
          SizedBox(height: 36),
          AnimatedSwitcher(
            duration: motion,
            child: shuffling
                ? SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: translateUi('正在洗牌', context),
                      ),
                    ),
                  )
                : widget.reading.cards.length > 3
                ? KeyedSubtree(
                    key: ValueKey(shuffleKey),
                    child: expandedSpread(context),
                  )
                : Row(
                    key: ValueKey(shuffleKey),
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      widget.reading.cards.length,
                      (i) => Flexible(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.reading.cards.length == 1
                                ? 56
                                : 4,
                          ),
                          child: Column(
                            children: [
                              FlipCard(
                                drawn: widget.reading.cards[i],
                                index: i,
                                revealed: revealed.contains(i),
                                onTap: () {
                                  if (revealed.contains(i)) {
                                    return;
                                  }
                                  HapticFeedback.lightImpact();
                                  setState(() => revealed.add(i));
                                },
                              ),
                              SizedBox(height: 14),
                              Text(
                                translateUi(
                                  widget.reading.positions[i],
                                  context,
                                ),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: motion,
                                child: Text(
                                  translateUi(
                                    revealed.contains(i)
                                        ? widget.reading.cards[i].card.name
                                        : '轻触展开',
                                    context,
                                  ),
                                  key: ValueKey(revealed.contains(i)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          SizedBox(height: 36),
          Text(
            translateUi(
              '${revealed.length} / ${widget.reading.cards.length} 张已展开',
              context,
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 24),
          FilledButton.icon(
            key: ValueKey('view-reading'),
            onPressed:
                revealed.length == widget.reading.cards.length && !shuffling
                ? () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ReadingPage(
                        reading: widget.reading,
                        journal: widget.journal,
                      ),
                    ),
                  )
                : null,
            icon: Icon(Icons.auto_awesome),
            label: Text(translateUi('查看解读', context)),
          ),
          SizedBox(height: 12),
          TextButton.icon(
            onPressed: revealed.isNotEmpty || shuffling
                ? null
                : () async {
                    HapticFeedback.selectionClick();
                    setState(() => shuffling = true);
                    await Future<void>.delayed(Duration(milliseconds: 650));
                    if (!mounted) {
                      return;
                    }
                    final cards = drawCards(
                      widget.reading.cards.length,
                      Random(),
                    );
                    setState(() {
                      widget.reading.cards
                        ..clear()
                        ..addAll(cards);
                      shuffling = false;
                      shuffleKey++;
                    });
                  },
            icon: Icon(Icons.shuffle),
            label: Text(translateUi('重新洗牌', context)),
          ),
        ],
      ),
    ),
  );
}

class FlipCard extends StatelessWidget {
  const FlipCard({
    super.key,
    required this.drawn,
    required this.revealed,
    required this.index,
    required this.onTap,
  });
  final DrawnCard drawn;
  final bool revealed;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: revealed
        ? '${drawn.card.name}，${drawn.orientation}'
        : tr('展开第${index + 1}张牌', context),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: revealed ? 1 : 0),
      duration: reducedMotion(context)
          ? Duration.zero
          : Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final front = value >= .5,
            angle = value >= .5 ? (1 - value) * pi : value * pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0015)
            ..rotateY(angle),
          child: Card.outlined(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('flip-$index'),
              onTap: onTap,
              child: AspectRatio(
                aspectRatio: 936 / 1681,
                child: RotatedBox(
                  quarterTurns: front && drawn.reversed ? 2 : 0,
                  child: Image.asset(
                    front ? drawn.card.image : 'assets/cards/back.png',
                    excludeFromSemantics: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key, required this.reading, required this.journal});
  final Reading reading;
  final JournalStore journal;
  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late final TextEditingController note;
  bool saving = false, saved = false;
  @override
  void initState() {
    super.initState();
    note = TextEditingController(text: widget.reading.note);
    saved = widget.journal.contains(widget.reading.id);
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.journal.save(widget.reading, note.text.trim());
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() {
        saved = true;
        saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translateUi('已保存到日记', context)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translateUi('保存失败，请重试。', context))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        translateUi(widget.reading.spread == '每日一牌' ? '今日指引' : '牌阵解读', context),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: EdgeInsets.all(24),
        children: [
          Text(
            translateUi(shortDate(widget.reading.created), context),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 10),
          Text(
            widget.reading.id.startsWith('daily-')
                ? tr(widget.reading.question, context)
                : widget.reading.question,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(height: 1.5),
          ),
          SizedBox(height: 24),
          ...List.generate(widget.reading.cards.length, (i) {
            final drawn = widget.reading.cards[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.reading.cards.length == 1)
                  Center(
                    child: SizedBox(
                      width: 180,
                      child: CardArt(
                        card: drawn.card,
                        reversed: drawn.reversed,
                        heroTag: widget.reading.spread == '每日一牌'
                            ? 'daily-card'
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CardPage(card: drawn.card),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 76,
                        child: CardArt(
                          card: drawn.card,
                          reversed: drawn.reversed,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CardPage(card: drawn.card),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translateUi(widget.reading.positions[i], context),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              translateUi(
                                '${drawn.card.name} · ${drawn.orientation}',
                                context,
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: 8),
                            Text(
                              translateUi(
                                drawn.card.keywords.join(' · '),
                                context,
                              ),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 20),
                if (widget.reading.cards.length == 1) ...[
                  Center(
                    child: Text(
                      translateUi(
                        '${drawn.card.name} · ${drawn.orientation}',
                        context,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      children: drawn.card.keywords
                          .map(
                            (w) => Chip(label: Text(translateUi(w, context))),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                Text(
                  translateUi(drawn.meaning, context),
                  style: TextStyle(fontSize: 16, height: 1.9),
                ),
                SizedBox(height: 16),
                if (widget.reading.cards.length > 1) ...[
                  Divider(),
                  SizedBox(height: 16),
                ],
              ],
            );
          }),
          Card.filled(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 10),
                      Text(
                        translateUi('给自己的一个问题', context),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    translateUi(
                      widget.reading.cards.last.card.reflection,
                      context,
                    ),
                    style: TextStyle(height: 1.8),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 28),
          AiReadingPanel(
            reading: widget.reading,
            onChanged: () => setState(() => saved = false),
          ),
          SizedBox(height: 28),
          Text(
            translateUi('此刻的感受', context),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 12),
          TextField(
            key: ValueKey('journal-note'),
            controller: note,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            onChanged: (_) {
              if (saved) {
                setState(() => saved = false);
              }
            },
            decoration: InputDecoration(
              hintText: translateUi('写下你看见的、感受到的…', context),
            ),
          ),
          SizedBox(height: 12),
          FilledButton.icon(
            key: ValueKey('save-journal'),
            onPressed: saving ? null : save,
            icon: AnimatedSwitcher(
              duration: motion,
              child: saving
                  ? SizedBox(
                      key: ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      saved ? Icons.check : Icons.bookmark_outline,
                      key: ValueKey(saved),
                    ),
            ),
            label: Text(translateUi(saved ? '已保存到日记' : '保存到日记', context)),
          ),
          SizedBox(height: 16),
          Text(
            translateUi('解读是一种思考的视角，行动与选择仍然属于你。', context),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ],
      ),
    ),
  );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.onOpen});
  final ValueChanged<TarotCard> onOpen;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String query = '';
  String category = '全部';
  @override
  Widget build(BuildContext context) {
    final cards = deck
        .where(
          (card) =>
              (category == '全部' || card.category == category) &&
              '${card.name} ${card.english} ${card.keywords.join(' ')}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text(
          translateUi('认识每一张牌', context),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        Text(
          translateUi('从象征出发，找到属于你的理解。', context),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 24),
        SearchBar(
          key: ValueKey('card-search'),
          hintText: translateUi('搜索牌名或关键词', context),
          leading: Icon(Icons.search),
          onChanged: (v) => setState(() => query = v),
        ),
        SizedBox(height: 24),
        Text(
          translateUi('$category · ${cards.length} 张', context),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['全部', '大阿卡纳', '权杖', '圣杯', '宝剑', '星币']
                .map(
                  (label) => Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(translateUi(label, context)),
                      selected: category == label,
                      onSelected: (_) => setState(() => category = label),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(height: 16),
        AnimatedSwitcher(
          duration: motion,
          child: cards.isEmpty
              ? Padding(
                  key: ValueKey('empty'),
                  padding: EdgeInsets.all(32),
                  child: Text(translateUi('没有找到这张牌，试试其他关键词。', context)),
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    final scaler = MediaQuery.textScalerOf(context);
                    final columns = scaler.scale(16) > 21 ? 1 : 2;
                    final cardWidth =
                        (box.maxWidth - (columns - 1) * 16) / columns;
                    return GridView.builder(
                      key: ValueKey(cards.map((context) => context.id).join()),
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 16,
                        mainAxisExtent:
                            cardWidth / (936 / 1681) + 14 + scaler.scale(80),
                      ),
                      itemBuilder: (context, i) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CardArt(
                            card: cards[i],
                            heroTag: 'library-${cards[i].id}',
                            onTap: () => widget.onOpen(cards[i]),
                          ),
                          SizedBox(height: 10),
                          Text(
                            translateUi(
                              '${cards[i].number}  ${cards[i].name}',
                              context,
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: 4),
                          Text(
                            translateUi(cards[i].keywords.join(' · '), context),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class CardPage extends StatefulWidget {
  const CardPage({super.key, required this.card});
  final TarotCard card;
  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  bool reversed = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(translateUi(widget.card.name, context))),
    body: SafeArea(
      child: ListView(
        padding: EdgeInsets.all(24),
        children: [
          Center(
            child: SizedBox(
              width: 200,
              child: AnimatedRotation(
                turns: reversed ? .5 : 0,
                duration: reducedMotion(context) ? Duration.zero : motion,
                curve: Curves.easeInOutCubic,
                child: CardArt(
                  card: widget.card,
                  heroTag: 'library-${widget.card.id}',
                ),
              ),
            ),
          ),
          SizedBox(height: 24),
          Center(
            child: Text(
              translateUi(widget.card.english, context),
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                letterSpacing: 2,
              ),
            ),
          ),
          SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(translateUi('正位', context)),
              ),
              ButtonSegment(
                value: true,
                label: Text(translateUi('逆位', context)),
              ),
            ],
            selected: {reversed},
            onSelectionChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => reversed = v.first);
            },
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: widget.card.keywords
                .map((w) => Chip(label: Text(translateUi(w, context))))
                .toList(),
          ),
          SizedBox(height: 16),
          AnimatedSize(
            duration: motion,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: motion,
              child: Text(
                translateUi(
                  reversed ? widget.card.reverse : widget.card.meaning,
                  context,
                ),
                key: ValueKey(reversed),
                style: TextStyle(fontSize: 16, height: 1.9),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            translateUi(widget.card.reflection, context),
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              height: 1.8,
            ),
          ),
        ],
      ),
    ),
  );
}
