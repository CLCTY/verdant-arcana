import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'localization.dart';

enum AiProvider { deepseek, opencode }

extension AiProviderInfo on AiProvider {
  String get label =>
      tr(this == AiProvider.deepseek ? 'DeepSeek 官方' : 'OpenCode Go');
  String get endpoint => this == AiProvider.deepseek
      ? 'https://api.deepseek.com/chat/completions'
      : 'https://opencode.ai/zen/go/v1/chat/completions';
  String get defaultModel =>
      this == AiProvider.deepseek ? 'deepseek-flash' : 'deepseek-v4.1-flash';
  List<String> get models => this == AiProvider.deepseek
      ? ['deepseek-flash', 'deepseek-v4-pro']
      : ['deepseek-v4.1-flash'];
}

class AiSettings extends ChangeNotifier {
  AiSettings({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  final FlutterSecureStorage _storage;
  final Map<AiProvider, String> _keys = {};
  final Map<AiProvider, String> _models = {};
  AiProvider provider = AiProvider.deepseek;
  String? error;
  String keyFor(AiProvider p) => _keys[p] ?? '';
  String modelFor(AiProvider p) => _models[p] ?? p.defaultModel;
  bool get ready => keyFor(provider).isNotEmpty;
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      provider = prefs.getString('ai_provider') == 'opencode'
          ? AiProvider.opencode
          : AiProvider.deepseek;
      for (final p in AiProvider.values) {
        final model = prefs.getString('ai_model_${p.name}');
        if (model != null && p.models.contains(model)) _models[p] = model;
        if (!kIsWeb) {
          _keys[p] = await _storage.read(key: 'tarot_key_${p.name}') ?? '';
        }
      }
    } catch (_) {
      error = '无法读取 AI 配置，可以重新输入密钥。';
    }
    notifyListeners();
  }

  Future<void> save(AiProvider p, String key, String model) async {
    if (!p.models.contains(model)) throw ArgumentError('Unsupported model');
    if (!kIsWeb) {
      if (key.trim().isEmpty) {
        await _storage.delete(key: 'tarot_key_${p.name}');
      } else {
        await _storage.write(key: 'tarot_key_${p.name}', value: key.trim());
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('ai_provider', p.name) ||
        !await prefs.setString('ai_model_${p.name}', model)) {
      throw StateError('Could not save settings');
    }
    _keys[p] = key.trim();
    _models[p] = model;
    provider = p;
    error = null;
    notifyListeners();
  }
}

final aiSettings = AiSettings();

class AiException implements Exception {
  const AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiService {
  AiService({http.Client? client, Uri? webOrigin})
    : client = client ?? http.Client(),
      webOrigin = webOrigin ?? (kIsWeb ? Uri.base : null);
  final http.Client client;
  final Uri? webOrigin;
  Future<Uri> requestEndpoint(AiProvider provider) async {
    final origin = webOrigin;
    // Only our loopback preview advertises a relay. Hosted builds stay direct.
    if (origin != null &&
        origin.scheme == 'http' &&
        (origin.host == '127.0.0.1' || origin.host == 'localhost')) {
      try {
        final response = await client
            .get(origin.resolve('/api/ai/status'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 &&
            jsonDecode(response.body)['relay'] == 'verdant-local-v1') {
          return origin.resolve('/api/ai/${provider.name}');
        }
      } catch (_) {
        // A static Flutter server does not have our relay.
      }
    }
    return Uri.parse(provider.endpoint);
  }

  void close() => client.close();
  Future<String> complete({
    required AiProvider provider,
    required String key,
    required String model,
    required String session,
    required String prompt,
    bool test = false,
  }) async {
    if (key.trim().isEmpty) throw const AiException('请先在设置中填写 API Key。');
    try {
      final endpoint = await requestEndpoint(provider);
      final response = await client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${key.trim()}',
              if (provider == AiProvider.opencode)
                'x-opencode-session': 'emerald-tarot-$session',
              // Browser user agents are browser-controlled; never impersonate a coding agent.
              if (!kIsWeb) 'User-Agent': 'VerdantArcana/0.3',
            },
            body: jsonEncode({
              'model': model,
              'stream': false,
              'max_tokens': test ? 32 : 2400,
              'thinking': {'type': 'disabled'},
              'messages': [
                {
                  'role': 'system',
                  'content': test
                      ? 'Reply with OK.'
                      : 'You are a compassionate, grounded tarot reflection assistant. Treat symbols as prompts for reflection, never certain predictions. Connect the question, spread positions, card orientations and relationships between cards. Suggest one to three practical small actions. Do not claim to know another person\'s inner thoughts. Do not output internal reasoning. Use short clear paragraphs. Respond exclusively in ${switch (appPreferences.language) {
                          'ja' => 'Japanese',
                          'en' => 'English',
                          _ => 'Simplified Chinese',
                        }}.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiException(switch (response.statusCode) {
          401 || 403 => '密钥无效或没有访问权限，请检查该服务的 API Key。',
          402 => '账户余额或额度不足，请检查服务账户。',
          404 => '当前模型或接口不可用，请检查服务的模型权限。',
          429 => '请求过于频繁或额度已用完，请稍后重试。',
          >= 500 => '服务暂时不可用，请稍后重试。',
          _ => '请求失败（${response.statusCode}），请检查模型配置。',
        });
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      final message = choices?.firstOrNull?['message'] as Map?;
      final content = message?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const AiException('服务没有返回解读正文，请重试。');
      }
      return content.trim();
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException('请求超时，请检查网络后重试。');
    } on http.ClientException {
      throw const AiException(
        kIsWeb ? '连接失败。浏览器可能受到跨域限制；可在 Android 应用中尝试。' : '无法连接服务，请检查网络。',
      );
    } on FormatException {
      throw const AiException('服务响应格式不正确，请稍后重试。');
    } catch (_) {
      throw const AiException('服务响应无法读取，请稍后重试。');
    }
  }

  Future<String> interpret(Reading reading, AiSettings settings) => complete(
    provider: settings.provider,
    key: settings.keyFor(settings.provider),
    model: settings.modelFor(settings.provider),
    session: reading.id,
    prompt:
        '问题：${reading.question}\n牌阵：${reading.spread}\n${List.generate(reading.cards.length, (i) => '${i + 1}. ${reading.positions[i]}：${reading.cards[i].card.name}（${reading.cards[i].orientation}），参考含义：${reading.cards[i].meaning}').join('\n')}\n请给出整体主题、各位置含义、牌与牌的关系，以及一至三个具体行动建议。',
  );
}
