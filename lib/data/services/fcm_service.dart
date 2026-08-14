import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/mail_provider.dart';

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> init() async {
    // 1. Minta izin notifikasi
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // 2. Setup Local Notifications untuk menangani notifikasi saat aplikasi dibuka (foreground)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _navigateToInbox();
      },
    );

    // Buat Notification Channel khusus dengan suara custom di Android
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_attend_v3',
          'BaknusAttend Notifications',
          description: 'Notifikasi presensi dan kehadiran BaknusAttend',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_attend'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_drive_v3',
          'BaknusDrive Notifications',
          description: 'Notifikasi penyimpanan dan berkas BaknusDrive',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_drive'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_talim_v3',
          'BaknusTalim Notifications',
          description: 'Notifikasi kegiatan BaknusTalim',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_talim'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_email_umum_v3',
          'Email Notifications',
          description: 'Notifikasi email umum',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_umum'),
          playSound: true,
        ),
      );
    }

    // 3. Dengarkan notifikasi saat aplikasi dibuka (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      final mailProvider = navigatorKey.currentContext?.read<MailProvider>();
      if (mailProvider != null) {
        mailProvider.loadFoldersAndEmails().catchError((_) {});
      }

      _showLocalNotification(message);
    });

    // 4. Ketika notifikasi di-tap dari latar belakang (background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('Notification clicked from background: ${message.data}');
      _navigateToInbox();
    });

    // 5. Ketika aplikasi dibuka dari kondisi mati (terminated) karena notifikasi di-tap
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App launched from terminated notification: ${message.data}');
        Future.delayed(const Duration(milliseconds: 500), () async {
          _navigateToInbox();
        });
      }
    });
  }

  // Menampilkan notifikasi background
  Future<void> showBackgroundNotification(RemoteMessage message) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotificationsPlugin.initialize(settings: initializationSettings);

    // Buat ulang notification channels untuk memastikan suara custom tersedia
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_email_umum_v3',
          'Email Notifications',
          description: 'Notifikasi email umum',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_umum'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_attend_v3',
          'BaknusAttend Notifications',
          description: 'Notifikasi presensi dan kehadiran BaknusAttend',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_attend'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_drive_v3',
          'BaknusDrive Notifications',
          description: 'Notifikasi penyimpanan dan berkas BaknusDrive',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_drive'),
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'channel_baknus_talim_v3',
          'BaknusTalim Notifications',
          description: 'Notifikasi kegiatan BaknusTalim',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_baknus_talim'),
          playSound: true,
        ),
      );
    }

    await _showLocalNotification(message);
  }

  // Mendapatkan channel dan suara berdasarkan pengirim & subjek email
  Map<String, String> _getChannelAndSound(String sender, String subject) {
    final lowerSender = sender.toLowerCase();
    final lowerSubject = subject.toLowerCase();

    if (lowerSender.contains('attend') ||
        lowerSender.contains('presensi') ||
        lowerSubject.contains('baknusattend') ||
        lowerSubject.contains('attend') ||
        lowerSubject.contains('presensi') ||
        lowerSubject.contains('kehadiran')) {
      return {
        'id': 'channel_baknus_attend_v3',
        'name': 'BaknusAttend Notifications',
        'desc': 'Notifikasi presensi dan kehadiran BaknusAttend',
        'sound': 'sound_baknus_attend',
      };
    } else if (lowerSender.contains('drive') ||
        lowerSubject.contains('baknusdrive') ||
        lowerSubject.contains('drive') ||
        lowerSubject.contains('berkas') ||
        lowerSubject.contains('penyimpanan')) {
      return {
        'id': 'channel_baknus_drive_v3',
        'name': 'BaknusDrive Notifications',
        'desc': 'Notifikasi penyimpanan dan berkas BaknusDrive',
        'sound': 'sound_baknus_drive',
      };
    } else if (lowerSender.contains('talim') ||
        lowerSender.contains('ta\'lim') ||
        lowerSubject.contains('baknustalim') ||
        lowerSubject.contains('talim') ||
        lowerSubject.contains('ta\'lim') ||
        lowerSubject.contains('kajian')) {
      return {
        'id': 'channel_baknus_talim_v3',
        'name': 'BaknusTalim Notifications',
        'desc': 'Notifikasi kegiatan BaknusTalim',
        'sound': 'sound_baknus_talim',
      };
    } else {
      return {
        'id': 'channel_email_umum_v3',
        'name': 'Email Notifications',
        'desc': 'Notifikasi email umum',
        'sound': 'sound_umum',
      };
    }
  }

  // Menampilkan notifikasi manual saat aplikasi sedang di foreground/background
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const title = 'Email Baru';
    const body = 'Anda mendapatkan pesan baru';

    // Gunakan channel_id & sound_name dari data payload jika ada (dikirim oleh server)
    // Jika tidak ada, fallback ke _getChannelAndSound berdasarkan pengirim & subjek
    final String channelIdFromData = message.data['channel_id'] ?? '';
    final String soundNameFromData = message.data['sound_name'] ?? '';

    late Map<String, String> channelConfig;
    if (channelIdFromData.isNotEmpty && soundNameFromData.isNotEmpty) {
      channelConfig = {
        'id': channelIdFromData,
        'name': 'Email Notifications',
        'desc': 'Notifikasi email BaknusMail',
        'sound': soundNameFromData,
      };
    } else {
      final String senderStr = message.data['email_from'] ?? message.data['from'] ?? title;
      final String subjectStr = message.data['subject'] ?? title;
      channelConfig = _getChannelAndSound(senderStr, subjectStr);
    }

    // Cancel any previous notifications so only the latest notification is shown
    try {
      await _localNotificationsPlugin.cancelAll();
    } catch (_) {}

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelConfig['id']!,
      channelConfig['name']!,
      channelDescription: channelConfig['desc'],
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(channelConfig['sound']!),
      showWhen: true,
      tag: 'baknus_latest_email',
      groupKey: 'com.baknus.baknusmail.NOTIFICATIONS',
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      id: 8888,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: jsonEncode({'route': '/home'}),
    );
  }

  // Navigasi langsung ke layar Inbox saat notifikasi di-klik
  void _navigateToInbox() async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final mailProvider = context.read<MailProvider>();
        await mailProvider.loadFoldersAndEmails();
      } catch (_) {}
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  // Mendapatkan token dan menyimpannya ke Firestore (dipanggil saat login)
  Future<void> registerToken(String email) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        // Simpan ke Firestore di koleksi user_tokens dengan timeout 4 detik
        await _firestore
            .collection('user_tokens')
            .doc(email.toLowerCase().trim())
            .set({
              'fcm_token': token,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
        debugPrint('Token registered for $email');
      }
    } catch (e) {
      debugPrint('Warning: Could not save token to Firestore: $e');
    }
  }

  // Menghapus token dari Firestore (dipanggil saat logout)
  Future<void> unregisterToken(String email) async {
    try {
      await _firestore
          .collection('user_tokens')
          .doc(email.toLowerCase().trim())
          .delete()
          .timeout(const Duration(seconds: 3));
      await _firebaseMessaging.deleteToken();
      debugPrint('Token unregistered for $email');
    } catch (e) {
      debugPrint('Warning: Error unregistering FCM token: $e');
    }
  }
}
