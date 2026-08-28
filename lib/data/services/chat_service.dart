import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/custom_group.dart';
import 'link_preview_service.dart';

class DirectConversationItem {
  final String peerEmail;
  final String peerName;
  final String peerTag;
  final String lastMessage;
  final DateTime lastTimestamp;
  final int unreadCount;
  final bool isPinned;
  final DateTime? pinnedAt;

  DirectConversationItem({
    required this.peerEmail,
    required this.peerName,
    required this.peerTag,
    required this.lastMessage,
    required this.lastTimestamp,
    this.unreadCount = 0,
    this.isPinned = false,
    this.pinnedAt,
  });

  factory DirectConversationItem.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return DirectConversationItem(
      peerEmail: map['peerEmail']?.toString() ?? '',
      peerName: map['peerName']?.toString() ?? 'Pengguna',
      peerTag: map['peerTag']?.toString() ?? 'Siswa',
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastTimestamp: parseDate(map['lastTimestamp']),
      unreadCount: (map['unreadCount'] is num) ? (map['unreadCount'] as num).toInt() : 0,
      isPinned: map['isPinned'] == true,
      pinnedAt: map['pinnedAt'] != null ? parseDate(map['pinnedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'peerEmail': peerEmail,
        'peerName': peerName,
        'peerTag': peerTag,
        'lastMessage': lastMessage,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': unreadCount,
        'isPinned': isPinned,
        'pinnedAt': pinnedAt != null ? Timestamp.fromDate(pinnedAt!) : null,
      };
}

class BaknusWebSession {
  final String sessionId;
  final String status; // 'pending' | 'authenticated' | 'expired' | 'revoked'
  final DateTime createdAt;
  final DateTime? authenticatedAt;
  final String? userEmail;
  final String? userName;
  final String? userRole;
  final String? deviceInfo;
  final String? ipAddress;

  BaknusWebSession({
    required this.sessionId,
    required this.status,
    required this.createdAt,
    this.authenticatedAt,
    this.userEmail,
    this.userName,
    this.userRole,
    this.deviceInfo,
    this.ipAddress,
  });

  factory BaknusWebSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return BaknusWebSession(
      sessionId: doc.id,
      status: data['status']?.toString() ?? 'pending',
      createdAt: parseDate(data['createdAt']),
      authenticatedAt: data['authenticatedAt'] != null ? parseDate(data['authenticatedAt']) : null,
      userEmail: data['userEmail']?.toString(),
      userName: data['userName']?.toString(),
      userRole: data['userRole']?.toString(),
      deviceInfo: data['deviceInfo']?.toString(),
      ipAddress: data['ipAddress']?.toString(),
    );
  }
}

class UserPresence {
  final String email;
  final bool isOnline;
  final DateTime? lastSeen;

  UserPresence({
    required this.email,
    required this.isOnline,
    this.lastSeen,
  });

  factory UserPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? parsedDate;
    final rawSeen = data['lastSeen'];
    if (rawSeen is Timestamp) parsedDate = rawSeen.toDate();
    if (rawSeen is String) parsedDate = DateTime.tryParse(rawSeen);

    bool active = data['isOnline'] == true;
    if (active && parsedDate != null) {
      final diff = DateTime.now().difference(parsedDate);
      if (diff.inMinutes > 5) {
        active = false;
      }
    }

    return UserPresence(
      email: doc.id,
      isOnline: active,
      lastSeen: parsedDate,
    );
  }
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String roomsCollection = 'baknus_chat_rooms';
  static const String directConversationsCollection = 'baknus_chat_direct_conversations';
  static const String userPresenceCollection = 'baknus_user_presence';
  static const String customGroupsCollection = 'baknus_custom_groups';
  static const String webSessionsCollection = 'baknus_web_sessions';

  /// 1. Buat Web QR Session ID baru (Dipanggil oleh Web Client di web.baknuschat.smkbn666.sch.id)
  Future<String> createWebQrSession() async {
    final docRef = _firestore.collection(webSessionsCollection).doc();
    final sessionId = docRef.id;

    await docRef.set({
      'sessionId': sessionId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
    });

    return sessionId;
  }

