import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'ai.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('让指引更贴近你', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: aiSettings,
          builder: (context, _) => Card.filled(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('AI 接入'),
              subtitle: Text(
                aiSettings.ready
                    ? '${aiSettings.provider.label} · ${aiSettings.modelFor(aiSettings.provider)}'
                    : '连接 DeepSeek 官方或 OpenCode Go',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('外观与内容', style: Theme.of(context).textTheme.titleMedium),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.dark_mode_outlined),
          title: Text('深色外观'),
          subtitle: Text('翡翠绿 · 玫瑰金'),
          trailing: Icon(Icons.check),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.style_outlined),
          title: Text('完整塔罗牌库'),
          subtitle: Text('22 张大阿卡纳 · 56 张小阿卡纳'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('私人日记'),
          subtitle: Text('保存在当前设备。长按记录可选择删除。'),
        ),
        const Divider(),
        const SizedBox(height: 16),
        const Text('卡牌提供思考的视角，选择始终由你自己做出。'),
      ],
    ),
  );
}

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});
  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late AiProvider provider;
  late String model;
  final keyInput = TextEditingController();
  bool obscure = true, busy = false;
  String? status;
  AiService? service;
  @override
  void initState() {
    super.initState();
    provider = aiSettings.provider;
    model = aiSettings.modelFor(provider);
    keyInput.text = aiSettings.keyFor(provider);
  }

  @override
  void dispose() {
    service?.close();
    keyInput.dispose();
    super.dispose();
  }

  Future<void> save({bool test = false, bool clear = false}) async {
    final key = clear ? '' : keyInput.text.trim();
    if (key.isEmpty && !clear) {
      setState(() => status = '请填写该服务的 API Key。');
      return;
    }
    setState(() {
      busy = true;
      status = null;
    });
    try {
      if (test) {
        service = AiService();
        await service!.complete(
          provider: provider,
          key: key,
          model: model,
          session: 'connection-test',
          prompt: 'Reply with OK.',
          test: true,
        );
      }
      await aiSettings.save(provider, key, model);
      if (!mounted) return;
      if (clear) keyInput.clear();
      setState(
        () => status = clear
            ? '已移除当前服务的密钥。'
            : test
            ? '连接成功，配置已保存。'
            : '配置已保存。',
      );
    } catch (e) {
      if (mounted) {
        setState(() => status = e is AiException ? e.message : '保存失败，请重试。');
      }
    } finally {
      service?.close();
      service = null;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 接入')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('选择解读服务', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('保存配置后，在牌阵解读中点击「AI 深入解读」。'),
        const SizedBox(height: 24),
        SegmentedButton<AiProvider>(
          segments: const [
            ButtonSegment(value: AiProvider.deepseek, label: Text('DeepSeek')),
            ButtonSegment(
              value: AiProvider.opencode,
              label: Text('OpenCode Go'),
            ),
          ],
          selected: {provider},
          onSelectionChanged: busy
              ? null
              : (value) => setState(() {
                  provider = value.first;
                  model = aiSettings.modelFor(provider);
                  keyInput.text = aiSettings.keyFor(provider);
                  status = null;
                }),
        ),
        const SizedBox(height: 24),
        DropdownMenu<String>(
          key: ValueKey(provider),
          expandedInsets: EdgeInsets.zero,
          initialSelection: model,
          label: const Text('模型'),
          enabled: !busy,
          dropdownMenuEntries: provider.models
              .map((m) => DropdownMenuEntry(value: m, label: m))
              .toList(),
          onSelected: (m) {
            if (m != null) setState(() => model = m);
          },
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('api-key'),
          controller: keyInput,
          enabled: !busy,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: '输入 ${provider.label} 的密钥',
            suffixIcon: IconButton(
              tooltip: obscure ? '显示密钥' : '隐藏密钥',
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          kIsWeb ? 'Web 预览的密钥仅保留到页面刷新。手机端使用系统安全存储。' : '密钥保存在系统安全存储中，各服务独立保存。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  provider.endpoint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (provider == AiProvider.opencode) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'OpenCode Go 主要面向编程代理请求。塔罗用途是否允许及可用，需以服务方规则和账户权限为准。',
                  ),
                ],
                const SizedBox(height: 12),
                const Text('AI 解读仅发送当前问题、牌阵和牌面。日记感受不会发送。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('save-ai'),
          onPressed: busy ? null : () => save(),
          icon: const Icon(Icons.check),
          label: const Text('保存配置'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('test-ai'),
          onPressed: busy ? null : () => save(test: true),
          icon: const Icon(Icons.wifi_tethering),
          label: const Text('测试连接并保存'),
        ),
        const SizedBox(height: 8),
        const Text('测试会向所选服务发送一条简短请求。'),
        if (busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (status != null) ...[
          const SizedBox(height: 16),
          Semantics(liveRegion: true, child: Text(status!)),
        ],
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: busy ? null : () => save(clear: true),
          icon: const Icon(Icons.key_off_outlined),
          label: const Text('移除当前服务的密钥'),
        ),
      ],
    ),
  );
}
