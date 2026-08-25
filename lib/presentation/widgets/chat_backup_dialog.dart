import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/baknus_service_models.dart';
import '../../data/services/chat_backup_service.dart';
import '../../providers/baknus_provider.dart';

class ChatBackupDialog extends StatefulWidget {
  final String userEmail;

  const ChatBackupDialog({
    super.key,
    required this.userEmail,
  });

  static Future<void> show(BuildContext context, String userEmail) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatBackupDialog(userEmail: userEmail),
    );
  }

  @override
  State<ChatBackupDialog> createState() => _ChatBackupDialogState();
}

class _ChatBackupDialogState extends State<ChatBackupDialog> {
  final ChatBackupService _backupService = ChatBackupService();

  bool _isLoading = true;
  bool _isBackingUp = false;
  String? _restoringBackupId;
  String? _deletingBackupId;

  List<BaknusDriveBackup> _backups = [];
  DateTime? _lastBackupTime;
  String _autoBackupFreq = 'daily';

  @override
  void initState() {
    super.initState();
    _loadBackupData();
  }

  Future<void> _loadBackupData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _backupService.getBackups(widget.userEmail);
      final lastTime = await _backupService.getLastBackupTime();
      final freq = await _backupService.getAutoBackupFrequency();

      if (mounted) {
        setState(() {
          _backups = list;
          _lastBackupTime = lastTime;
          _autoBackupFreq = freq;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleManualBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final result = await _backupService.performBackup(
        userEmail: widget.userEmail,
        backupType: 'manual',
      );

      if (mounted) {
        setState(() => _isBackingUp = false);
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Backup BaknusChat (${result.messageCount} pesan) berhasil disimpan di BaknusDrive!'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
            ),
          );
          _loadBackupData();
          context.read<BaknusProvider>().loadAllStats(widget.userEmail);

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                  SizedBox(width: 8),
                  Text('Backup Berhasil!'),
                ],
              ),
              content: Text(
                'Arsip pesan BaknusChat (${result.messageCount} pesan) telah berhasil dibuat dan tersimpan dengan aman di BaknusDrive.',
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK, Mengerti'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal melakukan backup. Cek koneksi internet & kuota BaknusDrive Anda.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _handleRestore(BaknusDriveBackup backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Pulihkan Pesan?'),
          ],
        ),
        content: Text(
          'Pesan BaknusChat akan dipulihkan dari file backup "${backup.filename}" (${backup.formattedDate}, ${backup.messageCount} pesan).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Pulihkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _restoringBackupId = backup.backupId);

    final success = await _backupService.restoreBackup(
      userEmail: widget.userEmail,
      backup: backup,
    );

    if (mounted) {
      setState(() => _restoringBackupId = null);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Berhasil memulihkan ${backup.messageCount} pesan BaknusChat!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 8),
                Text('Pemulihan Berhasil!'),
              ],
            ),
            content: Text(
              'Sebanyak ${backup.messageCount} pesan BaknusChat telah berhasil dipulihkan dari BaknusDrive ke obrolan Anda.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK, Selesai'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memulihkan backup. Terjadi kesalahan pada file.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(BaknusDriveBackup backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Backup?'),
        content: Text('File backup "${backup.filename}" di BaknusDrive akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingBackupId = backup.backupId);

    final success = await _backupService.deleteBackup(
      userEmail: widget.userEmail,
      backupId: backup.backupId,
    );

    if (mounted) {
      setState(() => _deletingBackupId = null);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File backup telah dihapus.')),
        );
        _loadBackupData();
        context.read<BaknusProvider>().loadAllStats(widget.userEmail);
      }
    }
  }

  String _formatLastBackupText() {
    if (_lastBackupTime == null) return 'Belum pernah dilakukan dari HP ini';
    final dt = _lastBackupTime!.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baknus = context.watch<BaknusProvider>();
    final drive = baknus.driveData;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup & Restore BaknusChat',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Penyimpanan terintegrasi BaknusDrive',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Kuota Storage BaknusDrive
                      if (drive != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kapasitas BaknusDrive Saya',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: drive.storage.percentageUsed,
                                      backgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                                      color: drive.storage.percentageUsed > 0.9 ? Colors.redAccent : AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${StorageInfo.formatBytes(drive.storage.usedBytes)} / ${StorageInfo.formatBytes(drive.storage.quotaBytes)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Subtitle Last Backup Info
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 14, color: isDark ? Colors.white54 : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Terakhir dibackup: ${_formatLastBackupText()}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tombol Backup Sekarang
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: _isBackingUp ? null : _handleManualBackup,
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.backup_rounded),
                          label: Text(
                            _isBackingUp ? 'Memproses Backup...' : 'Backup Sekarang ke BaknusDrive',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Pengaturan Auto Backup
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jadwal Auto-Backup',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.grey[800],
                            ),
                          ),
                          DropdownButton<String>(
                            value: _autoBackupFreq,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            underline: const SizedBox(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'daily', child: Text('Harian (Setiap Hari)')),
                              DropdownMenuItem(value: 'weekly', child: Text('Mingguan (7 Hari)')),
                              DropdownMenuItem(value: 'off', child: Text('Nonaktifkan')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _autoBackupFreq = val);
                                _backupService.setAutoBackupFrequency(val);
                              }
                            },
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Section List Riwayat Backup
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Riwayat Backup di BaknusDrive',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            tooltip: 'Muat ulang',
                            onPressed: _loadBackupData,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Notice Retensi Maks 3 File
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'BaknusDrive menyimpan maksimal 3 file backup terbaru secara otomatis.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.amber[200] : Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // List Content
                      _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _backups.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_off_rounded,
                                          size: 40,
                                          color: isDark ? Colors.white24 : Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Belum Ada Backup Tersimpan',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.white54 : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _backups.length,
                                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, index) {
                                    final bkp = _backups[index];
                                    final isRestoring = _restoringBackupId == bkp.backupId;
                                    final isDeleting = _deletingBackupId == bkp.backupId;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: bkp.backupType == 'auto'
                                                  ? Colors.blue.withValues(alpha: 0.15)
                                                  : Colors.green.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              bkp.backupType == 'auto'
                                                  ? Icons.autorenew_rounded
                                                  : Icons.touch_app_rounded,
                                              color: bkp.backupType == 'auto' ? Colors.blue : Colors.green,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  bkp.formattedDate,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${StorageInfo.formatBytes(bkp.fileSize)} • ${bkp.messageCount} Pesan (${bkp.backupType.toUpperCase()})',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.white60 : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isRestoring || isDeleting)
                                            const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          else
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                                                  tooltip: 'Pulihkan / Restore',
                                                  onPressed: () => _handleRestore(bkp),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                                  tooltip: 'Hapus',
                                                  onPressed: () => _handleDelete(bkp),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
