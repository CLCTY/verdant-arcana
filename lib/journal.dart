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
          content: Text('已删除 ${removed.length} 条记录'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              try {
                await widget.journal.restore(removed);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('恢复失败，请重试。')));
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请重试。')));
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_stories_outlined, color: rose, size: 48),
                const SizedBox(height: 24),
                Text(
                  '把此刻，留给未来的自己',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  '完成一次抽牌后，保存解读和感受。\n你的记录会在这里慢慢积累。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.8),
                ),
              ],
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (selected.isEmpty) ...[
            Text('留住每一次看见', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${records.length} 次记录 · 长按可选择删除',
              style: const TextStyle(color: muted),
            ),
          ] else
            Card.filled(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Expanded(child: Text('已选 ${selected.length} 条')),
                    IconButton(
                      tooltip: '全选',
                      onPressed: busy
                          ? null
                          : () => setState(
                              () => selected.addAll(records.map((r) => r.id)),
                            ),
                      icon: const Icon(Icons.done_all),
                    ),
                    IconButton(
                      key: const ValueKey('delete-selected'),
                      tooltip: '删除所选记录',
                      onPressed: busy ? null : remove,
                      icon: const Icon(Icons.delete_outline),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => selected.clear()),
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ),
            ),
          if (busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 24),
          ...records.map(
            (r) => Column(
              children: [
                ListTile(
                  key: ValueKey('journal-${r.id}'),
                  selected: selected.contains(r.id),
                  contentPadding: const EdgeInsets.symmetric(
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
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${shortDate(r.created)} · ${r.spread}'),
                  ),
                  trailing: selected.isNotEmpty
                      ? Checkbox(
                          value: selected.contains(r.id),
                          onChanged: busy ? null : (_) => toggle(r.id),
                        )
                      : const Icon(Icons.chevron_right),
                  onLongPress: busy ? null : () => toggle(r.id),
                  onTap: busy
                      ? null
                      : () =>
                            selected.isEmpty ? widget.onOpen(r) : toggle(r.id),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
        ],
      );
    },
  );
}
