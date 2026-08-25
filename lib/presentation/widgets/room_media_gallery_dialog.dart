import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/chat_service.dart';

class RoomMediaGalleryDialog extends StatefulWidget {
  final String roomId;
  final String roomTitle;

  const RoomMediaGalleryDialog({
    super.key,
    required this.roomId,
    required this.roomTitle,
  });

  static void show(BuildContext context, {required String roomId, required String roomTitle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoomMediaGalleryDialog(
        roomId: roomId,
        roomTitle: roomTitle,
      ),
    );
  }

  @override
  State<RoomMediaGalleryDialog> createState() => _RoomMediaGalleryDialogState();
}

class _RoomMediaGalleryDialogState extends State<RoomMediaGalleryDialog>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
                    color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.perm_media_rounded,
                    color: Color(0xFFE11D48),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Galeri Media & Dokumen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.roomTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

          // Custom TabBar
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFE11D48),
            labelColor: const Color(0xFFE11D48),
            unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: '📷 Foto'),
              Tab(text: '📄 Berkas'),
              Tab(text: '🎙️ Pesan Suara'),
            ],
          ),

          // TabBarView Content Stream
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessagesStream(widget.roomId, limit: 200),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMessages = snapshot.data ?? [];
                final imageMessages = allMessages.where((m) => m.isImage).toList();
                final fileMessages = allMessages.where((m) => m.isFile).toList();
                final audioMessages = allMessages.where((m) => m.isAudio).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildImageGrid(imageMessages, isDark),
                    _buildFileList(fileMessages, isDark),
                    _buildAudioList(audioMessages, isDark),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<ChatMessage> items, bool isDark) {
    if (items.isEmpty) {
      return _buildEmptyState(Icons.image_not_supported_outlined, 'Belum ada foto yang dibagikan');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final msg = items[index];
        final url = msg.imageUrl ?? msg.fileUrl ?? '';
        return GestureDetector(
          onTap: () => url.isNotEmpty ? _launchUrl(url) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[200],
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileList(List<ChatMessage> items, bool isDark) {
    if (items.isEmpty) {
      return _buildEmptyState(Icons.folder_open_rounded, 'Belum ada berkas atau dokumen');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final msg = items[index];
        final fileName = msg.fileName ?? 'Dokumen';
        final sizeStr = msg.formattedFileSize;
        final isArchive = msg.isArchive;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isArchive ? Colors.amber : const Color(0xFFE11D48)).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isArchive ? Icons.folder_zip_rounded : Icons.description_rounded,
                color: isArchive ? Colors.amber[800] : const Color(0xFFE11D48),
                size: 20,
              ),
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${msg.senderName} • ${msg.timeFormatted}${sizeStr.isNotEmpty ? " • $sizeStr" : ""}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: () => msg.effectiveFileUrl.isNotEmpty ? _launchUrl(msg.effectiveFileUrl) : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioList(List<ChatMessage> items, bool isDark) {
    if (items.isEmpty) {
      return _buildEmptyState(Icons.graphic_eq_rounded, 'Belum ada pesan suara');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final msg = items[index];
        final duration = msg.audioDuration ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            title: Text(
              'Pesan Suara (${duration}d)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${msg.senderName} • ${msg.timeFormatted}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB), size: 28),
              onPressed: () => msg.effectiveFileUrl.isNotEmpty ? _launchUrl(msg.effectiveFileUrl) : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}
