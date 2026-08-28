import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderEmail;
  final String senderName;
  final String senderRole; // Tag: 'Guru', 'TU', 'Siswa'
  final String text;
  final DateTime timestamp;
  final DateTime? expiresAt;
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
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToText;
  final Map<String, List<String>>? reactions;
  final bool isPinned;
  final int? audioDuration;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;
  final String? linkUrl;
  final bool isEdited;
  final DateTime? editedAt;
  final List<String> starredBy;

  ChatMessage({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    this.expiresAt,
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
    this.replyToId,
    this.replyToSenderName,
    this.replyToText,
    this.reactions,
    this.isPinned = false,
    this.audioDuration,
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
    this.linkUrl,
    this.isEdited = false,
    this.editedAt,
    this.starredBy = const [],
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
        : null;

    final isReadVal = data['isRead'] == true;
    final readTime = data['readAt'] != null ? parseDate(data['readAt']) : null;
    final imgUrl = data['imageUrl']?.toString();
    final fUrl = data['fileUrl']?.toString() ?? imgUrl;
    final fName = data['fileName']?.toString();
    final fSize = data['fileSize'] is num ? (data['fileSize'] as num).toInt() : null;
    final mType = data['mimeType']?.toString();
    final fId = data['fileId'] is num ? (data['fileId'] as num).toInt() : null;
    
    final repId = data['replyToId']?.toString();
    final repName = data['replyToSenderName']?.toString();
    final repText = data['replyToText']?.toString();
    final pinned = data['isPinned'] == true;
    final aDur = data['audioDuration'] is num ? (data['audioDuration'] as num).toInt() : null;
    final lTitle = data['linkTitle']?.toString();
    final lDesc = data['linkDescription']?.toString();
    final lImg = data['linkImageUrl']?.toString();
    final lUrl = data['linkUrl']?.toString();
    final editedVal = data['isEdited'] == true;
    final editedTime = data['editedAt'] != null ? parseDate(data['editedAt']) : null;

    Map<String, List<String>>? reactMap;
    if (data['reactions'] is Map) {
      reactMap = {};
      (data['reactions'] as Map).forEach((k, v) {
        if (v is List) {
          reactMap![k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    List<String> starredList = [];
    if (data['starredBy'] is List) {
      starredList = (data['starredBy'] as List).map((e) => e.toString().toLowerCase().trim()).toList();
    }

    String msgType = data['messageType']?.toString() ?? data['type']?.toString() ?? 'text';
    if (msgType == 'text') {
      if (fUrl != null && fUrl.isNotEmpty) {
        msgType = (imgUrl != null && imgUrl.isNotEmpty && (fName == null || _isImageFileName(fName)))
            ? 'image'
            : 'file';
      }
    }

    String? rId = data['roomId']?.toString();
    if (rId == null || rId.isEmpty) {
      rId = doc.reference.parent.parent?.id;
    }
    final finalRoomId = (rId != null && rId.isNotEmpty) ? rId : 'publik';

    return ChatMessage(
      id: doc.id,
      senderEmail: data['senderEmail']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'Pengguna',
      senderRole: data['senderRole']?.toString() ?? 'Siswa',
      text: data['text']?.toString() ?? '',
      timestamp: createdAt,
      expiresAt: expireTime,
      roomId: finalRoomId,
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
      replyToId: repId,
      replyToSenderName: repName,
      replyToText: repText,
      reactions: reactMap,
      isPinned: pinned,
      audioDuration: aDur,
      linkTitle: lTitle,
      linkDescription: lDesc,
      linkImageUrl: lImg,
      linkUrl: lUrl,
      isEdited: editedVal,
      editedAt: editedTime,
      starredBy: starredList,
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
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
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
      'replyToId': replyToId,
      'replyToSenderName': replyToSenderName,
      'replyToText': replyToText,
      'reactions': reactions,
      'isPinned': isPinned,
      'audioDuration': audioDuration,
      'linkTitle': linkTitle,
      'linkDescription': linkDescription,
      'linkImageUrl': linkImageUrl,
      'linkUrl': linkUrl,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'starredBy': starredBy,
    };
  }

  bool get isAudio =>
      type == 'audio' ||
      (fileUrl != null &&
          (fileUrl!.endsWith('.m4a') ||
              fileUrl!.endsWith('.aac') ||
              fileUrl!.endsWith('.mp3') ||
              fileUrl!.endsWith('.wav')));

  bool get hasLinkPreview =>
      linkUrl != null && linkUrl!.isNotEmpty && linkTitle != null && linkTitle!.isNotEmpty;

  String get effectiveFileUrl => fileUrl ?? imageUrl ?? '';

  bool get isSticker => type == 'sticker' || text.startsWith('🏷️ Stiker:');

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
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool isStarredBy(String userEmail) {
    final clean = userEmail.toLowerCase().trim();
    return clean.isNotEmpty && starredBy.contains(clean);
  }

  String get remainingTimeFormatted {
    if (expiresAt == null) return '';
    final diff = expiresAt!.difference(DateTime.now());
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
