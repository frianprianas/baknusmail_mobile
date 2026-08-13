import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';
import '../../data/models/email_message.dart';
import 'user_avatar.dart';

class EmailTile extends StatelessWidget {
  final EmailMessage email;
  final VoidCallback onTap;
  final VoidCallback onToggleStar;
  final VoidCallback onDelete;

  const EmailTile({
    super.key,
    required this.email,
    required this.onTap,
    required this.onToggleStar,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final senderName = email.from.name.isNotEmpty
        ? email.from.name
        : FormatHelper.extractNameFromEmail(email.from.email);

    return Dismissible(
      key: Key(email.messageId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: email.isRead
            ? Colors.transparent
            : (isDark
                ? AppColors.primaryDark.withValues(alpha: 0.15)
                : AppColors.primaryLight.withValues(alpha: 0.08)),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.6,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                UserAvatar(
                  email: email.from.email,
                  name: senderName,
                  radius: 22,
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender & Date
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              senderName,
                              style: TextStyle(
                                fontWeight: email.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                fontSize: 15,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            FormatHelper.formatEmailDate(email.dateTime),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: email.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: email.isRead
                                  ? (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted)
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Subject
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              email.subject,
                              style: TextStyle(
                                fontWeight: email.isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                fontSize: 13.5,
                                color: isDark
                                    ? (email.isRead
                                        ? AppColors.darkTextSecondary
                                        : AppColors.darkTextPrimary)
                                    : (email.isRead
                                        ? AppColors.lightTextSecondary
                                        : AppColors.lightTextPrimary),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (email.hasAttachments) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.attach_file_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Snippet
                      Text(
                        email.snippet,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Star Action Button
                IconButton(
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                  icon: Icon(
                    email.isStarred
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: email.isStarred
                        ? AppColors.gold
                        : (isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted),
                  ),
                  onPressed: onToggleStar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
