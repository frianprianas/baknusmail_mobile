import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';
import '../../providers/auth_provider.dart';

class UserAvatar extends StatelessWidget {
  final String email;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final String? avatarBase64;

  const UserAvatar({
    super.key,
    required this.email,
    required this.name,
    this.radius = 22,
    this.backgroundColor,
    this.avatarBase64,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = backgroundColor ?? AppColors.getAvatarColor(name);
    final cleanEmail = email.trim();
    final initials = FormatHelper.getInitials(name);

    // 1. Cek avatarBase64 dari parameter atau AuthProvider
    String? currentBase64 = avatarBase64;
    if (currentBase64 == null || currentBase64.isEmpty) {
      try {
        final auth = context.watch<AuthProvider>();
        if (auth.currentUser?.email.toLowerCase() == cleanEmail.toLowerCase()) {
          currentBase64 = auth.currentUser?.avatarBase64;
        }
      } catch (_) {}
    }

    // Render Base64 Image jika ada
    if (currentBase64 != null && currentBase64.isNotEmpty) {
      try {
        String base64Data = currentBase64;
        if (base64Data.contains(',')) {
          base64Data = base64Data.split(',').last;
        }
        final bytes = base64Decode(base64Data);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialsAvatar(avatarColor, initials);
            },
          ),
        );
      } catch (_) {
        // Fallback jika decode gagal
      }
    }

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
          // Fallback ke avatar inisial nama jika gagal memuat network image
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
