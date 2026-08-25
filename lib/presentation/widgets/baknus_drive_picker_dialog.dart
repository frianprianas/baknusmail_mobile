import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/chat_service.dart';

typedef OnBaknusDriveFileSelected = void Function(
  String fileName,
  String fileUrl,
  int? fileSize,
  String type,
);

class BaknusDrivePickerDialog extends StatefulWidget {
  final String userEmail;
  final OnBaknusDriveFileSelected onFileSelected;

  const BaknusDrivePickerDialog({
    super.key,
    required this.userEmail,
    required this.onFileSelected,
  });

  static void show(
    BuildContext context, {
    required String userEmail,
    required OnBaknusDriveFileSelected onFileSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BaknusDrivePickerDialog(
        userEmail: userEmail,
        onFileSelected: onFileSelected,
      ),
    );
  }

  @override
  State<BaknusDrivePickerDialog> createState() => _BaknusDrivePickerDialogState();
}

class _BaknusDrivePickerDialogState extends State<BaknusDrivePickerDialog> {
  int _selectedFilterIndex = 0; // 0 = Semua Cloud, 1 = Unggahan Saya

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ChatService chatService = ChatService();
    final cleanUserEmail = widget.userEmail.toLowerCase().trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_circle_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Berkas BaknusDrive Saya',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Penyimpanan cloud berkas & media sekolah',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filter Segment Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterTab(
                    index: 0,
                    label: 'Semua Berkas Cloud',
                    icon: Icons.cloud_done_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterTab(
                    index: 1,
                    label: 'Unggahan Saya',
                    icon: Icons.person_pin_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Stream Content: All Cloud Files from Firestore
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chatService.getUserDriveFilesStream(widget.userEmail),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final allFiles = snapshot.data ?? [];
                final driveFiles = _selectedFilterIndex == 1
                    ? allFiles.where((m) => m.senderEmail.toLowerCase() == cleanUserEmail).toList()
                    : allFiles;

                if (driveFiles.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_off_rounded,
                              size: 48,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFilterIndex == 1
                                ? 'Belum Ada Berkas yang Anda Unggah'
                                : 'Belum Ada Berkas BaknusDrive',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedFilterIndex == 1
                                ? 'Berkas atau foto yang Anda kirimkan ke chat akan otomatis tersimpan di sini.'
                                : 'Seluruh berkas dokumen & media yang dikirimkan di BaknusChat tersimpan otomatis di sini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: driveFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final msg = driveFiles[index];
                    final name = msg.fileName ?? (msg.isImage ? '📷 Foto BaknusDrive' : 'Dokumen');
                    final url = msg.effectiveFileUrl;
                    final sizeStr = msg.formattedFileSize;

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (msg.isImage ? Colors.purple : const Color(0xFF2563EB)).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            msg.isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                            color: msg.isImage ? Colors.purple : const Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${msg.senderName}${sizeStr.isNotEmpty ? " • $sizeStr" : ""} • ${msg.timeFormatted}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text('Kirim', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onFileSelected(
                              name,
                              url,
                              msg.fileSize,
                              msg.type,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
              : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF2563EB) : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
