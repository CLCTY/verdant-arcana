import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:emerald_tarot/ai.dart';

void main() {
  test(
    'loopback preview uses advertised same-origin relay without retrying a rejected request',
    () async {
      var posts = 0;
      final service = AiService(
        webOrigin: Uri.parse('http://127.0.0.1:4180/'),
        client: MockClient((request) async {
          if (request.method == 'GET') {
            expect(request.url.path, '/api/ai/status');
            expect(request.headers.containsKey('authorization'), false);
            return http.Response(
              jsonEncode({'relay': 'verdant-local-v1'}),
              200,
            );
          }
          posts++;
          expect(
            request.url.toString(),
            'http://127.0.0.1:4180/api/ai/opencode',
          );
          expect(request.headers['authorization'], 'Bearer test-only');
          expect(request.headers['x-opencode-session'], 'emerald-tarot-test');
          return http.Response('private upstream body', 401);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.complete(
          provider: AiProvider.opencode,
          key: 'test-only',
          model: 'deepseek-v4.1-flash',
          session: 'test',
          prompt: 'test',
        ),
        throwsA(isA<AiException>()),
      );
      expect(posts, 1);
    },
  );

  test(
    'hosted builds never send keys to a relay and static loopback builds stay direct',
    () async {
      for (final origin in ['https://example.com/', 'http://localhost:9000/']) {
        final service = AiService(
          webOrigin: Uri.parse(origin),
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response('static server', 404);
            }
            expect(request.url.toString(), AiProvider.deepseek.endpoint);
            return http.Response(
              '{"choices":[{"message":{"content":"OK"}}]}',
              200,
            );
          }),
        );
        expect(
          await service.complete(
            provider: AiProvider.deepseek,
            key: 'test-only',
            model: 'deepseek-flash',
            session: 'test',
            prompt: 'test',
          ),
          'OK',
        );
        service.close();
      }
    },
  );
}
