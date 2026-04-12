import 'package:url_launcher/url_launcher.dart';

String? encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&');
}

Future<void> openWhatsApp(String phoneNumber, String message) async {
  final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) {
    throw 'Invalid phone number for WhatsApp.';
  }
  final url = 'https://wa.me/$digitsOnly?text=${Uri.encodeComponent(message)}';
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  throw 'Could not launch $url';
}

Future<void> sendEmail({
  required String to,
  required String subject,
  required String body,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: to,
    query: encodeQueryParameters(<String, String>{
      'subject': subject,
      'body': body,
    }),
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return;
  }
  throw 'Could not launch $uri';
}
