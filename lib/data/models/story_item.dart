import 'package:cloud_firestore/cloud_firestore.dart';

class StoryViewerInfo {
  final String email;
  final String name;
  final String tag;
  final DateTime viewedAt;

  StoryViewerInfo({
    required this.email,
    required this.name,
    required this.tag,
    required this.viewedAt,
  });

  factory StoryViewerInfo.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return StoryViewerInfo(
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Pengguna',
      tag: map['tag']?.toString() ?? 'Siswa',
      viewedAt: parseDate(map['viewedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'tag': tag,
        'viewedAt': Timestamp.fromDate(viewedAt),
      };
}

class StoryItem {
  final String id;
  final String userEmail;
  final String userName;
  final String userTag;
  final String imageBase64;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<StoryViewerInfo> viewers;
  final List<String> targetAudience;
  final String type; // 'image' atau 'text'
  final String bgColor; // Hex code warna background untuk status tulisan
  final String? musicTitle;
  final String? artistName;
  final String? musicAudioUrl;
  final String? musicCoverUrl;

  StoryItem({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.userTag,
    required this.imageBase64,
    this.caption = '',
    required this.createdAt,
    required this.expiresAt,
    this.viewers = const [],
    this.targetAudience = const ['Semua'],
    this.type = 'image',
    this.bgColor = '#E11D48',
    this.musicTitle,
    this.artistName,
    this.musicAudioUrl,
    this.musicCoverUrl,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isTextStory => type == 'text';

  bool get isVideoStory =>
      type == 'video' ||
      imageBase64.toLowerCase().contains('.mp4') ||
      imageBase64.toLowerCase().contains('video') ||
      imageBase64.toLowerCase().startsWith('data:video');

  bool get hasMusic => musicAudioUrl != null && musicAudioUrl!.isNotEmpty;

  bool isViewedBy(String email) {
    final clean = email.toLowerCase().trim();
    return viewers.any((v) => v.email.toLowerCase().trim() == clean);
  }

  /// Mengecek apakah story ini dapat dilihat oleh pengguna tertentu berdasarkan email dan tag peran (Siswa/Guru/TU)
  bool isVisibleTo(String? email, String? roleTag) {
    final cleanEmail = (email ?? '').toLowerCase().trim();
    final cleanOwner = userEmail.toLowerCase().trim();
    
    // Pemilik story selalu bisa melihat story miliknya sendiri
    if (cleanEmail.isNotEmpty && cleanEmail == cleanOwner) {
      return true;
    }

    // Jika targetAudience kosong atau berisi 'Semua', story terbuka untuk publik civitas
    if (targetAudience.isEmpty || targetAudience.contains('Semua')) {
      return true;
    }

    // Jika tag pengguna cocok dengan salah satu audiens target yang diizinkan
    final tag = (roleTag ?? '').trim();
    if (tag.isNotEmpty && targetAudience.contains(tag)) {
      return true;
    }

    return false;
  }

  factory StoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final now = DateTime.now();
    final rawViewers = data['viewers'];
    List<StoryViewerInfo> viewersList = [];
    if (rawViewers is List) {
      viewersList = rawViewers
          .map((m) {
            if (m is Map<String, dynamic>) return StoryViewerInfo.fromMap(m);
            if (m is Map) return StoryViewerInfo.fromMap(Map<String, dynamic>.from(m));
            return null;
          })
          .whereType<StoryViewerInfo>()
          .toList();
    }

    final rawAudience = data['targetAudience'];
    List<String> audienceList = [];
    if (rawAudience is List) {
      audienceList = rawAudience.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (audienceList.isEmpty) {
      audienceList = const ['Semua'];
    }

    return StoryItem(
      id: doc.id,
      userEmail: data['userEmail']?.toString() ?? '',
      userName: data['userName']?.toString() ?? 'Pengguna',
      userTag: data['userTag']?.toString() ?? 'Siswa',
      imageBase64: data['imageBase64']?.toString() ?? '',
      caption: data['caption']?.toString() ?? '',
      createdAt: parseDate(data['createdAt'], now),
      expiresAt: parseDate(data['expiresAt'], now.add(const Duration(hours: 24))),
      viewers: viewersList,
      targetAudience: audienceList,
      type: data['type']?.toString() ?? 'image',
      bgColor: data['bgColor']?.toString() ?? '#E11D48',
      musicTitle: data['musicTitle']?.toString(),
      artistName: data['artistName']?.toString(),
      musicAudioUrl: data['musicAudioUrl']?.toString(),
      musicCoverUrl: data['musicCoverUrl']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userEmail': userEmail.toLowerCase().trim(),
        'userName': userName.trim(),
        'userTag': userTag.trim(),
        'imageBase64': imageBase64,
        'caption': caption.trim(),
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewers': viewers.map((v) => v.toMap()).toList(),
        'targetAudience': targetAudience,
        'type': type,
        'bgColor': bgColor,
        'musicTitle': musicTitle,
        'artistName': artistName,
        'musicAudioUrl': musicAudioUrl,
        'musicCoverUrl': musicCoverUrl,
      };
}
