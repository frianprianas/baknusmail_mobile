import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/baknus_service_models.dart';
import 'baknus_api_service.dart';
import 'baknus_backup_service.dart';
import 'chat_service.dart';

class ChatBackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BaknusApiService _apiService = BaknusApiService();
  final BaknusBackupService _backupService = BaknusBackupService();

  static const String _prefLastBackupTime = 'baknus_chat_last_backup_time';
  static const String _prefAutoBackupFrequency = 'baknus_chat_auto_backup_freq'; // 'off', 'daily', 'weekly'

  /// Mendapatkan Waktu Backup Terakhir (DateTime)
  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_prefLastBackupTime);
    if (iso != null && iso.isNotEmpty) {
      return DateTime.tryParse(iso);
    }
    return null;
  }

  /// Mendapatkan Frekuensi Auto Backup ('daily', 'weekly', 'off')
  Future<String> getAutoBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAutoBackupFrequency) ?? 'daily';
  }

  /// Mengubah Frekuensi Auto Backup
  Future<void> setAutoBackupFrequency(String freq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAutoBackupFrequency, freq);
  }

  /// Konversi rekursif Firestore Timestamp / DateTime ke String ISO8601 agar aman di-encode ke JSON
  dynamic _sanitizeForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((k, v) {
        result[k.toString()] = _sanitizeForJson(v);
      });
      return result;
    } else if (value is List) {
      return value.map((e) => _sanitizeForJson(e)).toList();
    }
    return value;
  }

  /// Ekspor seluruh percakapan & pesan pengguna ke format JSON Bytes
  Future<Map<String, dynamic>> exportChatPayload(String userEmail) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) throw Exception('Email pengguna tidak valid');

    List<Map<String, dynamic>> directConversations = [];
    List<Map<String, dynamic>> messagesList = [];
    final Set<String> targetRoomIds = {};

    // 1. Fetch Direct Conversations list & kumpulkan room ID Japri
    try {
      final directSnap = await _firestore
          .collection('baknus_chat_direct_conversations')
          .doc(cleanEmail)
          .collection('peers')
          .get();

      for (var doc in directSnap.docs) {
        final data = doc.data();
        final peerEmail = doc.id;
        data['id'] = peerEmail;
        final sanitized = _sanitizeForJson(data);
        if (sanitized is Map<String, dynamic>) {
          directConversations.add(sanitized);
        }

        // Kumpulkan room ID privat Antara cleanEmail dan peerEmail
        final privateRoomId = ChatService.getPrivateRoomId(cleanEmail, peerEmail);
        targetRoomIds.add(privateRoomId);
      }
    } catch (e) {
      debugPrint('Error fetching direct conversations for backup: $e');
    }

    // 2. Fetch Custom Groups di mana user menjadi anggota / creator & kumpulkan room ID Grup
    try {
      final groupsSnap = await _firestore.collection('baknus_custom_groups').get();
      for (var groupDoc in groupsSnap.docs) {
        final gData = groupDoc.data();
        final creatorEmail = gData['creatorEmail']?.toString().toLowerCase().trim() ?? '';
        final List<dynamic> members = List<dynamic>.from(gData['members'] ?? []);
        final isMember = members.any((m) {
          if (m is Map) return m['email']?.toString().toLowerCase().trim() == cleanEmail;
          return m.toString().toLowerCase().trim() == cleanEmail;
        });

        if (creatorEmail == cleanEmail || isMember) {
          targetRoomIds.add(groupDoc.id);
        }
      }
    } catch (e) {
      debugPrint('Error fetching user groups for backup: $e');
    }

    // 3. Cari room id tambahan di baknus_chat_rooms yang cocok (misal via sanitized email)
    final sanitizedEmail = cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    try {
      final roomsSnap = await _firestore.collection('baknus_chat_rooms').get();
      for (var roomDoc in roomsSnap.docs) {
        final roomId = roomDoc.id;
        if (roomId.contains(sanitizedEmail) || roomId.contains(cleanEmail)) {
          targetRoomIds.add(roomId);
        }
      }
    } catch (e) {
      debugPrint('Error searching chat rooms for backup: $e');
    }

    // 4. Ambil pesan dari setiap room ID yang dikumpulkan
    for (var roomId in targetRoomIds) {
      try {
        final msgsSnap = await _firestore
            .collection('baknus_chat_rooms')
            .doc(roomId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(500)
            .get();

        for (var mDoc in msgsSnap.docs) {
          final mData = mDoc.data();
          mData['messageId'] = mDoc.id;
          mData['roomId'] = roomId;

          final sanitized = _sanitizeForJson(mData);
          if (sanitized is Map<String, dynamic>) {
            messagesList.add(sanitized);
          }
        }
      } catch (e) {
        debugPrint('Error fetching messages for room $roomId: $e');
      }
    }

    final rawPayload = {
      'app': 'BaknusID',
      'service': 'BaknusChat',
      'version': 1,
      'user_email': cleanEmail,
      'exported_at': DateTime.now().toIso8601String(),
      'message_count': messagesList.length,
      'direct_conversations': directConversations,
      'messages': messagesList,
    };

    return _sanitizeForJson(rawPayload) as Map<String, dynamic>;
  }

  static const String _prefLocalBackupsPrefix = 'baknus_chat_local_backups_';
  static const String _prefLocalBackupPayloadPrefix = 'baknus_chat_payload_';

  /// Menyimpan backup ke lokal SharedPreferences jika upload ke API BaknusDrive gagal/offline
  Future<BaknusDriveBackup?> _saveLocalBackup({
    required String cleanEmail,
    required List<int> bytes,
    required String filename,
    required String backupType,
    required int messageCount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupId = 'local_backup_${DateTime.now().millisecondsSinceEpoch}';

      final backup = BaknusDriveBackup(
        backupId: backupId,
        filename: filename,
        createdAt: DateTime.now(),
        fileSize: bytes.length,
        messageCount: messageCount,
        backupType: backupType,
        downloadUrl: 'local://$backupId',
      );

      final jsonStr = utf8.decode(bytes);
      await prefs.setString('$_prefLocalBackupPayloadPrefix$backupId', jsonStr);

      final localListJson = prefs.getString('$_prefLocalBackupsPrefix$cleanEmail');
      List<dynamic> localList = [];
      if (localListJson != null && localListJson.isNotEmpty) {
        try {
          localList = jsonDecode(localListJson) as List? ?? [];
        } catch (_) {}
      }

      localList.insert(0, backup.toJson());

      // Batasi maksimal 3 file backup terbaru
      while (localList.length > 3) {
        final removed = localList.removeLast();
        if (removed is Map<String, dynamic> && removed['backup_id'] != null) {
          await prefs.remove('$_prefLocalBackupPayloadPrefix${removed['backup_id']}');
        }
      }

      await prefs.setString('$_prefLocalBackupsPrefix$cleanEmail', jsonEncode(localList));
      await prefs.setString(_prefLastBackupTime, DateTime.now().toIso8601String());

      return backup;
    } catch (e) {
      debugPrint('Error saving local backup: $e');
      return null;
    }
  }

  /// Mengambil daftar backup lokal
  Future<List<BaknusDriveBackup>> _getLocalBackups(String cleanEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localListJson = prefs.getString('$_prefLocalBackupsPrefix$cleanEmail');
      if (localListJson != null && localListJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(localListJson) as List? ?? [];
        return list
            .map((item) => BaknusDriveBackup.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error reading local backups: $e');
    }
    return [];
  }

  /// Eksekusi Backup (Manual / Otomatis) ke BaknusDrive REST API (dengan Fallback Lokal)
  Future<BaknusDriveBackup?> performBackup({
    required String userEmail,
    String backupType = 'manual',
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return null;

    try {
      final payload = await exportChatPayload(cleanEmail);
      final jsonString = jsonEncode(payload);
      final bytes = utf8.encode(jsonString);

      final dateStr = DateTime.now().toIso8601String().split('T')[0].replaceAll('-', '');
      final filename = 'baknuschat_backup_${cleanEmail.split('@')[0]}_$dateStr.json';
      final messageCount = (payload['messages'] as List? ?? []).length;

      BaknusDriveBackup? result;
      try {
        final res = await _backupService.uploadBackupBytes(
          email: cleanEmail,
          fileBytes: bytes,
          filename: filename,
          type: backupType,
          messageCount: messageCount,
        );
        if (res['success'] == true && res['data'] != null) {
          result = BaknusDriveBackup.fromJson(res['data'] as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('Upload to BaknusDrive API failed: $e. Using local storage fallback.');
      }

      if (result == null) {
        result = await _saveLocalBackup(
          cleanEmail: cleanEmail,
          bytes: bytes,
          filename: filename,
          backupType: backupType,
          messageCount: messageCount,
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLastBackupTime, DateTime.now().toIso8601String());
      }

      return result;
    } catch (e) {
      debugPrint('Error in performBackup: $e');
      return null;
    }
  }

  /// Mengambil daftar riwayat backup dari BaknusDrive & Penyimpanan Lokal
  Future<List<BaknusDriveBackup>> getBackups(String userEmail) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return [];

    List<BaknusDriveBackup> remoteBackups = [];
    try {
      final items = await _backupService.listBackups(email: cleanEmail);
      remoteBackups = items.map((i) => i.toBaknusDriveBackup()).toList();
    } catch (e) {
      debugPrint('Error fetching remote backups: $e');
    }

    final localBackups = await _getLocalBackups(cleanEmail);

    final combined = <String, BaknusDriveBackup>{};
    for (var b in remoteBackups) {
      combined[b.backupId] = b;
    }
    for (var b in localBackups) {
      if (!combined.containsKey(b.backupId)) {
        combined[b.backupId] = b;
      }
    }

    final list = combined.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Memulihkan (*restore*) data pesan dari file backup BaknusDrive ke Firestore
  Future<bool> restoreBackup({
    required String userEmail,
    required BaknusDriveBackup backup,
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return false;

    try {
      List<int>? bytes;

      if (backup.downloadUrl.startsWith('local://') || backup.backupId.startsWith('local_')) {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString('$_prefLocalBackupPayloadPrefix${backup.backupId}');
        if (jsonStr != null) {
          bytes = utf8.encode(jsonStr);
        }
      } else {
        try {
          bytes = await _apiService.downloadBackup(
            email: cleanEmail,
            backupId: backup.backupId,
            downloadUrl: backup.downloadUrl,
          );
        } catch (e) {
          debugPrint('Error downloading remote backup: $e');
        }

        if (bytes == null || bytes.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final jsonStr = prefs.getString('$_prefLocalBackupPayloadPrefix${backup.backupId}');
          if (jsonStr != null) {
            bytes = utf8.encode(jsonStr);
          }
        }
      }

      if (bytes == null || bytes.isEmpty) {
        debugPrint('Downloaded/Read backup bytes empty');
        return false;
      }

      final jsonString = utf8.decode(bytes);
      final Map<String, dynamic> data = jsonDecode(jsonString);

      final List<dynamic> messages = data['messages'] as List? ?? [];
      final List<dynamic> conversations = data['direct_conversations'] as List? ?? [];

      // Restore Direct Conversations
      for (var conv in conversations) {
        if (conv is Map<String, dynamic>) {
          final peerEmail = (conv['id'] ?? conv['peerEmail'])?.toString().toLowerCase().trim();
          if (peerEmail != null && peerEmail.isNotEmpty) {
            DateTime lastTime = DateTime.now();
            if (conv['lastTimestamp'] != null) {
              lastTime = DateTime.tryParse(conv['lastTimestamp'].toString()) ?? DateTime.now();
            }

            await _firestore
                .collection('baknus_chat_direct_conversations')
                .doc(cleanEmail)
                .collection('peers')
                .doc(peerEmail)
                .set({
              'peerEmail': conv['peerEmail'] ?? peerEmail,
              'peerName': conv['peerName'] ?? 'Pengguna',
              'peerTag': conv['peerTag'] ?? 'Siswa',
              'lastMessage': conv['lastMessage'] ?? '',
              'lastTimestamp': Timestamp.fromDate(lastTime),
              'unreadCount': 0,
            }, SetOptions(merge: true));
          }
        }
      }

      // Restore Messages to Firestore Rooms
      for (var msg in messages) {
        if (msg is Map<String, dynamic>) {
          final roomId = msg['roomId']?.toString();
          final messageId = msg['messageId']?.toString();

          if (roomId != null && roomId.isNotEmpty && messageId != null && messageId.isNotEmpty) {
            DateTime timestamp = DateTime.now();
            if (msg['timestamp'] != null) {
              timestamp = DateTime.tryParse(msg['timestamp'].toString()) ?? DateTime.now();
            }

            final Map<String, dynamic> msgMap = Map<String, dynamic>.from(msg);
            msgMap.remove('messageId');
            msgMap.remove('roomId');
            msgMap['timestamp'] = Timestamp.fromDate(timestamp);

            if (msgMap['readAt'] != null && msgMap['readAt'] is String) {
              final rAt = DateTime.tryParse(msgMap['readAt'].toString());
              if (rAt != null) {
                msgMap['readAt'] = Timestamp.fromDate(rAt);
              }
            }

            await _firestore
                .collection('baknus_chat_rooms')
                .doc(roomId)
                .collection('messages')
                .doc(messageId)
                .set(msgMap, SetOptions(merge: true));
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring chat backup: $e');
      return false;
    }
  }

  /// Menghapus file backup dari BaknusDrive / Lokal
  Future<bool> deleteBackup({
    required String userEmail,
    required String backupId,
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return false;

    bool remoteDeleted = false;
    try {
      remoteDeleted = await _backupService.deleteBackup(backupId: backupId, email: cleanEmail);
    } catch (e) {
      debugPrint('Error deleting remote backup: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefLocalBackupPayloadPrefix$backupId');

      final localListJson = prefs.getString('$_prefLocalBackupsPrefix$cleanEmail');
      if (localListJson != null && localListJson.isNotEmpty) {
        final List<dynamic> localList = jsonDecode(localListJson) as List? ?? [];
        localList.removeWhere((item) => item is Map<String, dynamic> && item['backup_id'] == backupId);
        await prefs.setString('$_prefLocalBackupsPrefix$cleanEmail', jsonEncode(localList));
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting local backup: $e');
    }

    return remoteDeleted;
  }

  /// Pengecekan otomatis saat aplikasi aktif untuk menjalankan auto-backup jika jadwalnya tiba
  Future<void> checkAndRunAutoBackup(String userEmail) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return;

    final freq = await getAutoBackupFrequency();
    if (freq == 'off') return;

    final lastBackup = await getLastBackupTime();
    final now = DateTime.now();

    bool shouldBackup = false;
    if (lastBackup == null) {
      shouldBackup = true;
    } else if (freq == 'daily' && now.difference(lastBackup).inHours >= 24) {
      shouldBackup = true;
    } else if (freq == 'weekly' && now.difference(lastBackup).inDays >= 7) {
      shouldBackup = true;
    }

    if (shouldBackup) {
      debugPrint('Running scheduled auto-backup for BaknusChat ($freq)...');
      await performBackup(userEmail: cleanEmail, backupType: 'auto');
    }
  }
}
