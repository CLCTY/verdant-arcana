import 'localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai.dart';

const repositoryUrl = 'https://github.com/CLCTY/verdant-arcana';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(translateUi('设置', context))),
    body: ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text(
          translateUi('让指引更贴近你', context),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 24),
        ListenableBuilder(
          listenable: aiSettings,
          builder: (context, _) => Card.filled(
            child: ListTile(
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text(translateUi('AI 接入', context)),
              subtitle: Text(
                translateUi(
                  aiSettings.ready
                      ? '${aiSettings.provider.label} · ${aiSettings.modelFor(aiSettings.provider)}'
                      : '连接 DeepSeek 官方或 OpenCode Go',
                  context,
                ),
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
              ),
            ),
          ),
        ),
        SizedBox(height: 24),
        Text(
          translateUi('外观与内容', context),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 16),
        DropdownMenu<String>(
          key: ValueKey('language-${appPreferences.language}'),
          initialSelection: appPreferences.language,
          expandedInsets: EdgeInsets.zero,
          label: Text(translateUi('语言', context)),
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'zh', label: '简体中文'),
            DropdownMenuEntry(value: 'en', label: 'English'),
            DropdownMenuEntry(value: 'ja', label: '日本語'),
          ],
          onSelected: (value) async {
            if (value == null) return;
            try {
              await appPreferences.setLanguage(value);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('保存失败，请重试。', context))),
                );
              }
            }
          },
        ),
        SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.dark_mode_outlined),
          title: Text(translateUi('OLED 纯黑背景', context)),
          subtitle: Text(translateUi('跟随系统壁纸配色', context)),
          trailing: Icon(Icons.check),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.palette_outlined),
          title: Text(tr('动态取色', context)),
          subtitle: Text(tr('支持的设备跟随壁纸或系统强调色，不支持时使用默认翡翠配色。', context)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.style_outlined),
          title: Text(translateUi('完整塔罗牌库', context)),
          subtitle: Text(translateUi('22 张大阿卡纳 · 56 张小阿卡纳', context)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text(translateUi('私人日记', context)),
          subtitle: Text(translateUi('保存在当前设备。长按记录可选择删除。', context)),
        ),
        Divider(),
        ListTile(
          key: const ValueKey('github-repository'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.code),
          title: Text(translateUi('GitHub 仓库', context)),
          subtitle: const Text(repositoryUrl),
          trailing: const Icon(Icons.open_in_new),
          onTap: () async {
            try {
              if (await launchUrl(
                Uri.parse(repositoryUrl),
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: kIsWeb ? '_self' : null,
              )) {
                return;
              }
            } catch (_) {
              // Show a recoverable message if no browser can open the link.
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(translateUi('无法打开链接，请稍后重试。', context))),
              );
            }
          },
        ),
        SizedBox(height: 16),
        Text(translateUi('卡牌提供思考的视角，选择始终由你自己做出。', context)),
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
    appBar: AppBar(title: Text(translateUi('AI 接入', context))),
    body: ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text(
          translateUi('选择解读服务', context),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 12),
        Text(translateUi('保存配置后，在牌阵解读中点击「AI 深入解读」。', context)),
        SizedBox(height: 24),
        SegmentedButton<AiProvider>(
          segments: [
            ButtonSegment(
              value: AiProvider.deepseek,
              label: Text(translateUi('DeepSeek', context)),
            ),
            ButtonSegment(
              value: AiProvider.opencode,
              label: Text(translateUi('OpenCode Go', context)),
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
        SizedBox(height: 24),
        DropdownMenu<String>(
          key: ValueKey(provider),
          expandedInsets: EdgeInsets.zero,
          initialSelection: model,
          label: Text(translateUi('模型', context)),
          enabled: !busy,
          dropdownMenuEntries: provider.models
              .map((m) => DropdownMenuEntry(value: m, label: m))
              .toList(),
          onSelected: (m) {
            if (m != null) setState(() => model = m);
          },
        ),
        SizedBox(height: 20),
        TextField(
          key: ValueKey('api-key'),
          controller: keyInput,
          enabled: !busy,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: translateUi('API Key', context),
            hintText: translateUi('输入 ${provider.label} 的密钥', context),
            suffixIcon: IconButton(
              tooltip: translateUi(obscure ? '显示密钥' : '隐藏密钥', context),
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          translateUi(
            kIsWeb ? 'Web 预览的密钥仅保留到页面刷新。手机端使用系统安全存储。' : '密钥保存在系统安全存储中，各服务独立保存。',
            context,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(height: 20),
        Card.filled(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateUi(provider.label, context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                SelectableText(
                  translateUi(provider.endpoint, context),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (provider == AiProvider.opencode) ...[
                  SizedBox(height: 12),
                  Text(
                    translateUi(
                      'OpenCode Go 主要面向编程代理请求。塔罗用途是否允许及可用，需以服务方规则和账户权限为准。',
                      context,
                    ),
                  ),
                ],
                SizedBox(height: 12),
                Text(translateUi('AI 解读仅发送当前问题、牌阵和牌面。日记感受不会发送。', context)),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        FilledButton.icon(
          key: ValueKey('save-ai'),
          onPressed: busy ? null : () => save(),
          icon: Icon(Icons.check),
          label: Text(translateUi('保存配置', context)),
        ),
        SizedBox(height: 12),
        OutlinedButton.icon(
          key: ValueKey('test-ai'),
          onPressed: busy ? null : () => save(test: true),
          icon: Icon(Icons.wifi_tethering),
          label: Text(translateUi('测试连接并保存', context)),
        ),
        SizedBox(height: 8),
        Text(translateUi('测试会向所选服务发送一条简短请求。', context)),
        if (busy) ...[SizedBox(height: 16), LinearProgressIndicator()],
        if (status != null) ...[
          SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(translateUi(status!, context)),
          ),
        ],
        SizedBox(height: 20),
        TextButton.icon(
          onPressed: busy ? null : () => save(clear: true),
          icon: Icon(Icons.key_off_outlined),
          label: Text(translateUi('移除当前服务的密钥', context)),
        ),
      ],
    ),
  );
}
