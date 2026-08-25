import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/utils/url_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/baknus_service_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baknus_provider.dart';

import '../widgets/app_background.dart';
import '../../data/services/chat_backup_service.dart';

class BaknusDriveScreen extends StatelessWidget {
  const BaknusDriveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final baknus = context.watch<BaknusProvider>();
    final user = auth.currentUser;
    final drive = baknus.driveData;

    final name = drive?.name.isNotEmpty == true
        ? drive!.name
        : (user?.displayName ?? 'Pengguna');
    final email = drive?.email.isNotEmpty == true
        ? drive!.email
        : (user?.email ?? '');
    final role = drive?.role.isNotEmpty == true ? drive!.role : 'Siswa';

    if (email.isNotEmpty) {
      ChatBackupService().checkAndRunAutoBackup(email);
    }

    final storage = drive?.storage ??
        StorageInfo(
          quotaBytes: 10737418240,
          usedBytes: 1048576,
          availableBytes: 10736369664,
          percentageUsed: 0.0097,
        );

    final usedStr = StorageInfo.formatBytes(storage.usedBytes);
    final quotaStr = StorageInfo.formatBytes(storage.quotaBytes);
    final availableStr = StorageInfo.formatBytes(storage.availableBytes);
    final percentageFormatted = storage.percentString;
    final lastAccessed = drive?.lastAccessed ?? '-';

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('BaknusDrive'),
          actions: [
            IconButton(
              icon: const Icon(Icons.language_rounded),
              tooltip: 'Buka Web BaknusDrive',
              onPressed: () => UrlHelper.openServiceWebUrl(
                MailcowConfig.driveWebUrl,
                userEmail: email,
                context: context,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan',
              onPressed: () {
                if (email.isNotEmpty) {
                  baknus.loadAllStats(email);
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            if (email.isNotEmpty) {
              await baknus.loadAllStats(email);
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Tombol Buka Aplikasi Web dengan Auto-Fill Email
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 22),
                label: const Text(
                  'Buka Web BaknusDrive (Auto-Fill Login)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: () => UrlHelper.openServiceWebUrl(
                  MailcowConfig.driveWebUrl,
                  userEmail: email,
                  context: context,
                ),
              ),
              const SizedBox(height: 14),
              // Header Profil (Nama, Email, Role)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Penyimpanan Berkas • $role',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.cloud_sync_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Indikator Grafis Kapasitas Penyimpanan (Kuota Terpakai vs Sisa Kuota)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kapasitas Penyimpanan Cloud',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Terpakai: $usedStr',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      Text(
                        'Total: $quotaStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar Kapasitas
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: storage.percentageUsed.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Rincian Detail Kuota
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildStorageRow(
                            'Kuota Terpakai (used_bytes)', usedStr, isDark),
                        const Divider(height: 14),
                        _buildStorageRow(
                            'Sisa Kuota (available_bytes)', availableStr, isDark),
                        const Divider(height: 14),
                        _buildStorageRow(
                            'Persentase Terpakai', percentageFormatted, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Waktu Terakhir Akses Drive
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Waktu Terakhir Akses Drive',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lastAccessed,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStorageRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
