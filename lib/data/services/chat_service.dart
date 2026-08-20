import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class DirectConversationItem {
  final String peerEmail;
  final String peerName;
  final String peerTag;
  final String lastMessage;
  final DateTime lastTimestamp;
  final int unreadCount;

  DirectConversationItem({
    required this.peerEmail,
    required this.peerName,
    required this.peerTag,
    required this.lastMessage,
    required this.lastTimestamp,
    this.unreadCount = 0,
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
    );
  }

  Map<String, dynamic> toMap() => {
        'peerEmail': peerEmail,
        'peerName': peerName,
        'peerTag': peerTag,
        'lastMessage': lastMessage,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': unreadCount,
      };
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String roomsCollection = 'baknus_chat_rooms';
  static const String directConversationsCollection = 'baknus_chat_direct_conversations';

  /// Formula deterministik Room ID untuk Chat Pribadi (Japri) antara 2 email
  static String getPrivateRoomId(String email1, String email2) {
    final e1 = email1.toLowerCase().trim();
    final e2 = email2.toLowerCase().trim();
    final list = [e1, e2]..sort();
    final sanitized = '${list[0]}___${list[1]}'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'dm_$sanitized';
  }

  /// Stream pesan real-time berdasarkan roomId (Grup maupun Japri)
  Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    return _firestore
        .collection(roomsCollection)
        .doc(roomId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final threshold = now.subtract(const Duration(hours: 24));

      final list = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .where((msg) => msg.timestamp.isAfter(threshold) && !msg.isExpired)
          .toList();

      // Urutkan berdasarkan waktu secara in-memory (0 error FAILED_PRECONDITION)
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
      list.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
      return list;
    });
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
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    try {
      // 1. Simpan pesan ke subcollection room dengan status awal isRead = false
      await _firestore
          .collection(roomsCollection)
          .doc(roomId)
          .collection('messages')
          .add({
        'roomId': roomId,
        'text': cleanText,
        'senderEmail': senderEmail.toLowerCase().trim(),
        'senderName': senderName.trim(),
        'senderRole': senderRole.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isRead': false,
        'readAt': null,
      });

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

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

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
      'expiresAt': Timestamp.fromDate(expiresAt),
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

  /// Kirim pesan gambar ke room chat dengan unggah ke BaknusDrive dan notifikasi FCM
  Future<void> sendImageMessage({
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

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

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
      'expiresAt': Timestamp.fromDate(expiresAt),
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

  /// Hapus pesan (hanya pengirim yang bisa menghapus)
  Future<bool> deleteMessage(String roomId, String messageId, String userEmail) async {
    try {
      final docRef = _firestore
          .collection(roomsCollection)
          .doc(roomId)
          .collection('messages')
          .doc(messageId);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data?['senderEmail']?.toString().toLowerCase() ==
            userEmail.toLowerCase()) {
          await docRef.delete();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting BaknusChat message: $e');
      return false;
    }
  }
}
