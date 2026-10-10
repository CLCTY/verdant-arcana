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
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
                const SizedBox(height: 10),
                Text(
                  '${i + 1}. ${widget.reading.positions[i]}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  revealed.contains(i)
                      ? widget.reading.cards[i].card.name
                      : '轻触展开',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(widget.reading.spread)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.reading.question,
            textAlign: TextAlign.center,
            style: Theme.of(c).textTheme.titleLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            revealed.length == widget.reading.cards.length
                ? '牌面已展开，听听它们的故事。'
                : '深呼吸，点击牌背，让牌面慢慢展开。',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 26),
          LinearProgressIndicator(
            value: revealed.length / widget.reading.cards.length,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 36),
          AnimatedSwitcher(
            duration: motion,
            child: shuffling
                ? const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(semanticsLabel: '正在洗牌'),
                    ),
                  )
                : widget.reading.cards.length > 3
                ? KeyedSubtree(
                    key: ValueKey(shuffleKey),
                    child: expandedSpread(c),
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
                              const SizedBox(height: 14),
                              Text(
                                widget.reading.positions[i],
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: motion,
                                child: Text(
                                  revealed.contains(i)
                                      ? widget.reading.cards[i].card.name
                                      : '轻触展开',
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
          const SizedBox(height: 36),
          Text(
            '${revealed.length} / ${widget.reading.cards.length} 张已展开',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('view-reading'),
            onPressed:
                revealed.length == widget.reading.cards.length && !shuffling
                ? () => Navigator.of(c).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ReadingPage(
                        reading: widget.reading,
                        journal: widget.journal,
                      ),
                    ),
                  )
                : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('查看解读'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: revealed.isNotEmpty || shuffling
                ? null
                : () async {
                    HapticFeedback.selectionClick();
                    setState(() => shuffling = true);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 650),
                    );
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
            icon: const Icon(Icons.shuffle),
            label: const Text('重新洗牌'),
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
  Widget build(BuildContext c) => Semantics(
    button: true,
    label: revealed
        ? '${drawn.card.name}，${drawn.orientation}'
        : '展开第${index + 1}张牌',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: revealed ? 1 : 0),
      duration: reducedMotion(c)
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      builder: (c, value, _) {
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
        const SnackBar(
          content: Text('已保存到日记'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试。')));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.reading.spread == '每日一牌' ? '今日指引' : '牌阵解读'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            shortDate(widget.reading.created),
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 10),
          Text(
            widget.reading.question,
            style: Theme.of(c).textTheme.headlineSmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
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
                        onTap: () => Navigator.of(c).push(
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
                          onTap: () => Navigator.of(c).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CardPage(card: drawn.card),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reading.positions[i],
                              style: const TextStyle(color: rose),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${drawn.card.name} · ${drawn.orientation}',
                              style: Theme.of(c).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              drawn.card.keywords.join(' · '),
                              style: const TextStyle(color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                if (widget.reading.cards.length == 1) ...[
                  Center(
                    child: Text(
                      '${drawn.card.name} · ${drawn.orientation}',
                      style: Theme.of(c).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      children: drawn.card.keywords
                          .map((w) => Chip(label: Text(w)))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  drawn.meaning,
                  style: const TextStyle(fontSize: 16, height: 1.9),
                ),
                const SizedBox(height: 16),
                if (widget.reading.cards.length > 1) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),
          Card.filled(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: rose),
                      const SizedBox(width: 10),
                      Text(
                        '给自己的一个问题',
                        style: Theme.of(c).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.reading.cards.last.card.reflection,
                    style: const TextStyle(height: 1.8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          AiReadingPanel(
            reading: widget.reading,
            onChanged: () => setState(() => saved = false),
          ),
          const SizedBox(height: 28),
          Text('此刻的感受', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('journal-note'),
            controller: note,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            onChanged: (_) {
              if (saved) {
                setState(() => saved = false);
              }
            },
            decoration: const InputDecoration(hintText: '写下你看见的、感受到的…'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('save-journal'),
            onPressed: saving ? null : save,
            icon: AnimatedSwitcher(
              duration: motion,
              child: saving
                  ? const SizedBox(
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
            label: Text(saved ? '已保存到日记' : '保存到日记'),
          ),
          const SizedBox(height: 16),
          const Text(
            '解读是一种思考的视角，行动与选择仍然属于你。',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12, height: 1.7),
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
  Widget build(BuildContext c) {
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
      padding: const EdgeInsets.all(24),
      children: [
        Text('认识每一张牌', style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('从象征出发，找到属于你的理解。', style: TextStyle(color: muted)),
        const SizedBox(height: 24),
        SearchBar(
          key: const ValueKey('card-search'),
          hintText: '搜索牌名或关键词',
          leading: const Icon(Icons.search),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 24),
        Text(
          '$category · ${cards.length} 张',
          style: Theme.of(c).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['全部', '大阿卡纳', '权杖', '圣杯', '宝剑', '星币']
                .map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: category == label,
                      onSelected: (_) => setState(() => category = label),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: motion,
          child: cards.isEmpty
              ? const Padding(
                  key: ValueKey('empty'),
                  padding: EdgeInsets.all(32),
                  child: Text('没有找到这张牌，试试其他关键词。'),
                )
              : LayoutBuilder(
                  builder: (c, box) {
                    final scaler = MediaQuery.textScalerOf(c);
                    final columns = scaler.scale(16) > 21 ? 1 : 2;
                    final cardWidth =
                        (box.maxWidth - (columns - 1) * 16) / columns;
                    return GridView.builder(
                      key: ValueKey(cards.map((c) => c.id).join()),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 16,
                        mainAxisExtent:
                            cardWidth / (936 / 1681) + 14 + scaler.scale(80),
                      ),
                      itemBuilder: (c, i) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CardArt(
                            card: cards[i],
                            heroTag: 'library-${cards[i].id}',
                            onTap: () => widget.onOpen(cards[i]),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${cards[i].number}  ${cards[i].name}',
                            style: Theme.of(c).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cards[i].keywords.join(' · '),
                            style: const TextStyle(color: muted, fontSize: 11),
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
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(widget.card.name)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: SizedBox(
              width: 200,
              child: AnimatedRotation(
                turns: reversed ? .5 : 0,
                duration: reducedMotion(c) ? Duration.zero : motion,
                curve: Curves.easeInOutCubic,
                child: CardArt(
                  card: widget.card,
                  heroTag: 'library-${widget.card.id}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              widget.card.english,
              style: const TextStyle(color: rose, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('正位')),
              ButtonSegment(value: true, label: Text('逆位')),
            ],
            selected: {reversed},
            onSelectionChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => reversed = v.first);
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: widget.card.keywords
                .map((w) => Chip(label: Text(w)))
                .toList(),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: motion,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: motion,
              child: Text(
                reversed ? widget.card.reverse : widget.card.meaning,
                key: ValueKey(reversed),
                style: const TextStyle(fontSize: 16, height: 1.9),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.card.reflection,
            style: const TextStyle(color: rose, height: 1.8),
          ),
        ],
      ),
    ),
  );
}
