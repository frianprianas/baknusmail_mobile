import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';
import '../../data/models/user_account.dart';

class QuotaProgressCard extends StatelessWidget {
  final UserAccount user;

  const QuotaProgressCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percentage = user.quotaPercentage;
    final percentageInt = (percentage * 100).toInt();

    Color progressColor = AppColors.success;
    if (percentage > 0.85) {
      progressColor = AppColors.error;
    } else if (percentage > 0.70) {
      progressColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_queue_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Penyimpanan Mailbox',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$percentageInt%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${FormatHelper.formatFileSize(user.quotaUsed)} dari ${FormatHelper.formatFileSize(user.quotaTotal)} terpakai',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}
