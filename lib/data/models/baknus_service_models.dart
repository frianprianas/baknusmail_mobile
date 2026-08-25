class DetailKehadiran {
  final String waktuTap;
  final String? waktuMasuk;
  final String? waktuPulang;
  final String status;
  final String keterangan;
  final String? lat;
  final String? long;
  final bool isDinasLuar;
  final String? lokasiDinasLuar;
  final String? photoUrl;

  DetailKehadiran({
    required this.waktuTap,
    this.waktuMasuk,
    this.waktuPulang,
    required this.status,
    required this.keterangan,
    this.lat,
    this.long,
    this.isDinasLuar = false,
    this.lokasiDinasLuar,
    this.photoUrl,
  });

  factory DetailKehadiran.fromJson(Map<String, dynamic> json) {
    final tap = json['waktu_tap']?.toString() ??
        json['waktu_masuk']?.toString() ??
        json['jam_masuk']?.toString() ??
        '';
    final masuk = json['waktu_masuk']?.toString() ?? json['jam_masuk']?.toString();
    final pulang = json['waktu_pulang']?.toString() ?? json['jam_pulang']?.toString();
    final photo = json['photo_url']?.toString() ??
        json['foto_url']?.toString() ??
        json['photo']?.toString();

    return DetailKehadiran(
      waktuTap: tap,
      waktuMasuk: masuk,
      waktuPulang: pulang,
      status: json['status']?.toString() ?? 'Hadir',
      keterangan: json['keterangan']?.toString() ?? '',
      lat: json['lat']?.toString(),
      long: json['long']?.toString(),
      isDinasLuar: json['is_dinas_luar'] == 1 || json['is_dinas_luar'] == true,
      lokasiDinasLuar: json['lokasi_dinas_luar']?.toString(),
      photoUrl: photo,
    );
  }

  /// Helper getter untuk parsing DateTime dari waktuTap
  DateTime? get date {
    if (waktuTap.isEmpty) return null;
    try {
      final formatted = waktuTap.trim().replaceAll(' ', 'T');
      return DateTime.parse(formatted);
    } catch (_) {
      try {
        final clean = waktuTap.trim();
        final parts = clean.split(' ');
        final dParts = parts[0].split('-');
        if (dParts.length == 3) {
          final year = int.parse(dParts[0]);
          final month = int.parse(dParts[1]);
          final day = int.parse(dParts[2]);
          int hour = 0, minute = 0, second = 0;
          if (parts.length >= 2) {
            final tParts = parts[1].split(':');
            if (tParts.isNotEmpty) hour = int.parse(tParts[0]);
            if (tParts.length >= 2) minute = int.parse(tParts[1]);
            if (tParts.length >= 3) second = int.parse(tParts[2].split('.')[0]);
          }
          return DateTime(year, month, day, hour, minute, second);
        }
      } catch (_) {}
      return null;
    }
  }
}

class BaknusAttendData {
  final String email;
  final String name;
  final String role;
  final int totalKehadiranBulanIni;
  final List<DetailKehadiran> detailKehadiran;

  BaknusAttendData({
    required this.email,
    required this.name,
    required this.role,
    required this.totalKehadiranBulanIni,
    required this.detailKehadiran,
  });

