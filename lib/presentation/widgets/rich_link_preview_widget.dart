import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class RichLinkPreviewWidget extends StatelessWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final String url;
  final bool isMe;
  final bool isDark;

  const RichLinkPreviewWidget({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.url,
    required this.isMe,
    required this.isDark,
  });

  Future<void> _launchUrl() async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domain = Uri.tryParse(url)?.host ?? url;

    return GestureDetector(
      onTap: _launchUrl,
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.black.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe
                ? Colors.white30
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: isMe ? Colors.white70 : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          domain,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white70 : AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isMe
                          ? Colors.white
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white70
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
