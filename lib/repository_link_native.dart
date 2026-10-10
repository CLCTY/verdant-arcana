import 'package:url_launcher/url_launcher.dart';

Future<bool> openRepository(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
