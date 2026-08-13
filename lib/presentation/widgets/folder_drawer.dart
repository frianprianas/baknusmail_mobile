import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mail_provider.dart';
import 'user_avatar.dart';
import 'quota_progress_card.dart';

class FolderDrawer extends StatelessWidget {
  const FolderDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final mail = context.watch<MailProvider>();
    final user = auth.currentUser;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // School Header & User Profile
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              MailcowConfig.appName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              MailcowConfig.schoolName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // User Info
                  if (user != null) ...[
                    Row(
                      children: [
                        UserAvatar(
                          email: user.email,
                          name: user.displayName,
                          radius: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Quota Widget
            if (user != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: QuotaProgressCard(user: user),
              ),

            const Divider(height: 1),

            // Folder List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: mail.folders.length,
                itemBuilder: (context, index) {
                  final folder = mail.folders[index];
                  final isSelected = mail.currentFolder.path == folder.path;

                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: isDark
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(
                      folder.icon,
                      color: isSelected
                          ? AppColors.primaryLight
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                      size: 22,
                    ),
                    title: Text(
                      folder.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? AppColors.primaryLight
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                      ),
                    ),
                    trailing: folder.unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${folder.unreadCount}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      mail.selectFolder(folder);
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Bottom Actions: Portal, Server Status, Settings, Logout
            ListTile(
              dense: true,
              leading: const Icon(Icons.hub_rounded, color: AppColors.primary),
              title: const Text(
                'Portal Layanan BaknusID',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Presensi, Drive, Taklim & SSO',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/portal');
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.dns_outlined, color: AppColors.accent),
              title: const Text('Status Server'),
              subtitle: const Text(
                'mail.smk.baktinusantara666.sch.id',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/server_status');
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(
                Icons.settings_outlined,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              title: const Text('Pengaturan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}
