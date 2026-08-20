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
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? fileId;
  final String type; // 'text' | 'image' | 'file' | 'document' | 'archive'

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
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
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
    final fUrl = data['fileUrl']?.toString() ?? imgUrl;
    final fName = data['fileName']?.toString();
    final fSize = data['fileSize'] is num ? (data['fileSize'] as num).toInt() : null;
    final mType = data['mimeType']?.toString();
    final fId = data['fileId'] is num ? (data['fileId'] as num).toInt() : null;
    
    String msgType = data['type']?.toString() ?? 'text';
    if (msgType == 'text') {
      if (fUrl != null && fUrl.isNotEmpty) {
        msgType = (imgUrl != null && imgUrl.isNotEmpty && (fName == null || _isImageFileName(fName)))
            ? 'image'
            : 'file';
      }
    }

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
      fileUrl: fUrl,
      fileName: fName,
      fileSize: fSize,
      mimeType: mType,
      fileId: fId,
      type: msgType,
    );
  }

  static bool _isImageFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
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
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'fileId': fileId,
      'type': type,
    };
  }

  String get effectiveFileUrl => fileUrl ?? imageUrl ?? '';

  bool get isImage =>
      type == 'image' ||
      (imageUrl != null && imageUrl!.isNotEmpty && (type == 'image' || type == 'text'));

  bool get isFile =>
      type == 'file' ||
      type == 'document' ||
      type == 'archive' ||
      (fileUrl != null && fileUrl!.isNotEmpty && type != 'image');

  bool get isArchive {
    if (type == 'archive') return true;
    final name = (fileName ?? text).toLowerCase();
    return name.endsWith('.zip') ||
        name.endsWith('.rar') ||
        name.endsWith('.7z') ||
        name.endsWith('.tar') ||
        name.endsWith('.gz');
  }

  String get formattedFileSize {
    if (fileSize == null || fileSize! <= 0) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    if (fileSize! < 1024 * 1024 * 1024) return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

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
