class FormatHelper {
  static const List<String> _indonesianDays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  static const List<String> _indonesianShortDays = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min'
  ];

  static const List<String> _indonesianMonths = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  static const List<String> _indonesianShortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des'
  ];

  static String formatEmailDate(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (messageDate == today) {
      return '$hour:$minute';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Kemarin';
    } else if (now.difference(dateTime).inDays < 7) {
      return _indonesianShortDays[dateTime.weekday - 1];
    } else if (dateTime.year == now.year) {
      return '${dateTime.day} ${_indonesianShortMonths[dateTime.month - 1]}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year.toString().substring(2)}';
    }
  }

  static String formatFullDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final dayName = _indonesianDays[dateTime.weekday - 1];
    final monthName = _indonesianMonths[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$dayName, ${dateTime.day} $monthName ${dateTime.year} • $hour:$minute';
  }

  static String formatLastSeen(DateTime? dateTime) {
    if (dateTime == null) return 'Terakhir dilihat tidak diketahui';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (dateOnly == today) {
      return 'Terakhir dilihat hari ini pukul $hour:$minute';
    } else if (dateOnly == yesterday) {
      return 'Terakhir dilihat kemarin pukul $hour:$minute';
    } else if (now.difference(dateTime).inDays < 7) {
      final dayName = _indonesianDays[dateTime.weekday - 1];
      return 'Terakhir dilihat $dayName pukul $hour:$minute';
    } else {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      return 'Terakhir dilihat $day/$month/${dateTime.year} pukul $hour:$minute';
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  static String extractNameFromEmail(String email) {
    if (email.contains('<') && email.contains('>')) {
      final name = email.substring(0, email.indexOf('<')).trim();
      if (name.isNotEmpty) return name.replaceAll('"', '');
    }
    final atIndex = email.indexOf('@');
    if (atIndex != -1) {
      return email.substring(0, atIndex).replaceAll('.', ' ').capitalize();
    }
    return email;
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}
