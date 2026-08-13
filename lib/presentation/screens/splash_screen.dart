import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/portal');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              MailcowConfig.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),

            // School Subtitle
            Text(
              MailcowConfig.schoolName,
              style: TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 48),

            // Loading Spinner
            const SpinKitFadingCircle(
              color: AppColors.accent,
              size: 36,
            ),
          ],
        ),
      ),
    );
  }
}
