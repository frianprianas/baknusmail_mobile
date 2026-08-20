import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlHelper {
  /// Opens a web URL in an In-App Safari/Chrome View with pre-filled email query parameter
  static Future<bool> openServiceWebUrl(
    String baseUrl, {
    String? userEmail,
    BuildContext? context,
  }) async {
    try {
      String finalUrlStr = baseUrl;
      if (userEmail != null && userEmail.isNotEmpty) {
        final uri = Uri.parse(baseUrl);
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams['email'] = userEmail;
        queryParams['username'] = userEmail;
        queryParams['user'] = userEmail;

        finalUrlStr = uri.replace(queryParameters: queryParams).toString();
      }

      final url = Uri.parse(finalUrlStr);
      final launched = await launchUrl(
        url,
        mode: LaunchMode.inAppBrowserView, // Uses SFSafariViewController on iOS & Custom Tabs on Android
      );

      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka halaman: $baseUrl')),
        );
      }
      return launched;
    } catch (e) {
      debugPrint('Error launching URL $baseUrl: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka tautan web: $e')),
        );
      }
      return false;
    }
  }
}
