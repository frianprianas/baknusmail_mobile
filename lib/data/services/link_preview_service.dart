import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LinkPreviewData {
  final String url;
  final String title;
  final String description;
  final String? imageUrl;

  LinkPreviewData({
    required this.url,
    required this.title,
    required this.description,
    this.imageUrl,
  });
}

class LinkPreviewService {
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s/$.?#].[^\s]*',
    caseSensitive: false,
  );

  /// Extract the first valid URL from a message text
  static String? extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  /// Fetch Rich Link Preview metadata for a URL
  static Future<LinkPreviewData?> fetchMetadata(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;

    try {
      // 1. YouTube & oEmbed Provider (Via noembed.com API)
      final noembedUri = Uri.parse('https://noembed.com/embed?url=${Uri.encodeComponent(cleanUrl)}');
      final res = await http.get(noembedUri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
        final title = json['title']?.toString();
        if (title != null && title.isNotEmpty) {
          final author = json['author_name']?.toString() ?? json['provider_name']?.toString() ?? '';
          final thumb = json['thumbnail_url']?.toString();
          return LinkPreviewData(
            url: cleanUrl,
            title: title,
            description: author.isNotEmpty ? 'Oleh: $author' : cleanUrl,
            imageUrl: thumb,
          );
        }
      }

      // 2. OpenGraph Meta Tags Parser for HTML pages
      final pageRes = await http.get(Uri.parse(cleanUrl)).timeout(const Duration(seconds: 4));
      if (pageRes.statusCode == 200) {
        final html = pageRes.body;
        
        String title = _extractMetaContent(html, 'og:title') ??
            _extractMetaContent(html, 'title') ??
            _extractTagContent(html, 'title') ??
            cleanUrl;

        String description = _extractMetaContent(html, 'og:description') ??
            _extractMetaContent(html, 'description') ??
            '';

        String? imageUrl = _extractMetaContent(html, 'og:image');

        if (title.isNotEmpty) {
          return LinkPreviewData(
            url: cleanUrl,
            title: title,
            description: description,
            imageUrl: imageUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching link preview for $cleanUrl: $e');
    }

    return null;
  }

  static String? _extractMetaContent(String html, String property) {
    final regExp = RegExp(
      '<meta[^>]*?(?:property|name)=["\']${RegExp.escape(property)}["\'][^>]*?content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(html);
    if (match != null && match.groupCount >= 1) {
      return _decodeHtmlEntities(match.group(1)!);
    }
    return null;
  }

  static String? _extractTagContent(String html, String tag) {
    final regExp = RegExp('<$tag[^>]*?>([^<]+)</$tag>', caseSensitive: false);
    final match = regExp.firstMatch(html);
    if (match != null && match.groupCount >= 1) {
      return _decodeHtmlEntities(match.group(1)!.trim());
    }
    return null;
  }

  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
