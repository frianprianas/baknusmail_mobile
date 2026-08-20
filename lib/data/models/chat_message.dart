import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderEmail;
  final String senderName;
  final String senderRole; // Tag: 'Guru', 'TU', 'Siswa'
  final String text;
  final DateTime timestamp;
  final DateTime expiresAt;
  final String roomId;
  final bool isRead;
  final DateTime? readAt;
  final bool isPending;
  final String? imageUrl;
  final int? fileId;
  final String type; // 'text' | 'image'

  ChatMessage({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    required this.expiresAt,
    required this.roomId,
    this.isRead = false,
    this.readAt,
    this.isPending = false,
    this.imageUrl,
    this.fileId,
    this.type = 'text',
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = parseDate(data['timestamp']);
    final expireTime = data['expiresAt'] != null
        ? parseDate(data['expiresAt'])
        : createdAt.add(const Duration(hours: 24));

    final isReadVal = data['isRead'] == true;
    final readTime = data['readAt'] != null ? parseDate(data['readAt']) : null;
    final imgUrl = data['imageUrl']?.toString();
    final fId = data['fileId'] is num ? (data['fileId'] as num).toInt() : null;
    final msgType = data['type']?.toString() ?? (imgUrl != null && imgUrl.isNotEmpty ? 'image' : 'text');

    return ChatMessage(
      id: doc.id,
      senderEmail: data['senderEmail']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'Pengguna',
      senderRole: data['senderRole']?.toString() ?? 'Siswa',
      text: data['text']?.toString() ?? '',
      timestamp: createdAt,
      expiresAt: expireTime,
      roomId: data['roomId']?.toString() ?? 'publik',
      isRead: isReadVal,
      readAt: readTime,
      isPending: false,
      imageUrl: imgUrl,
      fileId: fId,
      type: msgType,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderEmail': senderEmail,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'roomId': roomId,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'imageUrl': imageUrl,
      'fileId': fileId,
      'type': type,
    };
  }

  bool get isImage => type == 'image' || (imageUrl != null && imageUrl!.isNotEmpty);

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  String get remainingTimeFormatted {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Kedaluwarsa';
    if (diff.inHours > 0) {
      return '${diff.inHours}j ${diff.inMinutes % 60}m';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    }
    return '${diff.inSeconds}d';
  }

  String get timeFormatted {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool get isSenderGuru {
    final lower = senderRole.toLowerCase();
    return lower == 'guru' ||
        lower.contains('guru') ||
        lower.contains('pengajar') ||
        lower.contains('pendidik') ||
        senderEmail.toLowerCase().contains('guru');
  }

  bool get isSenderTU {
    final lower = senderRole.toLowerCase();
    return lower == 'tu' ||
        lower.contains('tata usaha') ||
        lower.contains('staff') ||
        lower.contains('admin') ||
        senderEmail.toLowerCase().contains('tu');
  }

  bool get isSenderSiswa {
    return !isSenderGuru && !isSenderTU;
  }
}
