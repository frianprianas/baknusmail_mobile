import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mail_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/role_selection_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final mail = context.read<MailProvider>();

    String username = _usernameController.text.trim();
    if (!username.contains('@')) {
      username = '$username@${MailcowConfig.domain}';
    }

    final success = await auth.login(
      email: username,
      password: _passwordController.text,
    );

    if (success && mounted) {
      final isParent = await RoleSelectionDialog.show(context);
      if (mounted) {
        await auth.setParentMode(isParent ?? false);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/portal');
          mail.loadFoldersAndEmails();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              // Tombol Toggle Tema Terang / Gelap di sudut kanan atas
              Positioned(
                top: 10,
                right: 14,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      themeProvider.isDarkMode
                          ? Icons.wb_sunny_rounded
                          : Icons.nightlight_round,
                      color: themeProvider.isDarkMode
                          ? Colors.amber
                          : const Color(0xFF1E3A8A),
                      size: 22,
                    ),
                    tooltip: themeProvider.isDarkMode
                        ? 'Ganti ke Mode Terang'
                        : 'Ganti ke Mode Gelap',
                    onPressed: () {
                      themeProvider.setThemeMode(
                        themeProvider.isDarkMode
                            ? ThemeMode.light
                            : ThemeMode.dark,
                      );
                    },
                  ),
                ),
              ),

              // Form Login Utama
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo Header
                          Center(
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // App Title
                          Center(
                            child: Text(
                              MailcowConfig.appName,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // School Subtitle
                          Center(
                            child: Text(
                              MailcowConfig.schoolName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Kartu Form Login
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface.withValues(alpha: 0.90)
                                  : Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Masuk Akun BaknusID',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Gunakan email SMK Bakti Nusantara 666',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),

                                 // Username Input
                                TextFormField(
                                  controller: _usernameController,
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (_) => setState(() {}),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Nama Pengguna / ID Email',
                                    labelStyle: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    hintText: 'Ketik username akun (contoh: budi)',
                                    hintStyle: TextStyle(
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email / ID pengguna tidak boleh kosong';
                                    }
                                    return null;
                                  },
                                ),
                                if (!_usernameController.text.contains('@'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, left: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Domain Otomatis: @${MailcowConfig.domain}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                // Password Input
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Kata Sandi',
                                    labelStyle: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Kata sandi tidak boleh kosong';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _handleLogin(),
                                ),
                                const SizedBox(height: 24),

                                // Error Message Display
                                if (auth.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.error.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            auth.errorMessage!,
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Login Button
                                ElevatedButton(
                                  onPressed: auth.status == AuthStatus.authenticating ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: auth.status == AuthStatus.authenticating
                                      ? const SpinKitThreeBounce(
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Masuk ke Akun Email',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 18),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
