import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../data/services/storage_service.dart';
import '../widgets/user_avatar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _signatureController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final storage = context.read<StorageService>();
    _signatureController.text =
        storage.getSignature(auth.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    final storage = context.read<StorageService>();
    await storage.setSignature(_signatureController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanda tangan email tersimpan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Anda harus memasukkan kembali kata sandi untuk masuk ke email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = context.read<AuthProvider>();
      await auth.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // User Profile Card
          if (user != null) ...[
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
                  UserAvatar(
                    email: user.email,
                    name: user.displayName,
                    radius: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Akun Resmi SMK Bakti Nusantara 666',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Theme Settings
          _buildSectionHeader('Tampilan & Tema', isDark),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_auto_rounded),
                  title: const Text('Ikuti Pengaturan Sistem'),
                  trailing: themeProvider.themeMode == ThemeMode.system
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight)
                      : null,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.light_mode_rounded),
                  title: const Text('Mode Terang'),
                  trailing: themeProvider.themeMode == ThemeMode.light
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight)
                      : null,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Mode Gelap (OLED/Dark)'),
                  trailing: themeProvider.themeMode == ThemeMode.dark
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight)
                      : null,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Email Signature
          _buildSectionHeader('Tanda Tangan Email', isDark),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _signatureController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Tanda tangan pengirim email...',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _saveSignature,
                    child: const Text('Simpan Tanda Tangan'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Server Info Shortcut
          _buildSectionHeader('Koneksi & Jaringan Server', isDark),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_rounded, color: AppColors.accent),
                  title: const Text('Server Mailcow'),
                  subtitle: const Text(MailcowConfig.mailHost),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, '/server_status'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded,
                      color: AppColors.warning),
                  title: const Text('Bersihkan Cache Lokal'),
                  subtitle: const Text('Hapus cache pesan yang tersimpan di memori hp'),
                  onTap: () async {
                    final storage = context.read<StorageService>();
                    await storage.clearAllCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cache lokal berhasil dibersihkan'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: const Text(
                'Keluar dari Akun',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleLogout,
            ),
          ),
          const SizedBox(height: 24),

          // App Info
          Center(
            child: Text(
              '${MailcowConfig.appName} v1.0.0 • ${MailcowConfig.schoolName}',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
