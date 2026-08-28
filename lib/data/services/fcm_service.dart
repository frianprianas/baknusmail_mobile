import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/mail_provider.dart';

class PendingNotificationTarget {
  final String route;
  final Map<String, dynamic>? arguments;

  PendingNotificationTarget({required this.route, this.arguments});
}

class FCMService {
  FirebaseMessaging? get _firebaseMessaging {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static PendingNotificationTarget? pendingTarget;
  String? _currentRegisteredEmail;

  /// Memeriksa apakah aplikasi dibuka dari klik notifikasi (Terminated / Cold Start)
  Future<PendingNotificationTarget?> checkPendingNotificationLaunch() async {
    if (pendingTarget != null) {
      final target = pendingTarget;
      pendingTarget = null;
      return target;
    }

    try {
      final initialMsg = await _firebaseMessaging?.getInitialMessage();
      if (initialMsg != null) {
        return _extractTargetFromRemoteMessage(initialMsg);
      }
    } catch (_) {}

    try {
      final launchDetails =
          await _localNotificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse?.payload != null) {
        return _extractTargetFromPayload(
            launchDetails!.notificationResponse!.payload!);
      }
    } catch (_) {}

    return null;
  }

  PendingNotificationTarget _extractTargetFromRemoteMessage(RemoteMessage message) {
    String route = message.data['route']?.toString() ?? '';
    if (route == '/chat') {
      final peerEmail = message.data['peer_email'] ?? message.data['sender_email'];
      final peerName = message.data['peer_name'] ?? message.data['sender_name'];
      final peerTag = message.data['peer_tag'] ?? message.data['sender_tag'];
      return PendingNotificationTarget(
        route: '/chat',
        arguments: {
          'peerEmail': peerEmail,
          'peerName': peerName,
          'peerTag': peerTag,
        },
      );
    }

    if (route.isEmpty || route == '/home') {
      final senderStr =
          message.data['email_from'] ?? message.data['from'] ?? message.data['sender_name'] ?? '';
      final subjectStr =
          message.data['subject'] ?? message.data['title'] ?? message.data['notif_title'] ?? '';
      final config = _getChannelAndSound(senderStr, subjectStr);
      if (config['id'] == 'channel_baknus_attend_v3') {
        route = '/attend';
      } else if (config['id'] == 'channel_baknus_drive_v3') {
        route = '/drive';
      } else if (config['id'] == 'channel_baknus_talim_v3') {
        route = '/talim';
      } else {
        route = '/home';
      }
    }

    return PendingNotificationTarget(route: route);
  }

