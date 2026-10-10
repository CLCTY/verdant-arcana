import 'package:flutter/material.dart';
import 'ai.dart';
import 'models.dart';
import 'settings.dart';

class AiReadingPanel extends StatefulWidget {
  const AiReadingPanel({
    super.key,
    required this.reading,
    required this.onChanged,
  });
  final Reading reading;
  final VoidCallback onChanged;
  @override
  State<AiReadingPanel> createState() => _AiReadingPanelState();
}

class _AiReadingPanelState extends State<AiReadingPanel> {
  bool busy = false;
  String? error;
  AiService? service;
  @override
  void dispose() {
    service?.close();
    super.dispose();
  }

  Future<void> generate() async {
    if (!aiSettings.ready) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final attribution =
        '${aiSettings.provider.label} · ${aiSettings.modelFor(aiSettings.provider)}';
    service = AiService();
    try {
      final text = await service!.interpret(widget.reading, aiSettings);
      if (!mounted) return;
      widget.reading.aiText = text;
      widget.reading.aiProvider = attribution;
      widget.onChanged();
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => error = e is AiException ? e.message : '解读失败，请重试。');
      }
    } finally {
      service?.close();
      service = null;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: aiSettings,
    builder: (context, _) => Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI 深入解读',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              aiSettings.ready
                  ? '将当前问题、牌阵和牌面发送给 ${aiSettings.provider.label}。'
                  : '连接你的解读服务，获得结合问题与牌阵的解读。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (widget.reading.aiText.isNotEmpty) ...[
              Text(
                widget.reading.aiProvider,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                widget.reading.aiText,
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
              const SizedBox(height: 16),
            ],
            if (busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('正在整理牌面的故事…'),
              const SizedBox(height: 16),
            ],
            if (error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.tonalIcon(
              key: const ValueKey('ai-reading'),
              onPressed: busy ? null : generate,
              icon: Icon(
                aiSettings.ready ? Icons.auto_awesome : Icons.key_outlined,
              ),
              label: Text(
                !aiSettings.ready
                    ? '配置 AI 接入'
                    : widget.reading.aiText.isEmpty
                    ? '生成 AI 解读'
                    : '重新解读',
              ),
            ),
            if (aiSettings.ready)
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AiSettingsPage(),
                        ),
                      ),
                child: const Text('更换服务'),
              ),
          ],
        ),
      ),
    ),
  );
}
