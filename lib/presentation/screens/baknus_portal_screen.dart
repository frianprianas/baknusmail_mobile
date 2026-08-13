import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/baknus_service_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baknus_provider.dart';
import '../../providers/mail_provider.dart';
import '../widgets/user_avatar.dart';

class BaknusPortalScreen extends StatefulWidget {
  const BaknusPortalScreen({super.key});

  @override
  State<BaknusPortalScreen> createState() => _BaknusPortalScreenState();
}

class _BaknusPortalScreenState extends State<BaknusPortalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final email = context.read<AuthProvider>().currentUser?.email ?? '';
      context.read<MailProvider>().loadFoldersAndEmails();
      if (email.isNotEmpty) {
        context.read<BaknusProvider>().loadAllStats(email);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final mail = context.watch<MailProvider>();
    final baknus = context.watch<BaknusProvider>();
    final user = auth.currentUser;

    final unreadMailCount = mail.unreadCountTotal;
    final attend = baknus.attendData;
    final talim = baknus.talimData;
    final drive = baknus.driveData;

    final userName = attend?.name.isNotEmpty == true
        ? attend!.name
        : (drive?.name.isNotEmpty == true
            ? drive!.name
            : (talim?.name.isNotEmpty == true
                ? talim!.name
                : (user?.displayName ?? 'Pengguna Baknus')));

    final userEmail = attend?.email.isNotEmpty == true
        ? attend!.email
        : (drive?.email.isNotEmpty == true
            ? drive!.email
            : (talim?.email.isNotEmpty == true
                ? talim!.email
                : (user?.email ?? '')));

    final userRole = baknus.userRole;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard BaknusID',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  MailcowConfig.schoolName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar dari Akun?'),
                  content: const Text(
                    'Anda akan keluar dari sesi akun Anda.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final email = auth.currentUser?.email ?? '';
          await Future.wait([
            mail.loadFoldersAndEmails(),
            if (email.isNotEmpty) baknus.loadAllStats(email),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            // ==================== 1. HEADER PROFIL (Nama, Email, Role) ====================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A), // Deep Navy
                    Color(0xFF1E40AF), // Royal Blue
                    Color(0xFF0284C7), // Sky Blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            UserAvatar(
                              name: userName,
                              email: userEmail,
                              radius: 25,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profil Pengguna',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Role Badge (Siswa / Guru / TU)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          userRole,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alternate_email_rounded,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            userEmail,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ==================== MENU LAYANAN UTAMA ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Layanan Terintegrasi',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (baknus.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 4 Grid Buttons
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _buildServiceButton(
                  title: 'BaknusMail',
                  subtitle: 'Kotak Masuk Email',
                  badge: unreadMailCount > 0 ? '$unreadMailCount Baru' : 'Inbox',
                  badgeColor: unreadMailCount > 0
                      ? AppColors.error
                      : const Color(0xFF2563EB),
                  icon: Icons.mark_email_read_rounded,
                  color: const Color(0xFF1E40AF),
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/home'),
                ),
                _buildServiceButton(
                  title: 'BaknusAttend',
                  subtitle: 'Presensi & Kehadiran',
                  badge: attend != null
                      ? '${attend.totalKehadiranBulanIni} Hadir'
                      : 'Presensi',
                  badgeColor: const Color(0xFF059669),
                  icon: Icons.fingerprint_rounded,
                  color: const Color(0xFF059669),
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/attend'),
                ),
                _buildServiceButton(
                  title: 'BaknusTa\'lim',
                  subtitle: 'Kegiatan Keagamaan',
                  badge: talim?.lastActivity != null
                      ? talim!.lastActivity!.tipe
                      : 'Ngaji',
                  badgeColor: const Color(0xFFD97706),
                  icon: Icons.auto_stories_rounded,
                  color: const Color(0xFFD97706),
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/talim'),
                ),
                _buildServiceButton(
                  title: 'BaknusDrive',
                  subtitle: 'Penyimpanan Berkas',
                  badge: drive != null
                      ? StorageInfo.formatBytes(drive.storage.usedBytes)
                      : 'Drive',
                  badgeColor: const Color(0xFF0284C7),
                  icon: Icons.cloud_sync_rounded,
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                  onTap: () => Navigator.pushNamed(context, '/drive'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==================== 2. WIDGET PRESENSI (BaknusAttend) ====================
            _buildSectionHeader('Kehadiran/Presensi (BaknusAttend)', isDark),
            _buildAttendWidget(attend, isDark),
            const SizedBox(height: 20),

            // ==================== 3. WIDGET KEAGAMAAN (BaknusTa'lim) ====================
            _buildSectionHeader('Kegiatan Keagamaan/Ngaji (BaknusTa\'lim)', isDark),
            _buildTalimWidget(talim, isDark),
            const SizedBox(height: 20),

            // ==================== 4. WIDGET PENYIMPANAN (BaknusDrive) ====================
            _buildSectionHeader('Penyimpanan Berkas/Drive (BaknusDrive)', isDark),
            _buildDriveWidget(drive, isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  // ==================== WIDGET PRESENSI (BaknusAttend) ====================
  Widget _buildAttendWidget(BaknusAttendData? attend, bool isDark) {
    final totalHadir = attend?.totalKehadiranBulanIni ?? 0;
    final details = attend?.detailKehadiran ?? [];

    return Container(
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
          // Ringkasan Jumlah Kehadiran Bulan Ini
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jumlah Kehadiran Bulan Ini',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$totalHadir Hari',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.pushNamed(context, '/attend'),
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar Kehadiran (Target standar 24 hari kerja/sekolah)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalHadir > 0 ? (totalHadir / 24).clamp(0.0, 1.0) : 0.0,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),

          // Daftar Riwayat Presensi Terbaru
          const Text(
            'Riwayat Presensi Terbaru:',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (details.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada catatan riwayat presensi.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            )
          else
            ...details.take(2).map((d) {
              final isTerlambat = d.status.toLowerCase().contains('terlambat');
              final isDinas = d.isDinasLuar || d.status.toLowerCase().contains('dinas');

              Color statusColor = const Color(0xFF10B981);
              if (isTerlambat) statusColor = const Color(0xFFF59E0B);
              if (isDinas) statusColor = const Color(0xFF3B82F6);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
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
                                size: 15, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              d.waktuTap,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            d.status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (d.keterangan.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        d.keterangan,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                    if (d.lokasiDinasLuar != null && d.lokasiDinasLuar!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Lokasi: ${d.lokasiDinasLuar}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==================== WIDGET KEAGAMAAN (BaknusTa'lim) ====================
  Widget _buildTalimWidget(BaknusTalimData? talim, bool isDark) {
    final activity = talim?.lastActivity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: activity == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Belum memiliki riwayat aktivitas keagamaan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Tipe & Nilai
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.tipe.isNotEmpty ? activity.tipe : 'Aktivitas',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (activity.waktu.isNotEmpty)
                                  Text(
                                    activity.formattedWaktu,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activity.nilai != null && activity.nilai!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Nilai: ${activity.nilai}',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Detail Sesuai Tipe Aktivitas
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _buildTalimDetailContent(activity, isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildTalimDetailContent(LastActivityTalim activity, bool isDark) {
    final tipe = activity.tipe.toLowerCase();

    // Bookmark
    if (tipe.contains('bookmark')) {
      final surahLabel = activity.surahNumber != null && activity.surahNumber! > 0
          ? 'QS. ${activity.surahNama} (${activity.surahNumber})'
          : (activity.surahNama.isNotEmpty ? 'QS. ${activity.surahNama}' : '');
      final ayatText = activity.ayatNumber != null && activity.ayatNumber! > 0
          ? 'Ayat ${activity.ayatNumber}'
          : (activity.ayatStart != null && activity.ayatEnd != null
              ? 'Ayat ${activity.ayatStart} - ${activity.ayatEnd}'
              : '');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (surahLabel.isNotEmpty)
            Text(
              'Surah: $surahLabel',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          if (ayatText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(ayatText, style: const TextStyle(fontSize: 11.5)),
          ],
          if (activity.catatan != null && activity.catatan!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Catatan: ${activity.catatan}',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      );
    }

    // Tilawah
    if (tipe.contains('tilawah')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.surahNama.isNotEmpty)
            Text(
              'Surah: ${activity.surahNama}${activity.ayatStart != null && activity.ayatEnd != null ? " (Ayat ${activity.ayatStart} - ${activity.ayatEnd})" : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          if (activity.status != null && activity.status!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Status: ${activity.status}', style: const TextStyle(fontSize: 11.5)),
          ],
          if (activity.catatan != null && activity.catatan!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan: "${activity.catatan}"',
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      );
    }

    // Hafalan
    if (tipe.contains('hafalan')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.surahNama.isNotEmpty)
            Text(
              'Surah: ${activity.surahNama}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          if (activity.status != null && activity.status!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Status: ${activity.status}', style: const TextStyle(fontSize: 11.5)),
          ],
          if (activity.catatan != null && activity.catatan!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan: "${activity.catatan}"',
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      );
    }

    // Amalan Yaumi
    if (tipe.contains('amalan') || tipe.contains('yaumi')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.shalatFardhu != null && activity.shalatFardhu!.isNotEmpty)
            Text(
              'Shalat Fardhu: ${activity.shalatFardhu}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          if (activity.shalatSunnah != null && activity.shalatSunnah!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Shalat Sunnah: ${activity.shalatSunnah}',
                style: const TextStyle(fontSize: 11.5)),
          ],
          if (activity.puasa != null && activity.puasa!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Puasa: ${activity.puasa}', style: const TextStyle(fontSize: 11.5)),
          ],
        ],
      );
    }

    // Praktek Ibadah
    if (tipe.contains('ibadah') || tipe.contains('praktek')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.jenisIbadah != null && activity.jenisIbadah!.isNotEmpty)
            Text(
              'Jenis Ibadah: ${activity.jenisIbadah}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          if (activity.status != null && activity.status!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Status: ${activity.status}', style: const TextStyle(fontSize: 11.5)),
          ],
          if (activity.catatan != null && activity.catatan!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan: "${activity.catatan}"',
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      );
    }

    // Generic / Dynamic fields fallback
    final lines = <Widget>[];
    activity.detail.forEach((k, v) {
      if (v != null && v.toString().trim().isNotEmpty) {
        final label = k.replaceAll('_', ' ');
        lines.add(Text(
          '${label[0].toUpperCase()}${label.substring(1)}: $v',
          style: const TextStyle(fontSize: 11.5),
        ));
      }
    });

    if (lines.isEmpty) {
      return const Text(
        'Data detail aktivitas tidak tersedia.',
        style: TextStyle(fontSize: 11.5, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }

  // ==================== WIDGET PENYIMPANAN (BaknusDrive) ====================
  Widget _buildDriveWidget(BaknusDriveData? drive, bool isDark) {
    final storage = drive?.storage ??
        StorageInfo(
          quotaBytes: 10737418240,
          usedBytes: 1048576,
          availableBytes: 10736369664,
          percentageUsed: 0.0097,
        );

    final usedStr = StorageInfo.formatBytes(storage.usedBytes);
    final quotaStr = StorageInfo.formatBytes(storage.quotaBytes);
    final availableStr = StorageInfo.formatBytes(storage.availableBytes);
    final percentageFormatted = storage.percentString;

    return Container(
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_queue_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kapasitas Penyimpanan',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$usedStr / $quotaStr ($percentageFormatted)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.pushNamed(context, '/drive'),
                child: const Text('Detail', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Indikator Grafis Kapasitas Penyimpanan (Progress Bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: storage.ratio,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 10),

          // Kuota Terpakai vs Sisa Kuota
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sisa Kuota: $availableStr',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (drive != null && drive.lastAccessed.isNotEmpty)
                Flexible(
                  child: Text(
                    'Akses: ${drive.lastAccessed}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceButton({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