  PendingNotificationTarget? _extractTargetFromPayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload) as Map<String, dynamic>;
      String route = decoded['route']?.toString() ?? '';
      if (route == '/chat') {
        return PendingNotificationTarget(
          route: '/chat',
          arguments: {
            'peerEmail': decoded['peer_email'] ?? decoded['sender_email'],
            'peerName': decoded['peer_name'] ?? decoded['sender_name'],
            'peerTag': decoded['peer_tag'] ?? decoded['sender_tag'],
          },
        );
      }

      if (route.isEmpty || route == '/home') {
        final senderStr =
            decoded['email_from'] ?? decoded['from'] ?? decoded['sender_name'] ?? '';
        final subjectStr =
            decoded['subject'] ?? decoded['title'] ?? decoded['notif_title'] ?? '';
        final config = _getChannelAndSound(senderStr, subjectStr);
        if (config['id'] == 'channel_baknus_attend_v3') {
          route = '/attend';
        } else if (config['id'] == 'channel_baknus_drive_v3') {
          route = '/drive';
        } else if (config['id'] == 'channel_baknus_talim_v3') {
          route = '/talim';
        } else {
          route = '/home';
        }
      }

      return PendingNotificationTarget(route: route);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    final messaging = _firebaseMessaging;
    // 1. Minta izin notifikasi jika FCM tersedia
    if (messaging != null) {
      try {
        NotificationSettings settings = await messaging.requestPermission(
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

        messaging.onTokenRefresh.listen((newToken) {
          if (_currentRegisteredEmail != null && _currentRegisteredEmail!.isNotEmpty) {
            debugPrint('FCM token refreshed, re-registering for $_currentRegisteredEmail');
            registerToken(_currentRegisteredEmail!);
          }
        });
      } catch (e) {
        debugPrint('Warning: FCM permission request failed: $e');
      }
    }

    // 2. Setup Local Notifications untuk menangani notifikasi saat aplikasi dibuka (foreground)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(null, response.payload);
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
          description: 'Notifikasi email umum & pesan',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_umum'),
          playSound: true,
        ),
      );
    }

    // 3. Dengarkan notifikasi jika messaging tersedia
    if (messaging != null) {
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');

          final route = message.data['route']?.toString() ?? '';
          if (route != '/chat') {
            final mailProvider = navigatorKey.currentContext?.read<MailProvider>();
            if (mailProvider != null) {
              mailProvider.loadFoldersAndEmails().catchError((_) {});
            }
          }

          _showLocalNotification(message);
        });

        // 4. Ketika notifikasi di-tap dari latar belakang (background)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
          debugPrint('Notification clicked from background: ${message.data}');
          _handleNotificationTap(message, null);
        });

        // 5. Ketika aplikasi dibuka dari kondisi mati (terminated) karena notifikasi di-tap
        messaging.getInitialMessage().then((RemoteMessage? message) {
          if (message != null) {
            debugPrint('App launched from terminated notification: ${message.data}');
            _handleNotificationTap(message, null);
          }
        });
      } catch (_) {}
    }
  }

  // Menampilkan notifikasi background
  Future<void> showBackgroundNotification(RemoteMessage message) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotificationsPlugin.initialize(settings: initializationSettings);

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
          description: 'Notifikasi email umum & pesan',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('sound_umum'),
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
        'desc': 'Notifikasi email umum & pesan',
        'sound': 'sound_umum',
      };
    }
  }

  // Menampilkan notifikasi manual saat aplikasi sedang di foreground/background
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final String senderStr =
        message.data['email_from'] ?? message.data['from'] ?? message.data['sender_name'] ?? '';
    final String subjectStr =
        message.data['subject'] ?? message.data['title'] ?? message.data['notif_title'] ?? '';

    // Smart detection channel & sound
    final autoDetectedConfig = _getChannelAndSound(senderStr, subjectStr);
    final String channelIdFromData = message.data['channel_id'] ?? '';
    final String soundNameFromData = message.data['sound_name'] ?? '';

    late Map<String, String> channelConfig;
    if (channelIdFromData.isNotEmpty &&
        soundNameFromData.isNotEmpty &&
        channelIdFromData != 'channel_email_umum_v3') {
      channelConfig = {
        'id': channelIdFromData,
        'name': 'Email & Chat Notifications',
        'desc': 'Notifikasi pesan BaknusMail',
        'sound': soundNameFromData,
      };
    } else {
      channelConfig = autoDetectedConfig;
    }

    String title = message.data['notif_title'] ??
        message.notification?.title ??
        '';
    if (title.isEmpty || title == 'Pesan Masuk' || title == 'Email Baru') {
      if (channelConfig['id'] == 'channel_baknus_attend_v3') {
        title = 'BaknusAttend - Presensi';
      } else if (channelConfig['id'] == 'channel_baknus_drive_v3') {
        title = 'BaknusDrive - Berkas';
      } else if (channelConfig['id'] == 'channel_baknus_talim_v3') {
        title = 'BaknusTalim - Kegiatan';
      } else {
        title = senderStr.isNotEmpty ? senderStr.split('<').first.trim() : 'Pesan Masuk';
      }
    }

    final String body = message.data['notif_body'] ??
        message.notification?.body ??
        (subjectStr.isNotEmpty ? subjectStr : 'Anda mendapat pesan masuk');

    String targetRoute = message.data['route'] ?? '';
    if (targetRoute.isEmpty || targetRoute == '/home') {
      if (channelConfig['id'] == 'channel_baknus_attend_v3') {
        targetRoute = '/attend';
      } else if (channelConfig['id'] == 'channel_baknus_drive_v3') {
        targetRoute = '/drive';
      } else if (channelConfig['id'] == 'channel_baknus_talim_v3') {
        targetRoute = '/talim';
      } else {
        targetRoute = '/home';
      }
    }

    final isChat = targetRoute == '/chat';
    final payloadMap = Map<String, dynamic>.from(message.data);
    payloadMap['route'] = targetRoute;

    final notifTag = isChat
        ? 'baknus_chat_${message.data["peer_email"] ?? message.data["sender_email"] ?? "dm"}'
        : 'baknus_notif_${channelConfig["id"]}';

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
      tag: notifTag,
      groupKey: isChat
          ? 'com.baknus.baknusmail.CHAT'
          : 'com.baknus.baknusmail.NOTIFICATIONS',
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final notifId = isChat
        ? (message.data['peer_email'] ?? message.data['sender_email'] ?? 'chat').hashCode
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotificationsPlugin.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: jsonEncode(payloadMap),
    );
  }

  // Navigasi ke layar target (Chat Japri / BaknusAttend / Home / Drive / Talim) saat notifikasi di-klik
  void _handleNotificationTap(RemoteMessage? message, [String? localPayload]) async {
    PendingNotificationTarget? target;
    if (message != null) {
      target = _extractTargetFromRemoteMessage(message);
    } else if (localPayload != null && localPayload.isNotEmpty) {
      target = _extractTargetFromPayload(localPayload);
    }

    if (target == null) return;

    final context = navigatorKey.currentContext;

    if (target.route == '/chat') {
      navigatorKey.currentState?.pushNamed(
        '/chat',
        arguments: target.arguments,
      );
      return;
    }

    if (target.route == '/attend') {
      navigatorKey.currentState?.pushNamed('/attend');
      return;
    }

    if (target.route == '/drive') {
      navigatorKey.currentState?.pushNamed('/drive');
      return;
    }

    if (target.route == '/talim') {
      navigatorKey.currentState?.pushNamed('/talim');
      return;
    }

    // Default Email Masuk: Buka Inbox (/home)
    if (context != null) {
      try {
        final mailProvider = context.read<MailProvider>();
        mailProvider.selectInboxAndRefresh().catchError((_) {});
      } catch (_) {}
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  // Mendapatkan token dan menyimpannya ke Firestore (dipanggil saat login, mendukung multi-device)
  Future<void> registerToken(String email) async {
    final messaging = _firebaseMessaging;
    final firestore = _firestore;
    if (messaging == null || firestore == null) return;

    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return;
    _currentRegisteredEmail = cleanEmail;

    try {
      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await firestore
            .collection('user_tokens')
            .doc(cleanEmail)
            .set({
              'fcm_token': token,
              'fcm_tokens': FieldValue.arrayUnion([token]),
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
        debugPrint('Token registered for $cleanEmail');
      }
    } catch (e) {
      debugPrint('Warning: Could not save token to Firestore: $e');
    }
  }

  // Menghapus token dari Firestore (dipanggil saat logout)
  Future<void> unregisterToken(String email) async {
    final messaging = _firebaseMessaging;
    final firestore = _firestore;
    if (messaging == null || firestore == null) return;

    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return;
    _currentRegisteredEmail = null;

    try {
      String? token = await messaging.getToken();
      if (token != null) {
        await firestore
            .collection('user_tokens')
            .doc(cleanEmail)
            .update({
              'fcm_tokens': FieldValue.arrayRemove([token]),
            })
            .timeout(const Duration(seconds: 10));
      } else {
        await firestore
            .collection('user_tokens')
            .doc(cleanEmail)
            .delete()
            .timeout(const Duration(seconds: 10));
      }
      await messaging.deleteToken();
      debugPrint('Token unregistered for $cleanEmail');
    } catch (e) {
      debugPrint('Warning: Error unregistering FCM token: $e');
    }
  }
}
