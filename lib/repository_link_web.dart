import 'package:web/web.dart' as web;

Future<bool> openRepository(String url) async {
  web.window.location.href = url;
  return true;
}
