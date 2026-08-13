import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/baknus_service_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baknus_provider.dart';

class BaknusTalimScreen extends StatelessWidget {
  const BaknusTalimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final baknus = context.watch<BaknusProvider>();
    final user = auth.currentUser;
    final talim = baknus.talimData;

    final name = talim?.name.isNotEmpty == true
        ? talim!.name
        : (user?.displayName ?? 'Pengguna');
    final email = talim?.email.isNotEmpty == true
        ? talim!.email
        : (user?.email ?? '');
    final role = talim?.role.isNotEmpty == true
        ? talim!.role
        : (user != null ? 'Civitas' : '');
    final activity = talim?.lastActivity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BaknusTa\'lim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () {
              if (email.isNotEmpty) {
                baknus.loadAllStats(email);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (email.isNotEmpty) {
            await baknus.loadAllStats(email);
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Header Profil (Nama, Email, Role)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
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
                          role.isNotEmpty ? 'Keagamaan • $role' : 'Keagamaan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.auto_stories_rounded,
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
            const SizedBox(height: 20),

            // Aktivitas Terakhir (last_activity dari API)
            const Text(
              'Aktivitas Keagamaan Terakhir',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (activity == null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 44,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Belum memiliki riwayat aktivitas keagamaan.',
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipe & Nilai
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.auto_stories_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.tipe.isNotEmpty
                                          ? activity.tipe
                                          : 'Aktivitas',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (activity.waktu.isNotEmpty)
                                      Text(
                                        activity.formattedWaktu,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (activity.nilai != null && activity.nilai!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Nilai: ${activity.nilai}',
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Detail Sesuai Data Asli dari API
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildDetailSections(activity, isDark),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSections(LastActivityTalim activity, bool isDark) {
    final tipe = activity.tipe.toLowerCase();
    final fields = <Widget>[];

    // Bookmark
    if (tipe.contains('bookmark')) {
      if (activity.surahNama.isNotEmpty) {
        final surahLabel = activity.surahNumber != null && activity.surahNumber! > 0
            ? 'QS. ${activity.surahNama} (${activity.surahNumber})'
            : 'QS. ${activity.surahNama}';
        fields.add(_buildField('Surah', surahLabel));
      }
      if (activity.ayatNumber != null && activity.ayatNumber! > 0) {
        fields.add(_buildField('Ayat', 'Ayat ${activity.ayatNumber}'));
      } else if (activity.ayatStart != null && activity.ayatEnd != null) {
        fields.add(_buildField('Ayat', 'Ayat ${activity.ayatStart} - ${activity.ayatEnd}'));
      }
      if (activity.catatan != null && activity.catatan!.isNotEmpty) {
        fields.add(_buildField('Catatan', activity.catatan!));
      }
    }
    // Tilawah
    else if (tipe.contains('tilawah')) {
      if (activity.surahNama.isNotEmpty) {
        final surahLabel = activity.surahNumber != null && activity.surahNumber! > 0
            ? 'QS. ${activity.surahNama} (${activity.surahNumber})'
            : 'QS. ${activity.surahNama}';
        fields.add(_buildField('Surah', surahLabel));
      }
      if (activity.ayatStart != null && activity.ayatEnd != null) {
        fields.add(_buildField('Ayat', 'Ayat ${activity.ayatStart} - ${activity.ayatEnd}'));
      } else if (activity.ayatNumber != null && activity.ayatNumber! > 0) {
        fields.add(_buildField('Ayat', 'Ayat ${activity.ayatNumber}'));
      }
      if (activity.status != null && activity.status!.isNotEmpty) {
        fields.add(_buildField('Status', activity.status!));
      }
      if (activity.catatan != null && activity.catatan!.isNotEmpty) {
        fields.add(_buildField('Catatan', '"${activity.catatan}"', isItalic: true));
      }
    }
    // Hafalan
    else if (tipe.contains('hafalan')) {
      if (activity.surahNama.isNotEmpty) {
        fields.add(_buildField('Surah', activity.surahNama));
      }
      if (activity.ayatStart != null && activity.ayatEnd != null) {
        fields.add(_buildField('Ayat', 'Ayat ${activity.ayatStart} - ${activity.ayatEnd}'));
      } else if (activity.ayatNumber != null && activity.ayatNumber! > 0) {
        fields.add(_buildField('Ayat', 'Ayat ${activity.ayatNumber}'));
      }
      if (activity.status != null && activity.status!.isNotEmpty) {
        fields.add(_buildField('Status', activity.status!));
      }
      if (activity.catatan != null && activity.catatan!.isNotEmpty) {
        fields.add(_buildField('Catatan', '"${activity.catatan}"', isItalic: true));
      }
    }
    // Amalan Yaumi
    else if (tipe.contains('amalan') || tipe.contains('yaumi')) {
      if (activity.shalatFardhu != null && activity.shalatFardhu!.isNotEmpty) {
        fields.add(_buildField('Shalat Fardhu', activity.shalatFardhu!));
      }
      if (activity.shalatSunnah != null && activity.shalatSunnah!.isNotEmpty) {
        fields.add(_buildField('Shalat Sunnah', activity.shalatSunnah!));
      }
      if (activity.puasa != null && activity.puasa!.isNotEmpty) {
        fields.add(_buildField('Puasa', activity.puasa!));
      }
      if (activity.catatan != null && activity.catatan!.isNotEmpty) {
        fields.add(_buildField('Catatan', activity.catatan!));
      }
    }
    // Praktek Ibadah
    else if (tipe.contains('ibadah') || tipe.contains('praktek')) {
      if (activity.jenisIbadah != null && activity.jenisIbadah!.isNotEmpty) {
        fields.add(_buildField('Jenis Ibadah', activity.jenisIbadah!));
      }
      if (activity.status != null && activity.status!.isNotEmpty) {
        fields.add(_buildField('Status', activity.status!));
      }
      if (activity.catatan != null && activity.catatan!.isNotEmpty) {
        fields.add(_buildField('Catatan', '"${activity.catatan}"', isItalic: true));
      }
    }

    // Jika belum ada field yang cocok atau ada field tambahan dari detail JSON
    if (fields.isEmpty) {
      activity.detail.forEach((key, val) {
        if (val != null && val.toString().trim().isNotEmpty) {
          final cleanKey = _formatKeyLabel(key);
          fields.add(_buildField(cleanKey, val.toString()));
        }
      });
    }

    if (fields.isEmpty) {
      return const Text(
        'Data detail aktivitas tidak tersedia.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          fields[i],
        ],
      ],
    );
  }

  String _formatKeyLabel(String key) {
    final words = key.replaceAll('_', ' ').split(' ');
    return words.map((w) {
      if (w.isEmpty) return '';
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  Widget _buildField(String label, String value, {bool isItalic = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
