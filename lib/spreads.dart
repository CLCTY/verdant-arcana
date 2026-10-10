import 'localization.dart';
import 'package:flutter/material.dart';

class Spread {
  const Spread(
    this.id,
    this._name,
    this._description,
    this._positions,
    this.points,
  );
  final String id, _name, _description;
  String get name => tr(_name);
  String get description => tr(_description);
  List<String> get positions => _positions.map(tr).toList();
  final List<String> _positions;
  final List<Offset> points;
  int get count => positions.length;
}

const spreads = <Spread>[
  Spread('single', '单张指引', '聚焦当下，给自己一个思考的方向。', ['当下的指引'], [Offset(.5, .5)]),
  Spread(
    'choice',
    '二选一抉择',
    '分别看见两个选择所带来的可能。',
    ['选择 A', '选择 B'],
    [Offset(.32, .5), Offset(.68, .5)],
  ),
  Spread(
    'clarity',
    '是非澄清',
    '从支持与阻碍两个角度，澄清你的判断。',
    ['支持因素', '阻碍因素'],
    [Offset(.5, .28), Offset(.5, .72)],
  ),
  Spread(
    'three',
    '三张牌 · 现状',
    '现状、需要留意、可以尝试，梳理一个小行动。',
    ['当下的状态', '需要留意', '可以尝试'],
    [Offset(.2, .5), Offset(.5, .5), Offset(.8, .5)],
  ),
  Spread(
    'timeline',
    '三张牌 · 时间',
    '回顾过去、理解现在，探索未来的可能。',
    ['过去的影响', '现在的状态', '未来的可能'],
    [Offset(.2, .5), Offset(.5, .5), Offset(.8, .5)],
  ),
  Spread(
    'relationship',
    '关系之镜',
    '理解彼此的感受，以及关系中的连接。',
    ['我的感受', '对方的视角', '关系的连接'],
    [Offset(.25, .28), Offset(.75, .28), Offset(.5, .75)],
  ),
  Spread(
    'elements',
    '四元素',
    '从行动、感受、思考、现实四个方面看问题。',
    ['火 · 行动', '水 · 感受', '风 · 思考', '土 · 现实'],
    [Offset(.3, .28), Offset(.7, .28), Offset(.3, .72), Offset(.7, .72)],
  ),
  Spread(
    'cross',
    '五张十字',
    '聚焦核心，辨认阻碍、基础、建议与趋势。',
    ['问题核心', '当前阻碍', '内在基础', '行动建议', '发展趋势'],
    [
      Offset(.5, .5),
      Offset(.2, .5),
      Offset(.5, .8),
      Offset(.8, .5),
      Offset(.5, .2),
    ],
  ),
  Spread(
    'celtic',
    '凯尔特十字',
    '用十个位置深入梳理一个复杂问题。',
    [
      '当前处境',
      '交叉挑战',
      '深层基础',
      '过去影响',
      '意识目标',
      '近期发展',
      '自我态度',
      '环境影响',
      '期待与担忧',
      '可能结果',
    ],
    [
      Offset(.3, .45),
      Offset(.47, .45),
      Offset(.3, .75),
      Offset(.12, .45),
      Offset(.3, .15),
      Offset(.63, .45),
      Offset(.88, .84),
      Offset(.88, .61),
      Offset(.88, .38),
      Offset(.88, .15),
    ],
  ),
];

Spread spreadById(String id) =>
    spreads.firstWhere((s) => s.id == id, orElse: () => spreads[3]);

/// Numbered MD3 miniature cards describe positions rather than decorative art.
class SpreadDiagram extends StatelessWidget {
  const SpreadDiagram({super.key, required this.spread, this.selected = false});
  final Spread spread;
  final bool selected;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, box) {
        final scheme = Theme.of(context).colorScheme;
        final width = spread.count > 5 ? 10.0 : 17.0;
        final height = spread.count > 5 ? 15.0 : 26.0;
        return Stack(
          children: List.generate(
            spread.count,
            (i) => Positioned(
              left: spread.points[i].dx * (box.maxWidth - width),
              top: spread.points[i].dy * (box.maxHeight - height),
              width: width,
              height: height,
              child: Card.outlined(
                margin: EdgeInsets.zero,
                color: selected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                    color: scheme.secondary.withValues(
                      alpha: selected ? 1 : .5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    translateUi('${i + 1}', context),
                    style: TextStyle(
                      fontSize: spread.count > 5 ? 8 : 11,
                      color: scheme.secondary,
                      height: 1,
                    ),
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

class SpreadPicker extends StatefulWidget {
  const SpreadPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });
  final String selectedId;
  final ValueChanged<Spread> onChanged;
  @override
  State<SpreadPicker> createState() => _SpreadPickerState();
}

class _SpreadPickerState extends State<SpreadPicker> {
  late final ScrollController controller;
  @override
  void initState() {
    super.initState();
    final index = spreads.indexWhere((s) => s.id == widget.selectedId);
    controller = ScrollController(
      initialScrollOffset: (index * 136 - 136).clamp(0, 1088).toDouble(),
    );
  }

  @override
  void didUpdateWidget(SpreadPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId && controller.hasClients) {
      final index = spreads.indexWhere((s) => s.id == widget.selectedId);
      final offset =
          (index * 136 - (controller.position.viewportDimension - 126) / 2)
              .clamp(0, controller.position.maxScrollExtent)
              .toDouble();
      controller.animateTo(
        offset,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 172,
    child: ListView.separated(
      controller: controller,
      scrollDirection: Axis.horizontal,
      itemCount: spreads.length,
      separatorBuilder: (_, _) => SizedBox(width: 10),
      itemBuilder: (context, i) {
        final s = spreads[i],
            selected = s.id == widget.selectedId,
            scheme = Theme.of(context).colorScheme;
        return Semantics(
          button: true,
          selected: selected,
          label: translateUi('${s.name}，${s.count}张牌', context),
          child: SizedBox(
            width: 126,
            child: Card.outlined(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              color: selected
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: selected ? scheme.secondary : scheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: InkWell(
                key: ValueKey('spread-${s.id}'),
                onTap: () => widget.onChanged(s),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedScale(
                          scale: selected ? 1.04 : 1,
                          duration: Duration(milliseconds: 250),
                          child: SpreadDiagram(spread: s, selected: selected),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        translateUi(s.name, context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SizedBox(height: 4),
                      Text(
                        translateUi('${s.count} 张牌', context),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
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
