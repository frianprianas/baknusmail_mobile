import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/baknus_service_models.dart';
import '../../data/services/attendance_service.dart';

class _MergedDayAttendance {
  final String status;
  final Color statusColor;
  final String jamMasuk;
  final String jamPulang;
  final String keterangan;
  final String? lokasiDinasLuar;
  final String? latMasuk;
  final String? longMasuk;
  final String? latPulang;
  final String? longPulang;
  final String? photoUrlMasuk;
  final String? photoUrlPulang;

  _MergedDayAttendance({
    required this.status,
    required this.statusColor,
    required this.jamMasuk,
    required this.jamPulang,
    required this.keterangan,
    this.lokasiDinasLuar,
    this.latMasuk,
    this.longMasuk,
    this.latPulang,
    this.longPulang,
    this.photoUrlMasuk,
    this.photoUrlPulang,
  });
}

class AttendanceCalendarWidget extends StatefulWidget {
  final String userEmail;
  final BaknusAttendData? initialData;
  final Function(BaknusAttendData newData)? onDataUpdated;

  const AttendanceCalendarWidget({
    super.key,
    required this.userEmail,
    this.initialData,
    this.onDataUpdated,
  });

  @override
  State<AttendanceCalendarWidget> createState() => _AttendanceCalendarWidgetState();
}

