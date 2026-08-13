import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/mail_provider.dart';
import '../models/email_message.dart';

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
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            _navigateToEmailDetail(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // 3. Dengarkan notifikasi saat aplikasi dibuka (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      // Otomatis refresh inbox saat ada email baru masuk
      try {
        navigatorKey.currentContext?.read<MailProvider>().loadFoldersAndEmails();
      } catch (_) {}

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // 4. Ketika notifikasi di-tap dari latar belakang (background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked from background: ${message.data}');
      try {
        navigatorKey.currentContext?.read<MailProvider>().loadFoldersAndEmails();
      } catch (_) {}
      _navigateToEmailDetail(message.data);
    });

    // 5. Ketika aplikasi dibuka dari kondisi mati (terminated) karena notifikasi di-tap
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App launched from terminated notification: ${message.data}');
        Future.delayed(const Duration(milliseconds: 800), () {
          try {
            navigatorKey.currentContext?.read<MailProvider>().loadFoldersAndEmails();
          } catch (_) {}
          _navigateToEmailDetail(message.data);
        });
      }
    });
  }

  // Menampilkan notifikasi manual saat aplikasi sedang di foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'email_notifications', // id channel
      'Email Notifications', // nama channel
      channelDescription: 'Notifications for incoming emails',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotificationsPlugin.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  // Navigasi langsung ke layar detail email saat notifikasi di-klik
  void _navigateToEmailDetail(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final senderRaw = data['email_from']?.toString() ?? data['from']?.toString() ?? 'Pengirim';
    String senderName = senderRaw;
    String senderEmail = senderRaw;
    if (senderRaw.contains('<') && senderRaw.contains('>')) {
      senderName = senderRaw.split('<').first.trim();
      senderEmail = senderRaw.split('<').last.replaceAll('>', '').trim();
    }

    final subject = data['subject']?.toString() ?? 'Email Masuk';
    final body = data['body']?.toString() ?? subject;
    final toEmail = data['email_to']?.toString() ?? data['to']?.toString() ?? '';

    final email = EmailMessage(
      messageId: data['message_id']?.toString() ?? 'notif-${DateTime.now().millisecondsSinceEpoch}',
      from: EmailAddressItem(name: senderName.isNotEmpty ? senderName : senderEmail, email: senderEmail),
      to: [EmailAddressItem(name: '', email: toEmail)],
      subject: subject,
      snippet: subject,
      bodyText: body,
      dateTime: DateTime.now(),
      isRead: true,
      folder: 'INBOX',
    );

    // Buka layar detail email
    navigatorKey.currentState?.pushNamed('/email_detail', arguments: email);
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
