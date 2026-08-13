import 'package:flutter/material.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';

class UserAvatar extends StatelessWidget {
  final String email;
  final String name;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    required this.email,
    required this.name,
    this.radius = 22,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = backgroundColor ?? AppColors.getAvatarColor(name);
    final cleanEmail = email.trim();
    final initials = FormatHelper.getInitials(name);

    if (cleanEmail.isEmpty) {
      return _buildInitialsAvatar(avatarColor, initials);
    }

    final avatarUrl = MailcowConfig.getAvatarUrl(cleanEmail);

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If image fails or 404, fallback to styled initials avatar
          return _buildInitialsAvatar(avatarColor, initials);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildInitialsAvatar(avatarColor, initials);
        },
      ),
    );
  }

  Widget _buildInitialsAvatar(Color color, String initials) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}