  /// 2. Stream status Web QR Session real-time (Dipanggil oleh Web Client untuk mendengarkan saat QR di-scan)
  Stream<BaknusWebSession?> streamWebQrSession(String sessionId) {
    if (sessionId.isEmpty) return Stream.value(null);
    return _firestore
        .collection(webSessionsCollection)
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? BaknusWebSession.fromFirestore(doc) : null);
  }

  /// 3. Otentikasi Web QR Session oleh HP (Dipanggil setelah kamera HP berhasil scan QR Code)
  Future<bool> authenticateWebQrSession({
    required String sessionId,
    required String userEmail,
    required String userName,
    required String userRole,
    String deviceInfo = 'BaknusChat Web Client',
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (sessionId.isEmpty || cleanEmail.isEmpty) return false;

    try {
      final docRef = _firestore.collection(webSessionsCollection).doc(sessionId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return false;

      await docRef.update({
        'status': 'authenticated',
        'userEmail': cleanEmail,
        'userName': userName,
        'userRole': userRole,
        'deviceInfo': deviceInfo,
        'authenticatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error authenticating Web QR session: $e');
      return false;
    }
  }

  /// 4. Stream daftar perangkat web tertaut milik pengguna tertentu (Dipanggil di HP untuk manajemen perangkat)
  Stream<List<BaknusWebSession>> getLinkedDevicesStream(String userEmail) {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return Stream.value([]);

    return _firestore
        .collection(webSessionsCollection)
        .where('userEmail', isEqualTo: cleanEmail)
        .where('status', isEqualTo: 'authenticated')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => BaknusWebSession.fromFirestore(doc)).toList());
  }

  /// 5. Revoke / Keluar dari Perangkat Tertaut tertentu (Logout Web dari HP)
  Future<void> revokeWebSession(String sessionId) async {
    if (sessionId.isEmpty) return;
    try {
      await _firestore.collection(webSessionsCollection).doc(sessionId).update({
        'status': 'revoked',
        'revokedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error revoking web session: $e');
    }
  }

  /// 6. Revoke / Keluar dari Semua Perangkat Web Tertaut milik user
  Future<void> revokeAllWebSessions(String userEmail) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return;

    try {
      final snap = await _firestore
          .collection(webSessionsCollection)
          .where('userEmail', isEqualTo: cleanEmail)
          .where('status', isEqualTo: 'authenticated')
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'status': 'revoked',
          'revokedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error revoking all web sessions: $e');
    }
  }

  /// Update status presence real-time user (online/offline)
  Future<void> updateUserPresence(String userEmail, bool isOnline) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return;
    try {
      await _firestore.collection(userPresenceCollection).doc(cleanEmail).set({
        'email': cleanEmail,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating presence for $cleanEmail: $e');
    }
  }

  /// Stream status presence real-time untuk user tertentu
  Stream<UserPresence> getUserPresenceStream(String targetEmail) {
    final cleanEmail = targetEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) {
      return Stream.value(UserPresence(email: '', isOnline: false));
    }
    return _firestore
        .collection(userPresenceCollection)
        .doc(cleanEmail)
        .snapshots()
        .map((doc) => doc.exists
            ? UserPresence.fromFirestore(doc)
            : UserPresence(email: cleanEmail, isOnline: false));
  }

  /// Toggle Reaksi Emoji pada pesan tertentu
  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String emoji,
    required String userEmail,
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty || messageId.isEmpty || roomId.isEmpty) return;

    final docRef = _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .doc(messageId);

    try {
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      List<dynamic> users = List<dynamic>.from(reactions[emoji] ?? []);

      if (users.contains(cleanEmail)) {
        users.remove(cleanEmail);
      } else {
        users.add(cleanEmail);
      }

      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }

      await docRef.update({'reactions': reactions});
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  /// Toggle Pin Message di room tertentu
  Future<void> togglePinMessage({
    required String roomId,
    required String messageId,
    required bool currentPinState,
  }) async {
    if (messageId.isEmpty || roomId.isEmpty) return;

    final docRef = _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .doc(messageId);

    try {
      await docRef.update({'isPinned': !currentPinState});
    } catch (e) {
      debugPrint('Error toggling pin message: $e');
    }
  }

  /// Update status sedang mengetik (typing indicator)
  Future<void> setTypingStatus({
    required String roomId,
    required String userEmail,
    required String userName,
    required bool isTyping,
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty || roomId.isEmpty) return;

    final docRef = _firestore
        .collection('baknus_chat_typing')
        .doc('${roomId}___$cleanEmail');

    try {
      if (isTyping) {
        await docRef.set({
          'roomId': roomId,
          'userEmail': cleanEmail,
          'userName': userName,
          'isTyping': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await docRef.delete();
      }
    } catch (e) {
      debugPrint('Error setting typing status: $e');
    }
  }

  /// Stream daftar user yang sedang mengetik di room tertentu
  Stream<List<Map<String, dynamic>>> getTypingStatusStream(String roomId, String currentEmail) {
    final cleanEmail = currentEmail.toLowerCase().trim();
    return _firestore
        .collection('baknus_chat_typing')
        .where('roomId', isEqualTo: roomId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data())
          .where((data) =>
              data['userEmail']?.toString().toLowerCase() != cleanEmail &&
              data['isTyping'] == true)
          .toList();
    });
  }

  /// Formula deterministik Room ID untuk Chat Pribadi (Japri) antara 2 email
  static String getPrivateRoomId(String email1, String email2) {
    final e1 = email1.toLowerCase().trim();
    final e2 = email2.toLowerCase().trim();
    final list = [e1, e2]..sort();
    final sanitized = '${list[0]}___${list[1]}'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'dm_$sanitized';
  }

  /// Stream pesan real-time berdasarkan roomId (Grup maupun Japri) dengan opsional limit pagination
  Stream<List<ChatMessage>> getMessagesStream(String roomId, {int limit = 50}) {
    return _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .where((msg) => !msg.isExpired)
          .toList();

      // Urutkan berdasarkan waktu secara in-memory (0 error FAILED_PRECONDITION)
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Paging / Limit pesan terbaru agar memori & tampilan chat rapi
      if (limit > 0 && list.length > limit) {
        return list.sublist(list.length - limit);
      }
      return list;
    });
  }

  /// Stream daftar riwayat percakapan Japri aktif milik user
  Stream<List<DirectConversationItem>> getDirectConversationsStream(String userEmail) {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return Stream.value([]);

    return _firestore
        .collection(directConversationsCollection)
        .doc(cleanEmail)
        .collection('peers')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => DirectConversationItem.fromMap(doc.data()))
          .toList();
      list.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        if (a.isPinned && b.isPinned) {
          final aPinTime = a.pinnedAt ?? a.lastTimestamp;
          final bPinTime = b.pinnedAt ?? b.lastTimestamp;
          return bPinTime.compareTo(aPinTime);
        }
        return b.lastTimestamp.compareTo(a.lastTimestamp);
      });
      return list;
    });
  }

  /// Pin atau lepas Pin percakapan Japri (Maksimal 3 percakapan)
  Future<bool> togglePinConversation({
    required String userEmail,
    required String peerEmail,
    required bool isPinned,
  }) async {
    final cleanUser = userEmail.toLowerCase().trim();
    final cleanPeer = peerEmail.toLowerCase().trim();
    if (cleanUser.isEmpty || cleanPeer.isEmpty) return false;

    final docRef = _firestore
        .collection(directConversationsCollection)
        .doc(cleanUser)
        .collection('peers')
        .doc(cleanPeer);

    if (isPinned) {
      // Cek jumlah percakapan yang sudah di-pin saat ini
      final pinnedSnap = await _firestore
          .collection(directConversationsCollection)
          .doc(cleanUser)
          .collection('peers')
          .where('isPinned', isEqualTo: true)
          .get();

      if (pinnedSnap.docs.length >= 3) {
        // Sudah mencapai batas maksimal 3
        return false;
      }

      await docRef.set({
        'isPinned': true,
        'pinnedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } else {
      await docRef.set({
        'isPinned': false,
        'pinnedAt': null,
      }, SetOptions(merge: true));
      return true;
    }
  }

  /// Stream total unread chat messages count across all active conversations
  Stream<int> getUnreadCountStream(String userEmail) {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return Stream.value(0);

    return _firestore
        .collection(directConversationsCollection)
        .doc(cleanEmail)
        .collection('peers')
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final count = (data['unreadCount'] is num) ? (data['unreadCount'] as num).toInt() : 0;
        totalUnread += count;
      }
      return totalUnread;
    });
  }

  /// Menandai percakapan dengan peerEmail telah dibaca (unreadCount = 0 & update status baca di Firestore)
  Future<void> markConversationAsRead(String userEmail, String peerEmail) async {
    final cleanUser = userEmail.toLowerCase().trim();
    final cleanPeer = peerEmail.toLowerCase().trim();
    if (cleanUser.isEmpty || cleanPeer.isEmpty) return;

    try {
      await _firestore
          .collection(directConversationsCollection)
          .doc(cleanUser)
          .collection('peers')
          .doc(cleanPeer)
          .update({'unreadCount': 0});
    } catch (_) {}

    final roomId = getPrivateRoomId(cleanUser, cleanPeer);
    await markRoomMessagesAsRead(roomId: roomId, readerEmail: cleanUser);
  }

  /// Menandai semua pesan di dalam room dari lawan bicara menjadi 'dibaca' (isRead: true)
  Future<void> markRoomMessagesAsRead({
    required String roomId,
    required String readerEmail,
  }) async {
    final cleanReader = readerEmail.toLowerCase().trim();
    if (cleanReader.isEmpty || roomId.isEmpty) return;

    try {
      final messagesSnapshot = await _firestore
          .collection(roomsCollection)
          .doc(roomId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      if (messagesSnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      int count = 0;

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        final sender = (data['senderEmail']?.toString() ?? '').toLowerCase().trim();
        // Hanya tandai pesan yang dikirim oleh LAWAN BICARA (bukan pesan kita sendiri)
        if (sender.isNotEmpty && sender != cleanReader) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking room messages as read: $e');
    }
  }

  /// Kirim pesan baru (Grup atau Japri) dengan TTL otomatis 24 jam dan notifikasi FCM
  Future<void> sendMessage({
    required String roomId,
    required String text,
    required String senderEmail,
    required String senderName,
    required String senderRole, // TAG: 'Guru' | 'TU' | 'Siswa'
    String? recipientEmail,
    String? recipientName,
    String? recipientTag,
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    try {
      // 1. Simpan pesan ke subcollection room dengan status awal isRead = false
      final msgData = <String, dynamic>{
        'roomId': roomId,
        'text': cleanText,
        'senderEmail': senderEmail.toLowerCase().trim(),
        'senderName': senderName.trim(),
        'senderRole': senderRole.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'isRead': false,
        'readAt': null,
      };

      if (replyToId != null && replyToId.isNotEmpty) {
        msgData['replyToId'] = replyToId;
        msgData['replyToSenderName'] = replyToSenderName;
        msgData['replyToText'] = replyToText;
      }

      // Deteksi & Ekstrak Link Preview otomatis untuk Tautan Website / YouTube
      final extractedUrl = LinkPreviewService.extractUrl(cleanText);
      if (extractedUrl != null && extractedUrl.isNotEmpty) {
        final previewData = await LinkPreviewService.fetchMetadata(extractedUrl);
        if (previewData != null) {
          msgData['linkUrl'] = previewData.url;
          msgData['linkTitle'] = previewData.title;
          msgData['linkDescription'] = previewData.description;
          if (previewData.imageUrl != null) {
            msgData['linkImageUrl'] = previewData.imageUrl;
          }
        }
      }

      await _firestore
          .collection(roomsCollection)
          .doc(roomId)
          .collection('messages')
          .add(msgData);

      // 2. Jika ini adalah Chat Pribadi (Japri), simpan riwayat percakapan untuk kedua belah pihak & picu notifikasi
      if (recipientEmail != null && recipientEmail.isNotEmpty) {
        final sEmail = senderEmail.toLowerCase().trim();
        final rEmail = recipientEmail.toLowerCase().trim();

        // Simpan di kontak pengirim (unreadCount = 0)
        await _firestore
            .collection(directConversationsCollection)
            .doc(sEmail)
            .collection('peers')
            .doc(rEmail)
            .set({
          'peerEmail': rEmail,
          'peerName': recipientName ?? rEmail.split('@').first,
          'peerTag': recipientTag ?? 'Siswa',
          'lastMessage': cleanText,
          'lastTimestamp': FieldValue.serverTimestamp(),
          'unreadCount': 0,
        }, SetOptions(merge: true));

        // Simpan di kontak penerima (unreadCount + 1)
        await _firestore
            .collection(directConversationsCollection)
            .doc(rEmail)
            .collection('peers')
            .doc(sEmail)
            .set({
          'peerEmail': sEmail,
          'peerName': senderName,
          'peerTag': senderRole,
          'lastMessage': cleanText,
          'lastTimestamp': FieldValue.serverTimestamp(),
          'unreadCount': FieldValue.increment(1),
        }, SetOptions(merge: true));

        // 3. Picu Push Notifikasi ke penerima melalui Server Backend
        _notifyRecipient(
          recipientEmail: rEmail,
          senderEmail: sEmail,
          senderName: senderName,
          senderRole: senderRole,
          messageText: cleanText,
        );
      }
    } catch (e) {
      debugPrint('Error sending BaknusChat message: $e');
      rethrow;
    }
  }

  /// Upload media gambar atau berkas (Dokumen/PDF/ZIP/RAR) ke BaknusDrive API (API Key: BAKNUS_CHAT_SECRET)
  Future<Map<String, dynamic>?> uploadFileToBaknusDrive({
    required String senderEmail,
    String? filePath,
    Uint8List? fileBytes,
    required String filename,
    String? peerEmail,
  }) async {
    try {
      final uri = Uri.parse('https://baknusdrive.smkbn666.sch.id/api/chat/upload');
      final request = http.MultipartRequest('POST', uri);

      request.headers['X-Chat-API-Key'] = 'BAKNUS_CHAT_SECRET';
      request.fields['email'] = senderEmail.trim().toLowerCase();
      if (peerEmail != null && peerEmail.isNotEmpty) {
        request.fields['peer_email'] = peerEmail.trim().toLowerCase();
      }

      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
      } else if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));
      } else {
        throw Exception('File tidak valid');
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true || data['file_url'] != null) {
          return data;
        }
      }
      debugPrint('Upload file to BaknusDrive failed (${response.statusCode}): ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error uploading file to BaknusDrive: $e');
      return null;
    }
  }

  /// Alias untuk kompatibilitas upload gambar
  Future<Map<String, dynamic>?> uploadImageToBaknusDrive({
    required String senderEmail,
    String? filePath,
    Uint8List? fileBytes,
    required String filename,
    String? peerEmail,
  }) =>
      uploadFileToBaknusDrive(
        senderEmail: senderEmail,
        filePath: filePath,
        fileBytes: fileBytes,
        filename: filename,
        peerEmail: peerEmail,
      );

  /// Kirim pesan dokumen/file publik dari link BaknusDrive
  Future<void> sendDocumentFileMessage({
    required String roomId,
    required String fileUrl,
    required String filename,
    int? fileSize,
    String? mimeType,
    required String senderEmail,
    required String senderName,
    required String senderRole,
  }) async {
    final msgData = <String, dynamic>{
      'roomId': roomId,
      'text': '📄 $filename',
      'messageType': 'file',
      'fileUrl': fileUrl,
      'filename': filename,
      'fileSize': fileSize ?? 0,
      'mimeType': mimeType ?? 'application/octet-stream',
      'senderEmail': senderEmail.toLowerCase().trim(),
      'senderName': senderName.trim(),
      'senderRole': senderRole.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': null,
      'isRead': false,
      'readAt': null,
    };

    await _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .add(msgData);
  }

  /// Kirim pesan stiker ke room chat
  Future<void> sendStickerMessage({
    required String roomId,
    required String stickerUrl,
    required String stickerName,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    String? recipientEmail,
    String? recipientName,
    String? recipientTag,
  }) async {
    final msgData = <String, dynamic>{
      'roomId': roomId,
      'text': '🏷️ Stiker: $stickerName',
      'messageType': 'sticker',
      'fileUrl': stickerUrl,
      'filename': stickerName,
      'senderEmail': senderEmail.toLowerCase().trim(),
      'senderName': senderName.trim(),
      'senderRole': senderRole.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': null,
      'isRead': false,
      'readAt': null,
    };

    await _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .add(msgData);

    final isCustomGroup = !roomId.startsWith('dm_') && !roomId.startsWith('private_');

    if (!isCustomGroup && recipientEmail != null && recipientEmail.isNotEmpty) {
      final cleanRecipient = recipientEmail.toLowerCase().trim();
      final cleanSender = senderEmail.toLowerCase().trim();

      await _firestore
          .collection(directConversationsCollection)
          .doc(cleanSender)
          .collection('peers')
          .doc(cleanRecipient)
          .set({
        'peerEmail': cleanRecipient,
        'peerName': recipientName ?? cleanRecipient.split('@').first,
        'peerTag': recipientTag ?? 'Siswa',
        'lastMessage': '🏷️ Stiker',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));

      await _firestore
          .collection(directConversationsCollection)
          .doc(cleanRecipient)
          .collection('peers')
          .doc(cleanSender)
          .set({
        'peerEmail': cleanSender,
        'peerName': senderName,
        'peerTag': senderRole,
        'lastMessage': '🏷️ Stiker',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _notifyRecipient(
        recipientEmail: cleanRecipient,
        senderEmail: cleanSender,
        senderName: senderName,
        senderRole: senderRole,
        messageText: '🏷️ Stiker: $stickerName',
      );
    } else if (isCustomGroup) {
      await _firestore.collection('baknus_custom_groups').doc(roomId).update({
        'lastMessage': '$senderName: 🏷️ Stiker',
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Kirim berkas dokumen/arsip (PDF, DOCX, XLSX, ZIP, RAR, 7Z, TXT) ke room chat dengan unggah ke BaknusDrive
  Future<void> sendFileMessage({
    required String roomId,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    String? caption,
    String? filePath,
    Uint8List? fileBytes,
    required String filename,
    int? fileSize,
    String? recipientEmail,
    String? recipientName,
    String? recipientTag,
  }) async {
    // 1. Unggah berkas ke BaknusDrive
    final uploadResult = await uploadFileToBaknusDrive(
      senderEmail: senderEmail,
      filePath: filePath,
      fileBytes: fileBytes,
      filename: filename,
      peerEmail: recipientEmail,
    );

    if (uploadResult == null || uploadResult['file_url'] == null) {
      throw Exception('Gagal mengunggah berkas ke BaknusDrive. Periksa koneksi Anda.');
    }

    final fileUrl = uploadResult['file_url'].toString();
    final fileId = uploadResult['file_id'] is num ? (uploadResult['file_id'] as num).toInt() : null;
    final mimeType = uploadResult['mime_type']?.toString();

    // Deteksi tipe berkas
    final lowerName = filename.toLowerCase();
    String msgType = 'file';
    if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp')) {
      msgType = 'image';
    } else if (lowerName.endsWith('.zip') ||
        lowerName.endsWith('.rar') ||
        lowerName.endsWith('.7z') ||
        lowerName.endsWith('.tar') ||
        lowerName.endsWith('.gz')) {
      msgType = 'archive';
    } else {
      msgType = 'document';
    }

    final cleanCaption = (caption ?? '').trim();
    String defaultIconPrefix = '📄';
    if (msgType == 'image') defaultIconPrefix = '📷';
    if (msgType == 'archive') defaultIconPrefix = '📦';

    final displayText = cleanCaption.isNotEmpty ? cleanCaption : '$defaultIconPrefix $filename';

    // 2. Simpan pesan berkas ke Firestore
    await _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .add({
      'roomId': roomId,
      'text': displayText,
      'fileUrl': fileUrl,
      'imageUrl': msgType == 'image' ? fileUrl : null,
      'fileName': filename,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'fileId': fileId,
      'type': msgType,
      'senderEmail': senderEmail.toLowerCase().trim(),
      'senderName': senderName.trim(),
      'senderRole': senderRole.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': null,
      'isRead': false,
      'readAt': null,
    });

    // 3. Simpan riwayat percakapan untuk kedua belah pihak & picu notifikasi FCM jika chat pribadi
    if (recipientEmail != null && recipientEmail.isNotEmpty) {
      final sEmail = senderEmail.toLowerCase().trim();
      final rEmail = recipientEmail.toLowerCase().trim();

      await _firestore
          .collection(directConversationsCollection)
          .doc(sEmail)
          .collection('peers')
          .doc(rEmail)
          .set({
        'peerEmail': rEmail,
        'peerName': recipientName ?? rEmail.split('@').first,
        'peerTag': recipientTag ?? 'Siswa',
        'lastMessage': '$defaultIconPrefix $filename',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));

      await _firestore
          .collection(directConversationsCollection)
          .doc(rEmail)
          .collection('peers')
          .doc(sEmail)
          .set({
        'peerEmail': sEmail,
        'peerName': senderName,
        'peerTag': senderRole,
        'lastMessage': '$defaultIconPrefix $filename',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _notifyRecipient(
        recipientEmail: rEmail,
        senderEmail: sEmail,
        senderName: senderName,
        senderRole: senderRole,
        messageText: '$defaultIconPrefix $filename',
      );
    }
  }

  /// Kirim pesan suara (Voice Note max 10s) dengan unggah otomatis ke BaknusDrive
  Future<void> sendVoiceNoteMessage({
    required String roomId,
    required String filePath,
    required int durationSec,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    String? recipientEmail,
    String? recipientName,
    String? recipientTag,
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
  }) async {
    final filename = 'VN_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final uploadResult = await uploadFileToBaknusDrive(
      senderEmail: senderEmail,
      filePath: filePath,
      filename: filename,
      peerEmail: recipientEmail,
    );

    if (uploadResult == null || uploadResult['file_url'] == null) {
      throw Exception('Gagal mengunggah pesan suara ke BaknusDrive. Periksa koneksi Anda.');
    }

    final fileUrl = uploadResult['file_url'].toString();

    final msgData = <String, dynamic>{
      'roomId': roomId,
      'text': '🎙️ Pesan Suara (${durationSec}d)',
      'senderEmail': senderEmail.toLowerCase().trim(),
      'senderName': senderName.trim(),
      'senderRole': senderRole.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': null,
      'isRead': false,
      'readAt': null,
      'fileUrl': fileUrl,
      'fileName': filename,
      'type': 'audio',
      'audioDuration': durationSec,
    };

    if (replyToId != null && replyToId.isNotEmpty) {
      msgData['replyToId'] = replyToId;
      msgData['replyToSenderName'] = replyToSenderName;
      msgData['replyToText'] = replyToText;
    }

    await _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .add(msgData);

    if (recipientEmail != null && recipientEmail.isNotEmpty) {
      final sEmail = senderEmail.toLowerCase().trim();
      final rEmail = recipientEmail.toLowerCase().trim();

      await _firestore
          .collection(directConversationsCollection)
          .doc(sEmail)
          .collection('peers')
          .doc(rEmail)
          .set({
        'peerEmail': rEmail,
        'peerName': recipientName ?? rEmail.split('@').first,
        'peerTag': recipientTag ?? 'Siswa',
        'lastMessage': '🎙️ Pesan Suara (${durationSec}d)',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));

      await _firestore
          .collection(directConversationsCollection)
          .doc(rEmail)
          .collection('peers')
          .doc(sEmail)
          .set({
        'peerEmail': sEmail,
        'peerName': senderName,
        'peerTag': senderRole,
        'lastMessage': '🎙️ Pesan Suara (${durationSec}d)',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _notifyRecipient(
        recipientEmail: rEmail,
        senderEmail: sEmail,
        senderName: senderName,
        senderRole: senderRole,
        messageText: '🎙️ Pesan Suara (${durationSec}d)',
      );
    }
  }

  /// Kirim pesan gambar ke room chat dengan unggah ke BaknusDrive dan notifikasi FCM
  Future<void> sendImageMessageLegacy({
    required String roomId,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    String? caption,
    String? filePath,
    Uint8List? fileBytes,
    required String filename,
    String? recipientEmail,
    String? recipientName,
    String? recipientTag,
  }) async {
    // 1. Unggah gambar ke BaknusDrive
    final uploadResult = await uploadImageToBaknusDrive(
      senderEmail: senderEmail,
      filePath: filePath,
      fileBytes: fileBytes,
      filename: filename,
      peerEmail: recipientEmail,
    );

    if (uploadResult == null || uploadResult['file_url'] == null) {
      throw Exception('Gagal mengunggah gambar ke BaknusDrive. Periksa koneksi Anda.');
    }

    final fileUrl = uploadResult['file_url'].toString();
    final fileId = uploadResult['file_id'] is num ? (uploadResult['file_id'] as num).toInt() : null;
    final cleanCaption = (caption ?? '').trim();
    final displayText = cleanCaption.isNotEmpty ? cleanCaption : '📷 Foto';

    // 2. Simpan pesan gambar ke Firestore
    await _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .add({
      'roomId': roomId,
      'text': displayText,
      'imageUrl': fileUrl,
      'fileId': fileId,
      'type': 'image',
      'senderEmail': senderEmail.toLowerCase().trim(),
      'senderName': senderName.trim(),
      'senderRole': senderRole.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': null,
      'isRead': false,
      'readAt': null,
    });

    // 3. Simpan riwayat percakapan untuk kedua belah pihak & picu notifikasi FCM jika chat pribadi
    if (recipientEmail != null && recipientEmail.isNotEmpty) {
      final sEmail = senderEmail.toLowerCase().trim();
      final rEmail = recipientEmail.toLowerCase().trim();

      await _firestore
          .collection(directConversationsCollection)
          .doc(sEmail)
          .collection('peers')
          .doc(rEmail)
          .set({
        'peerEmail': rEmail,
        'peerName': recipientName ?? rEmail.split('@').first,
        'peerTag': recipientTag ?? 'Siswa',
        'lastMessage': displayText,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));

      await _firestore
          .collection(directConversationsCollection)
          .doc(rEmail)
          .collection('peers')
          .doc(sEmail)
          .set({
        'peerEmail': sEmail,
        'peerName': senderName,
        'peerTag': senderRole,
        'lastMessage': displayText,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _notifyRecipient(
        recipientEmail: rEmail,
        senderEmail: sEmail,
        senderName: senderName,
        senderRole: senderRole,
        messageText: displayText,
      );
    }
  }

  /// Mengirim push notifikasi FCM ke penerima pesan japri via Backend Server
  void _notifyRecipient({
    required String recipientEmail,
    required String senderEmail,
    required String senderName,
    required String senderRole,
    required String messageText,
  }) async {
    final cleanRecipient = recipientEmail.toLowerCase().trim();
    final payload = jsonEncode({
      'recipient_email': cleanRecipient,
      'to': cleanRecipient,
      'sender_email': senderEmail,
      'sender_name': senderName,
      'sender_tag': senderRole,
      'from': senderName,
      'message': messageText,
      'text': messageText,
      'subject': '💬 Pesan Japri dari $senderName [$senderRole]',
      'snippet': messageText,
      'route': '/chat',
      'peer_email': senderEmail,
      'peer_name': senderName,
      'peer_tag': senderRole,
    });

    // 1. Panggil API Chat Notify di Server Backend Express.js
    try {
      final backendUrl =
          Uri.parse('https://baknusmail.smkbn666.sch.id/api/chat/notify');
      final res = await http
          .post(
            backendUrl,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) return;
    } catch (_) {}

    // 2. Fallback ke endpoint webhook server jika diperlukan
    try {
      final webhookUrl =
          Uri.parse('https://baknusmail.smkbn666.sch.id/api/webhook/incoming-email');
      await http
          .post(
            webhookUrl,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Edit teks pesan (hanya pengirim yang berhak mengedit)
  Future<bool> editMessage({
    required String roomId,
    required String messageId,
    required String newText,
    required String userEmail,
  }) async {
    final cleanText = newText.trim();
    if (cleanText.isEmpty || roomId.isEmpty || messageId.isEmpty) return false;

    try {
      final docRef = _firestore
          .collection(roomsCollection)
          .doc(roomId)
          .collection('messages')
          .doc(messageId);
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data?['senderEmail']?.toString().toLowerCase() !=
          userEmail.toLowerCase().trim()) {
        return false;
      }

      final updateData = <String, dynamic>{
        'text': cleanText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      };

      // Ekstrak ulang Link Preview jika teks memuat URL
      final extractedUrl = LinkPreviewService.extractUrl(cleanText);
      if (extractedUrl != null && extractedUrl.isNotEmpty) {
        final previewData = await LinkPreviewService.fetchMetadata(extractedUrl);
        if (previewData != null) {
          updateData['linkUrl'] = previewData.url;
          updateData['linkTitle'] = previewData.title;
          updateData['linkDescription'] = previewData.description;
          if (previewData.imageUrl != null) {
            updateData['linkImageUrl'] = previewData.imageUrl;
          }
        } else {
          updateData['linkUrl'] = null;
          updateData['linkTitle'] = null;
          updateData['linkDescription'] = null;
          updateData['linkImageUrl'] = null;
        }
      } else {
        updateData['linkUrl'] = null;
        updateData['linkTitle'] = null;
        updateData['linkDescription'] = null;
        updateData['linkImageUrl'] = null;
      }

      await docRef.update(updateData);
      return true;
    } catch (e) {
      debugPrint('Error editing BaknusChat message: $e');
      return false;
    }
  }

  /// Hapus pesan obrolan (dapat dihapus oleh pengirim maupun penerima)
  Future<bool> deleteMessage(String roomId, String messageId, String userEmail) async {
    try {
      final docRef = _firestore
          .collection(roomsCollection)
          .doc(roomId)
          .collection('messages')
          .doc(messageId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting BaknusChat message: $e');
      return false;
    }
  }

  /// Hapus Percakapan Japri (1-on-1) beserta pesan-pesannya
  Future<bool> deleteDirectConversation({
    required String currentEmail,
    required String peerEmail,
  }) async {
    final cleanCurrent = currentEmail.toLowerCase().trim();
    final cleanPeer = peerEmail.toLowerCase().trim();
    if (cleanCurrent.isEmpty || cleanPeer.isEmpty) return false;

    try {
      await _firestore
          .collection(directConversationsCollection)
          .doc(cleanCurrent)
          .collection('peers')
          .doc(cleanPeer)
          .delete();

      final roomId = getPrivateRoomId(cleanCurrent, cleanPeer);
      final msgsSnap = await _firestore
          .collection(roomsCollection)
          .doc(roomId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in msgsSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return true;
    } catch (e) {
      debugPrint('Error deleting direct conversation: $e');
      return false;
    }
  }

  /// Hapus atau keluar dari Grup Obrolan
  Future<bool> deleteGroup({
    required String groupId,
    required String userEmail,
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (groupId.isEmpty || cleanEmail.isEmpty) return false;

    try {
      final docRef = _firestore.collection(customGroupsCollection).doc(groupId);
      final snap = await docRef.get();
      if (!snap.exists) return false;

      final data = snap.data();
      final creatorEmail = data?['creatorEmail']?.toString().toLowerCase().trim() ?? '';
      final List<dynamic> members = List<dynamic>.from(data?['members'] ?? []);

      if (creatorEmail == cleanEmail) {
        await docRef.delete();

        final msgsSnap = await _firestore
            .collection(roomsCollection)
            .doc(groupId)
            .collection('messages')
            .get();

        final batch = _firestore.batch();
        for (var doc in msgsSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } else {
        members.removeWhere((m) {
          if (m is Map) {
            return m['email']?.toString().toLowerCase().trim() == cleanEmail;
          }
          return m.toString().toLowerCase().trim() == cleanEmail;
        });
        await docRef.update({'members': members});
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting custom group: $e');
      return false;
    }
  }

  /// Hitung jumlah grup yang pernah dibuat oleh user ini (Admin)
  Future<int> getUserCreatedGroupsCount(String creatorEmail) async {
    final cleanEmail = creatorEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return 0;
    try {
      final snap = await _firestore
          .collection(customGroupsCollection)
          .where('creatorEmail', isEqualTo: cleanEmail)
          .get();
      return snap.docs.length;
    } catch (e) {
      debugPrint('Error getting user created groups count: $e');
      return 0;
    }
  }

  /// Buat Grup Obrolan baru dengan pembatasan maksimal 2 grup per user
  Future<CustomGroup> createCustomGroup({
    required String name,
    required String description,
    required String creatorEmail,
    required String creatorName,
    required String creatorTag,
    List<String>? initialMemberEmails,
    Map<String, String>? initialMemberNames,
    Map<String, String>? initialMemberTags,
  }) async {
    final cEmail = creatorEmail.toLowerCase().trim();
    final count = await getUserCreatedGroupsCount(cEmail);

    if (count >= 2) {
      throw Exception(
        'Batas Maksimal 2 Grup Tercapai!\n\nAnda telah membuat 2 grup obrolan (batas maksimal per pengguna). Silakan hapus salah satu grup buatan Anda jika ingin membuat grup baru.',
      );
    }

    final members = <String>{cEmail};
    final memberNames = <String, String>{cEmail: creatorName};
    final memberTags = <String, String>{cEmail: creatorTag};

    if (initialMemberEmails != null) {
      for (final email in initialMemberEmails) {
        final clean = email.toLowerCase().trim();
        if (clean.isNotEmpty) {
          members.add(clean);
          if (initialMemberNames != null && initialMemberNames.containsKey(clean)) {
            memberNames[clean] = initialMemberNames[clean]!;
          }
          if (initialMemberTags != null && initialMemberTags.containsKey(clean)) {
            memberTags[clean] = initialMemberTags[clean]!;
          }
        }
      }
    }

    final now = DateTime.now();
    final docRef = _firestore.collection(customGroupsCollection).doc();

    final groupData = {
      'name': name.trim(),
      'description': description.trim(),
      'creatorEmail': cEmail,
      'creatorName': creatorName.trim(),
      'members': members.toList(),
      'memberNames': memberNames,
      'memberTags': memberTags,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Grup obrolan dibuat oleh $creatorName',
      'lastTimestamp': FieldValue.serverTimestamp(),
    };

    await docRef.set(groupData);

    return CustomGroup(
      id: docRef.id,
      name: name.trim(),
      description: description.trim(),
      creatorEmail: cEmail,
      creatorName: creatorName.trim(),
      members: members.toList(),
      memberNames: memberNames,
      memberTags: memberTags,
      createdAt: now,
      lastMessage: 'Grup obrolan dibuat oleh $creatorName',
    );
  }

  /// Stream daftar grup obrolan di mana user menjadi anggota
  Stream<List<CustomGroup>> getUserGroupsStream(String userEmail) {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return Stream.value([]);

    return _firestore
        .collection(customGroupsCollection)
        .where('members', arrayContains: cleanEmail)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CustomGroup.fromFirestore(doc)).toList());
  }

  /// Tambah Anggota Baru ke Grup Obrolan
  Future<void> addMemberToGroup({
    required String groupId,
    required String memberEmail,
    required String memberName,
    required String memberTag,
  }) async {
    final cleanEmail = memberEmail.toLowerCase().trim();
    if (groupId.isEmpty || cleanEmail.isEmpty) return;

    final docRef = _firestore.collection(customGroupsCollection).doc(groupId);
    await docRef.update({
      'members': FieldValue.arrayUnion([cleanEmail]),
      'memberNames.$cleanEmail': memberName.trim(),
      'memberTags.$cleanEmail': memberTag.trim(),
    });
  }

  /// Keluarkan / Hapus Anggota dari Grup Obrolan
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String memberEmail,
  }) async {
    final cleanEmail = memberEmail.toLowerCase().trim();
    if (groupId.isEmpty || cleanEmail.isEmpty) return;

    final docRef = _firestore.collection(customGroupsCollection).doc(groupId);
    await docRef.update({
      'members': FieldValue.arrayRemove([cleanEmail]),
    });
  }



  /// Toggle Bintang (Star/Unstar) pada Pesan Obrolan
  Future<void> toggleStarMessage({
    required String roomId,
    required String messageId,
    required String userEmail,
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty || messageId.isEmpty || roomId.isEmpty) return;

    final docRef = _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .doc(messageId);

    try {
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      List<dynamic> starred = List<dynamic>.from(data['starredBy'] ?? []);

      if (starred.contains(cleanEmail)) {
        await docRef.update({
          'starredBy': FieldValue.arrayRemove([cleanEmail])
        });
      } else {
        await docRef.update({
          'starredBy': FieldValue.arrayUnion([cleanEmail])
        });
      }
    } catch (e) {
      debugPrint('Error toggling star on message $messageId: $e');
    }
  }

  /// Stream seluruh pesan yang diberi bintang oleh user tertentu
  Stream<List<ChatMessage>> getStarredMessagesStream(String userEmail) {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) return Stream.value([]);

    return _firestore
        .collectionGroup('messages')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .where((m) => m.isStarredBy(cleanEmail))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    }).handleError((e) {
      debugPrint('Error in getStarredMessagesStream: $e');
      return <ChatMessage>[];
    });
  }

  /// Stream seluruh berkas (dokumen & foto) tersimpan di cloud BaknusDrive / BaknusChat
  Stream<List<ChatMessage>> getUserDriveFilesStream(String userEmail) {
    return _firestore
        .collectionGroup('messages')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .where((m) {
            final hasFile = (m.isFile || m.isImage) && m.effectiveFileUrl.isNotEmpty;
            return hasFile;
          })
          .toList();
      // Hilangkan duplikat berdasarkan URL berkas
      final seenUrls = <String>{};
      final uniqueList = <ChatMessage>[];
      for (final msg in list) {
        final url = msg.effectiveFileUrl;
        if (!seenUrls.contains(url)) {
          seenUrls.add(url);
          uniqueList.add(msg);
        }
      }
      uniqueList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return uniqueList;
    });
  }

  /// Teruskan pesan obrolan ke banyak penerima (Kontak / Grup, Maksimal 5 Target)
  Future<void> forwardMessageToMultipleRecipients({
    required ChatMessage originalMessage,
    required List<Map<String, dynamic>> targetRecipients,
    required String senderEmail,
    required String senderName,
    required String senderRole,
  }) async {
    final cleanSender = senderEmail.toLowerCase().trim();
    final textToSend = originalMessage.text.startsWith('↪ Diteruskan')
        ? originalMessage.text
        : '↪ Diteruskan:\n${originalMessage.text}';

    for (final recipient in targetRecipients) {
      final bool isGroup = recipient['isGroup'] == true;
      final String roomId = recipient['roomId'] ?? '';
      final String? peerEmail = recipient['peerEmail'];
      final String? peerName = recipient['peerName'];
      final String? peerTag = recipient['peerTag'];

      if (roomId.isEmpty) continue;

      if (originalMessage.isFile) {
        await sendDocumentFileMessage(
          roomId: roomId,
          fileUrl: originalMessage.effectiveFileUrl,
          filename: originalMessage.fileName ?? 'Dokumen Diteruskan',
          fileSize: originalMessage.fileSize,
          mimeType: originalMessage.mimeType,
          senderEmail: cleanSender,
          senderName: senderName,
          senderRole: senderRole,
        );
      } else if (originalMessage.isSticker) {
        await sendStickerMessage(
          roomId: roomId,
          stickerUrl: originalMessage.effectiveFileUrl,
          stickerName: originalMessage.fileName ?? 'Stiker',
          senderEmail: cleanSender,
          senderName: senderName,
          senderRole: senderRole,
          recipientEmail: isGroup ? null : peerEmail,
          recipientName: isGroup ? null : peerName,
          recipientTag: isGroup ? null : peerTag,
        );
      } else {
        await sendMessage(
          roomId: roomId,
          text: textToSend,
          senderEmail: cleanSender,
          senderName: senderName,
          senderRole: senderRole,
          recipientEmail: isGroup ? null : peerEmail,
          recipientName: isGroup ? null : peerName,
          recipientTag: isGroup ? null : peerTag,
        );
      }
    }
  }
}
