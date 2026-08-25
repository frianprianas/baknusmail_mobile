import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/baknus_service_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baknus_provider.dart';

import '../../core/config/mailcow_config.dart';
import '../../core/utils/url_helper.dart';

import '../widgets/app_background.dart';
import '../widgets/attendance_calendar_widget.dart';

class BaknusAttendScreen extends StatefulWidget {
  const BaknusAttendScreen({super.key});

  @override
  State<BaknusAttendScreen> createState() => _BaknusAttendScreenState();
}

class _BaknusAttendScreenState extends State<BaknusAttendScreen> {
  BaknusAttendData? _calendarData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final baknus = context.watch<BaknusProvider>();
    final user = auth.currentUser;

    final providerAttend = baknus.attendData;
    final attend = _calendarData ?? providerAttend;

    final name = attend?.name.isNotEmpty == true
        ? attend!.name
        : (user?.displayName ?? 'Pengguna');
    final email = attend?.email.isNotEmpty == true
        ? attend!.email
        : (user?.email ?? '');
    final role = attend?.role.isNotEmpty == true ? attend!.role : 'Siswa';
    final totalHadir = attend?.totalKehadiranBulanIni ?? 0;
    final details = attend?.detailKehadiran ?? [];

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('BaknusAttend'),
          actions: [
            IconButton(
              icon: const Icon(Icons.language_rounded),
              tooltip: 'Buka Web BaknusAttend',
              onPressed: () => UrlHelper.openServiceWebUrl(
                MailcowConfig.attendWebUrl,
                userEmail: email,
                context: context,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan',
              onPressed: () {
                if (email.isNotEmpty) {
                  baknus.loadAllStats(email);
                  setState(() {
                    _calendarData = null;
                  });
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            if (email.isNotEmpty) {
              await baknus.loadAllStats(email);
              if (mounted) {
                setState(() {
                  _calendarData = null;
                });
              }
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Tombol Buka Aplikasi Web dengan Auto-Fill Email
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 22),
                label: const Text(
                  'Buka Web BaknusAttend (Auto-Fill Login)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: () => UrlHelper.openServiceWebUrl(
                  MailcowConfig.attendWebUrl,
                  userEmail: email,
                  context: context,
                ),
              ),
              const SizedBox(height: 14),

              // Header Profil (Nama, Email, Role)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Presensi • $role',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.fingerprint_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ==================== WIDGET KALENDER LAPORAN KEHADIRAN ====================
              AttendanceCalendarWidget(
                userEmail: email,
                initialData: providerAttend,
                onDataUpdated: (newData) {
                  setState(() {
                    _calendarData = newData;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Ringkasan & Progress Bar: Jumlah Kehadiran Bulan Ini
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah Kehadiran Bulan Ini',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$totalHadir Hari',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalHadir > 0 ? (totalHadir / 24).clamp(0.0, 1.0) : 0.0,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalHadir dari estimasi 24 hari kerja/sekolah bulan ini',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Daftar Riwayat Presensi Terbaru (detail_kehadiran)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar Riwayat Presensi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${details.length} Catatan',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (details.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 44,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada catatan riwayat presensi.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...details.map((d) => _buildDetailItem(d, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(DetailKehadiran d, bool isDark) {
    final isTerlambat = d.status.toLowerCase().contains('terlambat');
    final isDinas = d.isDinasLuar || d.status.toLowerCase().contains('dinas');

    Color statusColor = const Color(0xFF10B981);
    if (isTerlambat || isDinas) statusColor = const Color(0xFFEAB308);
    if (d.status.toLowerCase().contains('izin') || d.status.toLowerCase().contains('sakit')) {
      statusColor = const Color(0xFF3B82F6);
    }
    if (d.status.toLowerCase().contains('alpa')) {
      statusColor = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_filled_rounded,
                      size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    d.waktuTap,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (d.keterangan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              d.keterangan,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
          if (d.lokasiDinasLuar != null && d.lokasiDinasLuar!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFEAB308)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Lokasi: ${d.lokasiDinasLuar}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFEAB308),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (d.lat != null && d.long != null && d.lat!.isNotEmpty && d.long!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF3B82F6)),
                const SizedBox(width: 4),
                Text(
                  'Koordinat: ${d.lat}, ${d.long}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
