import 'localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'main.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, required this.journal, required this.onOpen});
  final JournalStore journal;
  final ValueChanged<Reading> onOpen;
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final selected = <String>{};
  bool busy = false;
  void toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!selected.add(id)) selected.remove(id);
    });
  }

  Future<void> remove() async {
    if (selected.isEmpty) return;
    setState(() => busy = true);
    try {
      final removed = await widget.journal.delete(Set.of(selected));
      if (!mounted) return;
      setState(() => selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translateUi('已删除 ${removed.length} 条记录', context)),
          duration: Duration(seconds: 8),
          action: SnackBarAction(
            label: translateUi('撤销', context),
            onPressed: () async {
              try {
                await widget.journal.restore(removed);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(translateUi('恢复失败，请重试。', context))),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateUi('删除失败，请重试。', context))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.journal,
    builder: (context, _) {
      final records = widget.journal.readings;
      if (records.isEmpty) {
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 48,
                ),
                SizedBox(height: 24),
                Text(
                  translateUi('把此刻，留给未来的自己', context),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                Text(
                  translateUi('完成一次抽牌后，保存解读和感受。\n你的记录会在这里慢慢积累。', context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return ListView(
        padding: EdgeInsets.all(24),
        children: [
          if (selected.isEmpty) ...[
            Text(
              translateUi('留住每一次看见', context),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Text(
              translateUi('${records.length} 次记录 · 长按可选择删除', context),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else
            Card.filled(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        translateUi('已选 ${selected.length} 条', context),
                      ),
                    ),
                    IconButton(
                      tooltip: translateUi('全选', context),
                      onPressed: busy
                          ? null
                          : () => setState(
                              () => selected.addAll(records.map((r) => r.id)),
                            ),
                      icon: Icon(Icons.done_all),
                    ),
                    IconButton(
                      key: ValueKey('delete-selected'),
                      tooltip: translateUi('删除所选记录', context),
                      onPressed: busy ? null : remove,
                      icon: Icon(Icons.delete_outline),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => selected.clear()),
                      child: Text(translateUi('取消', context)),
                    ),
                  ],
                ),
              ),
            ),
          if (busy) ...[SizedBox(height: 12), LinearProgressIndicator()],
          SizedBox(height: 24),
          ...records.map(
            (r) => Column(
              children: [
                ListTile(
                  key: ValueKey('journal-${r.id}'),
                  selected: selected.contains(r.id),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      r.cards.first.card.image,
                      width: 38,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    r.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      translateUi(
                        '${shortDate(r.created)} · ${tr(r.spread)}',
                        context,
                      ),
                    ),
                  ),
                  trailing: selected.isNotEmpty
                      ? Checkbox(
                          value: selected.contains(r.id),
                          onChanged: busy ? null : (_) => toggle(r.id),
                        )
                      : Icon(Icons.chevron_right),
                  onLongPress: busy ? null : () => toggle(r.id),
                  onTap: busy
                      ? null
                      : () =>
                            selected.isEmpty ? widget.onOpen(r) : toggle(r.id),
                ),
                Divider(height: 1),
              ],
            ),
          ),
        ],
      );
    },
  );
}
