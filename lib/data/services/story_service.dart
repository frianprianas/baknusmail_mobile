import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/story_item.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String storiesCollection = 'baknus_stories';

  /// Stream semua story aktif (belum kedaluwarsa 24 jam) yang dapat dilihat oleh user tertentu
  Stream<List<StoryItem>> getStoriesStream({String? currentUserEmail, String? currentUserTag}) {
    final now = DateTime.now();

    return _firestore.collection(storiesCollection).snapshots().map((snapshot) {
      final stories = snapshot.docs
          .map((doc) => StoryItem.fromFirestore(doc))
          .where((story) => story.expiresAt.isAfter(now) && !story.isExpired)
          .where((story) => story.isVisibleTo(currentUserEmail, currentUserTag))
          .toList();

      // Urutkan story terbaru di depan
      stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return stories;
    });
  }

  /// Membuat & mengunggah Story Baru (Foto, Video, atau Status Tulisan)
  Future<void> createStory({
    required String userEmail,
    required String userName,
    required String userTag,
    Uint8List? imageBytes,
    Uint8List? mediaBytes,
    String? mediaUrl,
    String caption = '',
    List<String> targetAudience = const ['Semua'],
    String type = 'image',
    String bgColor = '#E11D48',
    String? musicTitle,
    String? artistName,
    String? musicAudioUrl,
    String? musicCoverUrl,
  }) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    if (cleanEmail.isEmpty) {
      throw Exception('Data email tidak valid.');
    }

    final bytes = mediaBytes ?? imageBytes;
    if (type == 'image' && (mediaUrl == null || mediaUrl.isEmpty) && (bytes == null || bytes.isEmpty)) {
      throw Exception('Data gambar tidak valid.');
    }

    if (type == 'video' && (mediaUrl == null || mediaUrl.isEmpty) && (bytes == null || bytes.isEmpty)) {
      throw Exception('Data video tidak valid.');
    }

    if (type == 'text' && caption.trim().isEmpty) {
      throw Exception('Teks status tidak boleh kosong.');
    }

    final now = DateTime.now();

    // Periksa jumlah story aktif milik user (maksimal 3 story)
    final existingDocs = await _firestore
        .collection(storiesCollection)
        .where('userEmail', isEqualTo: cleanEmail)
        .get();

    final activeStories = existingDocs.docs
        .map((doc) => StoryItem.fromFirestore(doc))
        .where((story) => story.expiresAt.isAfter(now) && !story.isExpired)
        .toList();

    if (activeStories.length >= 3) {
      throw Exception('Batas maksimal 3 story telah tercapai. Hapus story lama untuk membuat story baru.');
    }

    final expiresAt = now.add(const Duration(hours: 24));

    // Jika mediaUrl (URL BaknusDrive) tersedia, gunakan URL BaknusDrive (0% beban Firestore limit 1MB)
    String mediaPathString = mediaUrl ?? '';
    if (mediaPathString.isEmpty && bytes != null && bytes.isNotEmpty) {
      if (type == 'video') {
        mediaPathString = 'data:video/mp4;base64,${base64Encode(bytes)}';
      } else if (type == 'image') {
        mediaPathString = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    }

    await _firestore.collection(storiesCollection).add({
      'userEmail': cleanEmail,
      'userName': userName.trim(),
      'userTag': userTag.trim(),
      'imageBase64': mediaPathString,
      'caption': caption.trim(),
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewers': [],
      'targetAudience': targetAudience.isEmpty ? ['Semua'] : targetAudience,
      'type': type,
      'bgColor': bgColor,
      'musicTitle': musicTitle,
      'artistName': artistName,
      'musicAudioUrl': musicAudioUrl,
      'musicCoverUrl': musicCoverUrl,
    });
  }

  /// Menandai story telah dilihat oleh pengguna tertentu (Viewers List Tracking)
  Future<void> markStoryAsViewed({
    required String storyId,
    required String viewerEmail,
    required String viewerName,
    required String viewerTag,
  }) async {
    final cleanViewer = viewerEmail.toLowerCase().trim();
    if (storyId.isEmpty || cleanViewer.isEmpty) return;

    try {
      final docRef = _firestore.collection(storiesCollection).doc(storyId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final story = StoryItem.fromFirestore(doc);

      // Jika pengguna adalah pemilik story, tidak perlu masuk daftar penonton
      if (story.userEmail.toLowerCase().trim() == cleanViewer) return;

      // Jika sudah pernah melihat, tidak perlu update ulang
      if (story.isViewedBy(cleanViewer)) return;

      final newViewer = StoryViewerInfo(
        email: cleanViewer,
        name: viewerName.trim(),
        tag: viewerTag.trim(),
        viewedAt: DateTime.now(),
      );

      final updatedViewers = List<Map<String, dynamic>>.from(
        story.viewers.map((v) => v.toMap()),
      )..add(newViewer.toMap());

      await docRef.update({
        'viewers': updatedViewers,
      });
    } catch (e) {
      debugPrint('Error marking story as viewed: $e');
    }
  }

  /// Menghapus story (hanya pemilik story yang diizinkan)
  Future<bool> deleteStory(String storyId, String userEmail) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    try {
      final docRef = _firestore.collection(storiesCollection).doc(storyId);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data?['userEmail']?.toString().toLowerCase().trim() == cleanEmail) {
          await docRef.delete();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting story: $e');
      return false;
    }
  }
}