  factory BaknusAttendData.fromJson(Map<String, dynamic> json) {
    final list = json['detail_kehadiran'] as List? ?? [];
    return BaknusAttendData(
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Siswa',
      totalKehadiranBulanIni:
          int.tryParse(json['total_kehadiran_bulan_ini']?.toString() ?? '0') ?? 0,
      detailKehadiran:
          list.map((item) => DetailKehadiran.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class LastActivityTalim {
  final String tipe;
  final String waktu;
  final Map<String, dynamic> detail;

  LastActivityTalim({
    required this.tipe,
    required this.waktu,
    required this.detail,
  });

  factory LastActivityTalim.fromJson(Map<String, dynamic> json) {
    return LastActivityTalim(
      tipe: json['tipe']?.toString() ?? '',
      waktu: json['waktu']?.toString() ?? '',
      detail: json['detail'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['detail'] as Map)
          : {},
    );
  }

  // Helper getters for specific fields from API
  String get surahNama =>
      detail['surah_nama']?.toString() ?? detail['surah']?.toString() ?? '';
  int? get surahNumber =>
      int.tryParse(detail['surah_number']?.toString() ?? '');
  int? get ayatNumber =>
      int.tryParse(detail['ayat_number']?.toString() ?? detail['ayat']?.toString() ?? '');
  int? get ayatStart =>
      int.tryParse(detail['ayat_start']?.toString() ?? '');
  int? get ayatEnd =>
      int.tryParse(detail['ayat_end']?.toString() ?? '');
  String? get status => detail['status']?.toString();
  String? get nilai => detail['nilai']?.toString();
  String? get catatan => detail['catatan']?.toString();

  // Praktek Ibadah
  String? get jenisIbadah =>
      detail['jenis_ibadah']?.toString() ?? detail['ibadah']?.toString();

  // Amalan Yaumi
  String? get shalatFardhu =>
      detail['shalat_fardhu']?.toString() ?? detail['fardhu']?.toString();
  String? get shalatSunnah =>
      detail['shalat_sunnah']?.toString() ?? detail['sunnah']?.toString();
  String? get puasa => detail['puasa']?.toString();

  // Formatted date
  String get formattedWaktu {
    if (waktu.isEmpty) return '';
    try {
      final dt = DateTime.parse(waktu).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$min';
    } catch (_) {
      return waktu;
    }
  }
}

class BaknusTalimData {
  final String email;
  final String name;
  final String role;
  final LastActivityTalim? lastActivity;

  BaknusTalimData({
    required this.email,
    required this.name,
    required this.role,
    this.lastActivity,
  });

  factory BaknusTalimData.fromJson(Map<String, dynamic> json) {
    final activityJson = json['last_activity'] as Map<String, dynamic>?;
    return BaknusTalimData(
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      lastActivity: activityJson != null
          ? LastActivityTalim.fromJson(activityJson)
          : null,
    );
  }
}

class StorageInfo {
  final int quotaBytes;
  final int usedBytes;
  final int availableBytes;
  final double percentageUsed;

  StorageInfo({
    required this.quotaBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.percentageUsed,
  });

  factory StorageInfo.fromJson(Map<String, dynamic> json) {
    final quota =
        int.tryParse(json['quota_bytes']?.toString() ?? '10737418240') ?? 10737418240;
    final used =
        int.tryParse(json['used_bytes']?.toString() ?? '0') ?? 0;
    final available =
        int.tryParse(json['available_bytes']?.toString() ?? '') ?? (quota - used);

    // Hitung persentase secara akurat dari byte terpakai / kuota
    double pct = 0.0;
    if (quota > 0) {
      pct = (used / quota).clamp(0.0, 1.0);
    } else if (json['percentage_used'] != null) {
      final raw = double.tryParse(json['percentage_used'].toString()) ?? 0.0;
      pct = raw > 1.0 ? (raw / 100.0).clamp(0.0, 1.0) : raw.clamp(0.0, 1.0);
    }

    return StorageInfo(
      quotaBytes: quota,
      usedBytes: used,
      availableBytes: available,
      percentageUsed: pct,
    );
  }

  double get ratio => percentageUsed.clamp(0.0, 1.0);
  double get percentValue => ratio * 100.0;
  String get percentString => '${percentValue.toStringAsFixed(2)}%';

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(count >= 10 || i == 0 ? 0 : 2)} ${suffixes[i]}';
  }
}

class BaknusDriveData {
  final String email;
  final String name;
  final String role;
  final String lastAccessed;
  final StorageInfo storage;

  BaknusDriveData({
    required this.email,
    required this.name,
    required this.role,
    required this.lastAccessed,
    required this.storage,
  });

  factory BaknusDriveData.fromJson(Map<String, dynamic> json) {
    final storageJson = json['storage'] as Map<String, dynamic>? ?? {};
    return BaknusDriveData(
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Guru',
      lastAccessed: json['last_accessed']?.toString() ?? '',
      storage: StorageInfo.fromJson(storageJson),
    );
  }
}

class BaknusDriveBackup {
  final String backupId;
  final String filename;
  final int fileSize;
  final String backupType;
  final int messageCount;
  final DateTime createdAt;
  final String downloadUrl;

  BaknusDriveBackup({
    required this.backupId,
    required this.filename,
    required this.fileSize,
    required this.backupType,
    required this.messageCount,
    required this.createdAt,
    required this.downloadUrl,
  });

  factory BaknusDriveBackup.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BaknusDriveBackup(
      backupId: json['backup_id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'backup.json',
      fileSize: int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      backupType: json['backup_type']?.toString() ?? 'auto',
      messageCount: int.tryParse(json['message_count']?.toString() ?? '0') ?? 0,
      createdAt: parseDate(json['created_at']),
      downloadUrl: json['download_url']?.toString() ?? '',
    );
  }

  int get fileSizeBytes => fileSize;

  Map<String, dynamic> toJson() {
    return {
      'backup_id': backupId,
      'filename': filename,
      'file_size': fileSize,
      'backup_type': backupType,
      'message_count': messageCount,
      'created_at': createdAt.toIso8601String(),
      'download_url': downloadUrl,
    };
  }

  String get formattedDate {
    final dt = createdAt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$min';
  }
}

