import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/mailcow_provider.dart';
import '../../data/services/storage_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/avatar_picker_dialog.dart';
import '../widgets/role_selection_dialog.dart';

import '../widgets/app_background.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _signatureController = TextEditingController();
  final _aliasPrefixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final storage = context.read<StorageService>();
    final userEmail = auth.currentUser?.email ?? '';
    _signatureController.text = storage.getSignature(userEmail);

    if (userEmail.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MailcowProvider>().fetchUserAliases(userEmail);
        }
      });
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _aliasPrefixController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAlias(String userEmail) async {
    final rawPrefix = _aliasPrefixController.text.trim().toLowerCase();
    if (rawPrefix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama alias (contoh: humas.siswa)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cleanPrefix = rawPrefix.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    if (cleanPrefix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama alias hanya boleh mengandung huruf, angka, titik, dan strip'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final fullAddress = cleanPrefix.contains('@')
        ? cleanPrefix
        : '$cleanPrefix@${MailcowConfig.domain}';

    final mailcow = context.read<MailcowProvider>();
    final res = await mailcow.createAlias(
      aliasAddress: fullAddress,
      userEmail: userEmail,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Alias dibuat'),
          backgroundColor: res['success'] == true ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (res['success'] == true) {
        _aliasPrefixController.clear();
      }
    }
  }

  Future<void> _handleDeleteAlias(String aliasId, String address, String userEmail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Alias Email?'),
        content: Text(
          'Email yang dikirim ke "$address" tidak akan masuk lagi ke kotak masuk Anda ($userEmail).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final mailcow = context.read<MailcowProvider>();
      final res = await mailcow.deleteUserAlias(
        aliasId: aliasId,
        userEmail: userEmail,
        address: address,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Alias dihapus'),
            backgroundColor: res['success'] == true ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
    final mailcow = context.watch<MailcowProvider>();
    final user = auth.currentUser;
    final userEmail = user?.email ?? '';

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => AvatarPickerDialog.show(context),
                        child: Stack(
                          children: [
                            UserAvatar(
                              email: user.email,
                              name: user.displayName,
                              radius: 28,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => AvatarPickerDialog.show(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ganti Foto Profil (Verifikasi AI)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Peran Akses Application Role
          _buildSectionHeader('Peran Akses Aplikasi', isDark),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (auth.isParentMode ? const Color(0xFF059669) : const Color(0xFF2563EB)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    auth.isParentMode ? Icons.family_restroom_rounded : Icons.school_rounded,
                    color: auth.isParentMode ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.isParentMode ? 'Mode Orang Tua / Wali' : 'Mode Siswa / Guru / TU',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.isParentMode
                            ? 'Akses pemantauan (BaknusChat dinonaktifkan)'
                            : 'Akses penuh ke semua fitur aplikasi',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final isParent = await RoleSelectionDialog.show(context);
                    if (isParent != null && context.mounted) {
                      await auth.setParentMode(isParent);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isParent
                                  ? 'Mode beralih ke Orang Tua / Wali.'
                                  : 'Mode beralih ke Siswa.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Ganti'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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

          // Email Alias (Max 1)
          if (userEmail.isNotEmpty) ...[
            _buildAliasSection(
              isDark: isDark,
              userEmail: userEmail,
              mailcow: mailcow,
            ),
            const SizedBox(height: 20),
          ],


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

  Widget _buildAliasSection({
    required bool isDark,
    required String userEmail,
    required MailcowProvider mailcow,
  }) {
    final aliases = mailcow.userAliases;
    final hasAlias = aliases.isNotEmpty;
    final isLoading = mailcow.isLoadingAliases;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Alias Email (Maksimal 1)', isDark),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasAlias
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasAlias ? '1 / 1 Alias Digunakan' : '0 / 1 Alias Digunakan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: hasAlias ? AppColors.warning : AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
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
              Text(
                'Alias memungkinkan Anda memiliki alamat email tambahan yang pesan fisiknya otomatis masuk ke kotak masuk utama ($userEmail).',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (hasAlias) ...[
                ...aliases.map((alias) {
                  final address = (alias['address'] ?? '').toString();
                  final aliasId = (alias['id'] ?? '').toString();
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.alternate_email_rounded,
                            color: AppColors.primaryLight,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Diteruskan ke $userEmail',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          tooltip: 'Hapus Alias',
                          onPressed: () => _handleDeleteAlias(aliasId, address, userEmail),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aliasPrefixController,
                        decoration: InputDecoration(
                          hintText: 'nama.alias',
                          suffixText: '@${MailcowConfig.domain}',
                          suffixStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCreateAlias(userEmail),
                    icon: const Icon(Icons.add_link_rounded, size: 18),
                    label: const Text('Buat Alias Baru'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

