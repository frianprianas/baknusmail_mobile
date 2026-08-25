import 'package:flutter/material.dart';

class UserTagResolver {
  /// Ekstraksi TAG resmi: 'Guru', 'TU', atau 'Siswa'
  static String resolve({
    required String email,
    required String displayName,
    dynamic mailboxData, // Map<String, dynamic> dari API Mailcow jika ada
    String? fallbackRole,
  }) {
    final cleanEmail = email.toLowerCase().trim();
    final cleanName = displayName.toLowerCase().trim();
    final cleanRole = (fallbackRole ?? '').toLowerCase().trim();

    // 1. Jika fallbackRole sudah bernilai 'Guru' atau 'TU', prioritaskan
    if (cleanRole == 'guru') return 'Guru';
    if (cleanRole == 'tu') return 'TU';

    // 2. Cek langsung dari field 'tags' / 'tag' / 'comment' / 'description' / 'name' pada data Mailcow API
    if (mailboxData is Map<String, dynamic>) {
      final tagsRaw = mailboxData['tags'] ?? mailboxData['tag'] ?? mailboxData['tags_array'];
      final tagsString = _flattenTagsToString(tagsRaw).toLowerCase();

      if (_matchesGuruPattern(tagsString)) return 'Guru';
      if (_matchesTUPattern(tagsString)) return 'TU';
      if (tagsString.contains('siswa') || tagsString.contains('student') || tagsString.contains('murid')) {
        return 'Siswa';
      }

      final comment = (mailboxData['comment'] ?? mailboxData['description'] ?? mailboxData['name'] ?? '').toString().toLowerCase();
      if (_matchesGuruPattern(comment)) return 'Guru';
      if (_matchesTUPattern(comment)) return 'TU';
      if (comment.contains('siswa') || comment.contains('student') || comment.contains('murid')) {
        return 'Siswa';
      }
    }

    // 3. Cek dari role yang dikembalikan oleh layanan terintegrasi Baknus (Attend / Drive / Talim)
    if (_matchesGuruPattern(cleanRole)) return 'Guru';
    if (_matchesTUPattern(cleanRole)) return 'TU';
    if (cleanRole.contains('siswa') || cleanRole.contains('murid') || cleanRole.contains('santri')) {
      return 'Siswa';
    }

    // 4. Cek dari email atau display name apakah ada indikasi Guru / TU
    if (_matchesGuruPattern(cleanEmail) || _matchesGuruPattern(cleanName)) return 'Guru';
    if (_matchesTUPattern(cleanEmail) || _matchesTUPattern(cleanName)) return 'TU';

    // 5. Cek apakah format email berupa NIS/NISN siswa (mengandung 4+ angka berurutan, misal: 212210045@...)
    final hasNisPattern = RegExp(r'\d{4,}').hasMatch(cleanEmail);
    if (hasNisPattern) {
      return 'Siswa';
    }

    // 6. Jika email TIDAK mengandung angka NIS 4+ berurutan (misal: budi@smkbn666.sch.id, yhan@...),
    // maka akun tersebut adalah Guru / Tenaga Pendidik.
    return 'Guru';
  }

  static bool _matchesGuruPattern(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();

    // Kata kunci utama
    if (lower.contains('guru') ||
        lower.contains('teacher') ||
        lower.contains('pengajar') ||
        lower.contains('pendidik') ||
        lower.contains('tenaga pendidik') ||
        lower.contains('wali kelas') ||
        lower.contains('kaprog') ||
        lower.contains('kajur') ||
        lower.contains('waka') ||
        lower.contains('kepala sekolah')) {
      return true;
    }

    // Sapaan / Panggilan
    if (lower.contains('bpk') ||
        lower.contains('bapak') ||
        lower.contains('ibu ') ||
        lower.startsWith('ibu') ||
        lower.contains('ustadz') ||
        lower.contains('ustazah') ||
        lower.contains('ust.')) {
      return true;
    }

    // Gelar akademik Indonesia
    final academicTitles = [
      's.pd',
      'm.pd',
      's.kom',
      'm.kom',
      's.t',
      'm.t',
      's.si',
      'm.si',
      's.ag',
      'm.ag',
      's.e',
      'm.m',
      's.sos',
      'drs',
      'dra',
      'dr.',
      'lc.',
      'gr.',
      'spd',
      'mpd',
      'skom',
      'mkom',
      'st',
      'mt',
    ];

    for (final title in academicTitles) {
      if (lower.contains(title)) return true;
    }

    return false;
  }

  static bool _matchesTUPattern(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();

    if (lower == 'tu' ||
        lower.contains('tu ') ||
        lower.contains(' tu') ||
        lower.contains('tata usaha') ||
        lower.contains('tatausaha') ||
        lower.contains('staff') ||
        lower.contains('staf') ||
        lower.contains('kepegawaian') ||
        lower.contains('administrasi') ||
        lower.contains('admin') ||
        lower.contains('operator') ||
        lower.contains('sarpras') ||
        lower.contains('keuangan') ||
        lower.contains('bendahara')) {
      return true;
    }
    return false;
  }

  static String _flattenTagsToString(dynamic tagsRaw) {
    if (tagsRaw == null) return '';
    if (tagsRaw is List) {
      return tagsRaw.map((e) {
        if (e is Map) return e.values.join(' ');
        return e.toString();
      }).join(' ');
    }
    if (tagsRaw is Map) {
      return tagsRaw.values.join(' ');
    }
    return tagsRaw.toString();
  }

  static Color getTagColor(String tag) {
    switch (tag) {
      case 'Guru':
        return const Color(0xFFD97706); // Amber / Gold
      case 'TU':
        return const Color(0xFF7C3AED); // Purple / Violet
      case 'Siswa':
      default:
        return const Color(0xFF059669); // Emerald / Green
    }
  }

  static IconData getTagIcon(String tag) {
    switch (tag) {
      case 'Guru':
        return Icons.school_rounded;
      case 'TU':
        return Icons.badge_rounded;
      case 'Siswa':
      default:
        return Icons.person_rounded;
    }
  }
}
