import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/config/mailcow_config.dart';
import 'core/theme/app_theme.dart';
import 'data/services/fcm_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/mailcow_api_service.dart';
import 'data/services/imap_service.dart';
import 'data/services/smtp_service.dart';
import 'data/services/baknus_api_service.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/mailcow_provider.dart';
import 'providers/mail_provider.dart';
import 'providers/baknus_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/baknus_portal_screen.dart';
import 'presentation/screens/baknus_attend_screen.dart';
import 'presentation/screens/baknus_drive_screen.dart';
import 'presentation/screens/baknus_talim_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/email_detail_screen.dart';
import 'presentation/screens/compose_screen.dart';
import 'presentation/screens/server_status_screen.dart';
import 'presentation/screens/settings_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM Service
  final fcmService = FCMService();
  await fcmService.init();

  // Initialize storage
  final storageService = await StorageService.init();
  final apiService = MailcowApiService();
  final imapService = ImapService();
  final smtpService = SmtpService();

  final baknusApiService = BaknusApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<MailcowApiService>.value(value: apiService),
        Provider<BaknusApiService>.value(value: baknusApiService),
        Provider<ImapService>.value(value: imapService),
        Provider<SmtpService>.value(value: smtpService),
        Provider<FCMService>.value(value: fcmService),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(storageService, imapService, apiService, fcmService),
        ),
        ChangeNotifierProvider(
          create: (_) => BaknusProvider(baknusApiService),
        ),
        ChangeNotifierProvider(
          create: (_) => MailcowProvider(apiService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MailProvider>(
          create: (ctx) => MailProvider(
            storageService,
            imapService,
            smtpService,
            ctx.read<AuthProvider>(),
          ),
          update: (ctx, auth, previous) {
            if (previous != null) {
              if (!auth.isAuthenticated) {
                previous.clearMailbox();
              }
              return previous;
            }
            return MailProvider(storageService, imapService, smtpService, auth);
          },
        ),
      ],
      child: const BaknusMailApp(),
    ),
  );
}

class BaknusMailApp extends StatelessWidget {
  const BaknusMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: MailcowConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/portal': (context) => const BaknusPortalScreen(),
        '/home': (context) => const HomeScreen(),
        '/attend': (context) => const BaknusAttendScreen(),
        '/drive': (context) => const BaknusDriveScreen(),
        '/talim': (context) => const BaknusTalimScreen(),
        '/email_detail': (context) => const EmailDetailScreen(),
        '/compose': (context) => const ComposeScreen(),
        '/server_status': (context) => const ServerStatusScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