class _AttendanceCalendarWidgetState extends State<AttendanceCalendarWidget> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  BaknusAttendData? _currentData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _currentData = widget.initialData;

    // Load initial data if not provided or to ensure month sync
    if (_currentData == null && widget.userEmail.isNotEmpty) {
      _loadAttendanceData(_focusedDay.month, _focusedDay.year);
    }
  }

  @override
  void didUpdateWidget(covariant AttendanceCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData && widget.initialData != null) {
      setState(() {
        _currentData = widget.initialData;
      });
    }
  }

  Future<void> _loadAttendanceData(int month, int year) async {
    if (widget.userEmail.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final newData = await AttendanceService.getUserAttendanceModel(
        email: widget.userEmail,
        month: month,
        year: year,
      );
      if (mounted) {
        setState(() {
          if (newData != null) {
            _currentData = newData;
            widget.onDataUpdated?.call(newData);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Warna penanda (Marker Dot Color) berdasarkan aturan:
  /// 🟢 Hijau (#22C55E): Hadir
  /// 🟡 Kuning/Oranye (#EAB308): Terlambat / Dinas Luar
  /// 🔵 Biru (#3B82F6): Izin / Sakit
  /// 🔴 Merah (#EF4444): Alpa
  Color _getStatusColor(DetailKehadiran item) {
    final s = item.status.toLowerCase().trim();
    if (item.isDinasLuar || s.contains('dinas')) {
      return const Color(0xFFEAB308); // 🟡 Yellow/Orange
    }
    if (s.contains('terlambat') || s.contains('late')) {
      return const Color(0xFFEAB308); // 🟡 Yellow/Orange
    }
    if (s.contains('hadir') || s.contains('present')) {
      return const Color(0xFF22C55E); // 🟢 Green
    }
    if (s.contains('izin') || s.contains('sakit') || s.contains('permission') || s.contains('sick')) {
      return const Color(0xFF3B82F6); // 🔵 Blue
    }
    if (s.contains('alpa') || s.contains('absent') || s.contains('alpha')) {
      return const Color(0xFFEF4444); // 🔴 Red
    }
    return const Color(0xFF22C55E);
  }

  String _formatTimeOnly(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '-';
    if (clean.contains(' ')) {
      final parts = clean.split(' ');
      if (parts.length >= 2) {
        final t = parts[1];
        return t.length >= 5 ? '${t.substring(0, 5)} WIB' : t;
      }
    }
    if (clean.contains(':')) {
      return clean.length >= 5 ? '${clean.substring(0, 5)} WIB' : clean;
    }
    return clean;
  }

  List<DetailKehadiran> _getEventsForDay(DateTime day) {
    if (_currentData == null) return [];
    return _currentData!.detailKehadiran.where((d) {
      final dDate = d.date;
      if (dDate == null) return false;
      return isSameDay(dDate, day);
    }).toList();
  }

  String _formatIndonesianDate(DateTime date) {
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = dayNames[date.weekday - 1];
    final monthName = monthNames[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  _MergedDayAttendance? _mergeDayEvents(List<DetailKehadiran> events) {
    if (events.isEmpty) return null;

    final primaryItem = events.firstWhere(
      (e) => e.status.toLowerCase().contains('terlambat') || e.isDinasLuar,
      orElse: () => events.first,
    );
    final status = primaryItem.status;
    final statusColor = _getStatusColor(primaryItem);

    String jamMasuk = '-';
    String jamPulang = '-';
    String? latMasuk;
    String? longMasuk;
    String? latPulang;
    String? longPulang;
    String? photoUrlMasuk;
    String? photoUrlPulang;

    DetailKehadiran? masukItem;
    DetailKehadiran? pulangItem;

    for (final item in events) {
      final ket = item.keterangan.toLowerCase();
      if (item.waktuMasuk != null && item.waktuMasuk!.isNotEmpty) {
        jamMasuk = _formatTimeOnly(item.waktuMasuk!);
        if (item.lat != null && item.lat!.isNotEmpty) {
          latMasuk = item.lat;
          longMasuk = item.long;
        }
        if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
          photoUrlMasuk = item.photoUrl;
        }
      }
      if (item.waktuPulang != null && item.waktuPulang!.isNotEmpty) {
        jamPulang = _formatTimeOnly(item.waktuPulang!);
        if (item.lat != null && item.lat!.isNotEmpty) {
          latPulang = item.lat;
          longPulang = item.long;
        }
        if (item.photoUrl != null && item.photoUrl!.isNotEmpty) {
          photoUrlPulang = item.photoUrl;
        }
      }

      if (ket.contains('masuk')) {
        masukItem = item;
      } else if (ket.contains('pulang')) {
        pulangItem = item;
      }
    }

    if (masukItem == null && events.isNotEmpty) {
      masukItem = events.first;
    }
    if (pulangItem == null && events.length > 1) {
      pulangItem = events.last;
    }

    if (jamMasuk == '-' && masukItem != null) {
      jamMasuk = _formatTimeOnly(masukItem.waktuTap);
    }
    if (latMasuk == null && masukItem != null) {
      latMasuk = masukItem.lat;
      longMasuk = masukItem.long;
    }
    if (photoUrlMasuk == null && masukItem != null && masukItem.photoUrl != null && masukItem.photoUrl!.isNotEmpty) {
      photoUrlMasuk = masukItem.photoUrl;
    }

    if (jamPulang == '-' && pulangItem != null && pulangItem != masukItem) {
      jamPulang = _formatTimeOnly(pulangItem.waktuTap);
    }
    if (latPulang == null && pulangItem != null && pulangItem != masukItem) {
      latPulang = pulangItem.lat;
      longPulang = pulangItem.long;
    }
    if (photoUrlPulang == null && pulangItem != null && pulangItem != masukItem && pulangItem.photoUrl != null && pulangItem.photoUrl!.isNotEmpty) {
      photoUrlPulang = pulangItem.photoUrl;
    }

    final ketList = <String>[];
    for (final e in events) {
      if (e.keterangan.isNotEmpty && !ketList.contains(e.keterangan)) {
        ketList.add(e.keterangan);
      }
    }

    final dinas = events.firstWhere(
      (e) => e.lokasiDinasLuar != null && e.lokasiDinasLuar!.isNotEmpty,
      orElse: () => primaryItem,
    ).lokasiDinasLuar;

    return _MergedDayAttendance(
      status: status,
      statusColor: statusColor,
      jamMasuk: jamMasuk,
      jamPulang: jamPulang,
      keterangan: ketList.join(' • '),
      lokasiDinasLuar: dinas,
      latMasuk: latMasuk,
      longMasuk: longMasuk,
      latPulang: latPulang,
      longPulang: longPulang,
      photoUrlMasuk: photoUrlMasuk,
      photoUrlPulang: photoUrlPulang,
    );
  }

  void _showDetailBottomSheet(DateTime selectedDay, List<DetailKehadiran> events) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = _formatIndonesianDate(selectedDay);
    final mergedData = _mergeDayEvents(events);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar Modal
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Tanggal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Kehadiran Harian',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Isi Kartu Tunggal Berdasarkan Tanggal Terpilih
              if (mergedData == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 40,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tidak ada catatan presensi pada tanggal ini.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                _buildUnifiedAttendanceCard(mergedData, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnifiedAttendanceCard(_MergedDayAttendance data, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: data.statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Badge & Tercatat Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: data.statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: data.statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          data.status,
                          style: TextStyle(
                            color: data.statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Tercatat',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Kartu Jam Masuk & Jam Pulang (Disatukan Rapi Tanpa Overflow)
          Row(
            children: [
              // Jam Masuk Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 15,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Jam Masuk',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.jamMasuk,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Jam Pulang Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: data.jamPulang != '-'
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: data.jamPulang != '-'
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 15,
                            color: data.jamPulang != '-' ? const Color(0xFF3B82F6) : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Jam Pulang',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.jamPulang,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: data.jamPulang != '-'
                              ? const Color(0xFF3B82F6)
                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Keterangan Presensi
          if (data.keterangan.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.keterangan,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Lokasi Dinas Luar (jika ada)
          if (data.lokasiDinasLuar != null && data.lokasiDinasLuar!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business_center_rounded,
                    size: 14,
                    color: Color(0xFFEAB308),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Dinas Luar: ${data.lokasiDinasLuar}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEAB308),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tampilan Foto Selfie Presensi (jika photo_url != null)
          if ((data.photoUrlMasuk != null && data.photoUrlMasuk!.isNotEmpty) ||
              (data.photoUrlPulang != null && data.photoUrlPulang!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 15,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Foto Selfie Presensi (Ketuk untuk Perbesar)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (data.photoUrlMasuk != null && data.photoUrlMasuk!.isNotEmpty) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showFullScreenImage(
                            context,
                            data.photoUrlMasuk!,
                            'Foto Selfie Masuk (${data.jamMasuk})',
                          ),
                          child: Container(
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    data.photoUrlMasuk!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF10B981),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                    ),
                                  ),
                                  // Overlay Label
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                                      color: Colors.black.withValues(alpha: 0.65),
                                      child: const Text(
                                        '📷 Selfie Masuk',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if ((data.photoUrlMasuk != null && data.photoUrlMasuk!.isNotEmpty) &&
                        (data.photoUrlPulang != null && data.photoUrlPulang!.isNotEmpty))
                      const SizedBox(width: 10),
                    if (data.photoUrlPulang != null && data.photoUrlPulang!.isNotEmpty) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showFullScreenImage(
                            context,
                            data.photoUrlPulang!,
                            'Foto Selfie Pulang (${data.jamPulang})',
                          ),
                          child: Container(
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    data.photoUrlPulang!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                    ),
                                  ),
                                  // Overlay Label
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                                      color: Colors.black.withValues(alpha: 0.65),
                                      child: const Text(
                                        '📷 Selfie Pulang',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ] else ...[
            // Jika photo_url == null: Tampilkan Indikator Presensi NFC Kartu
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.nfc_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '💳 Presensi via Tap Kartu NFC (Tanpa Foto)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // GPS Coordinates (Masuk & Pulang)
          if ((data.latMasuk != null && data.latMasuk!.isNotEmpty) ||
              (data.latPulang != null && data.latPulang!.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.pin_drop_rounded,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Koordinat GPS Presensi',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (data.latMasuk != null && data.latMasuk!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          size: 12,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'GPS Masuk: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${data.latMasuk}, ${data.longMasuk}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (data.latPulang != null && data.latPulang!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          size: 12,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'GPS Pulang: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${data.latPulang}, ${data.longPulang}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Dialog
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    // Image Viewer with Zoom & Pan
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(color: Color(0xFF10B981)),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                                  SizedBox(height: 8),
                                  Text(
                                    'Gagal memuat foto selfie',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Widget & Legenda Indikator Warna
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Kalender Presensi',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF10B981),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Legend Penanda Warna
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLegendItem(const Color(0xFF22C55E), 'Hadir'),
                      const SizedBox(width: 14),
                      _buildLegendItem(const Color(0xFFEAB308), 'Terlambat / Dinas'),
                      const SizedBox(width: 14),
                      _buildLegendItem(const Color(0xFF3B82F6), 'Izin / Sakit'),
                      const SizedBox(width: 14),
                      _buildLegendItem(const Color(0xFFEF4444), 'Alpa'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Core TableCalendar
          TableCalendar<DetailKehadiran>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
              defaultTextStyle: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
              ),
              markersMaxCount: 3,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;

                // Render marker dots berdasarkan aturan warna
                return Positioned(
                  bottom: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: events.take(3).map((item) {
                      final dotColor = _getStatusColor(item);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });

              final events = _getEventsForDay(selectedDay);
              _showDetailBottomSheet(selectedDay, events);
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              // Panggil ulang API untuk pembaruan data bulan baru
              _loadAttendanceData(focusedDay.month, focusedDay.year);
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
