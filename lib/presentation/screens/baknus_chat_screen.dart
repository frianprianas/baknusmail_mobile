import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_tag_resolver.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/mailcow_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baknus_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/user_avatar.dart';

class BaknusChatScreen extends StatefulWidget {
  final String? initialDirectPeerEmail;
  final String? initialDirectPeerName;
  final String? initialDirectPeerTag;

  const BaknusChatScreen({
    super.key,
    this.initialDirectPeerEmail,
    this.initialDirectPeerName,
    this.initialDirectPeerTag,
  });

  @override
  State<BaknusChatScreen> createState() => _BaknusChatScreenState();
}

class _BaknusChatScreenState extends State<BaknusChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();

  // State untuk Chat Pribadi (Japri)
  String? _activeDirectPeerEmail;
  String? _activeDirectPeerName;
  String? _activeDirectPeerTag;

  Map<String, dynamic>? _liveMailboxData;
  bool _isSending = false;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialDirectPeerEmail != null) {
      _activeDirectPeerEmail = widget.initialDirectPeerEmail;
      _activeDirectPeerName =
          widget.initialDirectPeerName ?? widget.initialDirectPeerEmail!.split('@').first;
      _activeDirectPeerTag = widget.initialDirectPeerTag ?? 'Siswa';
    }

    // Ambil data mailbox Mailcow secara live untuk deteksi TAG yang 100% akurat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLiveMailboxInfo();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _activeDirectPeerEmail == null) {
      final peerEmail = args['peerEmail']?.toString();
      if (peerEmail != null && peerEmail.isNotEmpty) {
        final auth = context.read<AuthProvider>();
        final userEmail = auth.currentUser?.email ?? '';
        if (userEmail.isNotEmpty) {
          _chatService.markConversationAsRead(userEmail, peerEmail);
        }
        setState(() {
          _activeDirectPeerEmail = peerEmail;
          _activeDirectPeerName = args['peerName']?.toString() ?? peerEmail.split('@').first;
          _activeDirectPeerTag = args['peerTag']?.toString() ?? 'Siswa';
        });
      }
    }
  }

  Future<void> _fetchLiveMailboxInfo() async {
    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? '';
    if (email.isEmpty) return;

    try {
      final api = context.read<MailcowApiService>();
      final mbox = await api.getMailboxDetails(email);
      if (mbox != null && mounted) {
        setState(() {
          _liveMailboxData = mbox;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openDirectChat({
    required String peerEmail,
    required String peerName,
    required String peerTag,
  }) {
    final cleanPeer = peerEmail.toLowerCase().trim();
    final auth = context.read<AuthProvider>();
    final userEmail = auth.currentUser?.email ?? '';
    if (userEmail.isNotEmpty) {
      _chatService.markConversationAsRead(userEmail, cleanPeer);
    }
    setState(() {
      _activeDirectPeerEmail = cleanPeer;
      _activeDirectPeerName = peerName;
      _activeDirectPeerTag = peerTag;
    });
  }

  Future<void> _handleSendMessage({
    required String senderEmail,
    required String senderName,
    required String senderTag,
  }) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_activeDirectPeerEmail == null || _activeDirectPeerEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kontak tujuan terlebih dahulu.')),
      );
      return;
    }

    final targetRoomId = ChatService.getPrivateRoomId(senderEmail, _activeDirectPeerEmail!);

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await _chatService.sendMessage(
        roomId: targetRoomId,
        text: text,
        senderEmail: senderEmail,
        senderName: senderName,
        senderRole: senderTag, // TAG resmi: Siswa / Guru / TU
        recipientEmail: _activeDirectPeerEmail,
        recipientName: _activeDirectPeerName,
        recipientTag: _activeDirectPeerTag,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim pesan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handlePickAndSendFile({
    required String senderEmail,
    required String senderName,
    required String senderTag,
    FileType fileType = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    if (_activeDirectPeerEmail == null || _activeDirectPeerEmail!.isEmpty || _isSending) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final filePath = file.path;
      final fileBytes = file.bytes;
      final filename = file.name;
      final fileSize = file.size;

      if (filePath == null && fileBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File tidak dapat dibaca.')),
          );
        }
        return;
      }

      final caption = await _showFileCaptionDialog(filename, fileSize);
      if (caption == null) return; // Dibatalkan oleh pengguna

      final targetRoomId = ChatService.getPrivateRoomId(senderEmail, _activeDirectPeerEmail!);

      setState(() => _isSending = true);

      await _chatService.sendFileMessage(
        roomId: targetRoomId,
        senderEmail: senderEmail,
        senderName: senderName,
        senderRole: senderTag,
        caption: caption,
        filePath: filePath,
        fileBytes: fileBytes,
        filename: filename,
        fileSize: fileSize,
        recipientEmail: _activeDirectPeerEmail,
        recipientName: _activeDirectPeerName,
        recipientTag: _activeDirectPeerTag,
      );

      _scrollToBottom();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berkas berhasil dikirim & tersimpan di BaknusDrive!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah berkas: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showAttachmentPickerMenu({
    required String senderEmail,
    required String senderName,
    required String senderTag,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kirim Berkas ke BaknusChat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Media & dokumen tersimpan otomatis di akun BaknusDrive Anda.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.3,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.image_rounded,
                      color: const Color(0xFFE11D48),
                      title: 'Foto & Gambar',
                      subtitle: 'JPG, PNG, WEBP',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _handlePickAndSendFile(
                          senderEmail: senderEmail,
                          senderName: senderName,
                          senderTag: senderTag,
                          fileType: FileType.image,
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFF2563EB),
                      title: 'Dokumen / PDF',
                      subtitle: 'PDF, DOCX, XLSX',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _handlePickAndSendFile(
                          senderEmail: senderEmail,
                          senderName: senderName,
                          senderTag: senderTag,
                          fileType: FileType.custom,
                          allowedExtensions: [
                            'pdf',
                            'doc',
                            'docx',
                            'xls',
                            'xlsx',
                            'ppt',
                            'pptx',
                            'txt',
                            'csv'
                          ],
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.folder_zip_rounded,
                      color: const Color(0xFFD97706),
                      title: 'File Kompres',
                      subtitle: 'ZIP, RAR, 7Z, TAR',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _handlePickAndSendFile(
                          senderEmail: senderEmail,
                          senderName: senderName,
                          senderTag: senderTag,
                          fileType: FileType.custom,
                          allowedExtensions: ['zip', 'rar', '7z', 'tar', 'gz'],
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.folder_open_rounded,
                      color: const Color(0xFF059669),
                      title: 'Semua Berkas',
                      subtitle: 'Pilih dari HP',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _handlePickAndSendFile(
                          senderEmail: senderEmail,
                          senderName: senderName,
                          senderTag: senderTag,
                          fileType: FileType.any,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
    );
  }

  Future<String?> _showFileCaptionDialog(String filename, int fileSize) async {
    final captionController = TextEditingController();
    final fileIcon = _getFileIcon(filename);
    final fileColor = _getFileColor(filename);
    final formattedSize = ChatMessage(
      id: '',
      senderEmail: '',
      senderName: '',
      senderRole: '',
      text: '',
      timestamp: DateTime.now(),
      expiresAt: DateTime.now(),
      roomId: '',
      fileSize: fileSize,
    ).formattedFileSize;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: fileColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(fileIcon, color: fileColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filename,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedSize.isNotEmpty
                                ? '$formattedSize • Tersimpan ke BaknusDrive'
                                : 'Tersimpan ke BaknusDrive',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: captionController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan / keterangan berkas (opsional)...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, captionController.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Kirim Berkas'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showImageCaptionDialog(String filename) async {
    final captionController = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.image_rounded, color: Color(0xFFE11D48), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kirim Gambar ke Chat',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            filename,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: captionController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Tulis keterangan foto (opsional)...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, captionController.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Kirim Foto'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullImageDialog(String url, String caption) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 24),
                tooltip: 'Buka di Browser / BaknusDrive',
                onPressed: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
            if (caption.isNotEmpty && caption != '📷 Foto')
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNewDirectChatModal(BuildContext context, String currentEmail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewDirectChatModal(
        currentEmail: currentEmail,
        onUserSelected: (email, name, tag) {
          Navigator.pop(ctx);
          _openDirectChat(peerEmail: email, peerName: name, peerTag: tag);
        },
      ),
    );
  }

  void _showInfoDialog(String userTag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 10),
            Text('BaknusChat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BaknusChat beroperasi dalam mode **Chat Pribadi** 1-on-1 antar civitas sekolah.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: UserTagResolver.getTagColor(userTag).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    UserTagResolver.getTagIcon(userTag),
                    color: UserTagResolver.getTagColor(userTag),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Akun Anda terverifikasi sebagai: $userTag',
                    style: TextStyle(
                      color: UserTagResolver.getTagColor(userTag),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFE11D48), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pesan bersifat privat (hanya Anda dan lawan bicara yang bisa membaca).',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pesan otomatis hilang dalam 24 jam untuk menjaga privasi & mencegah penumpukan data.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final baknus = context.watch<BaknusProvider>();

    final user = auth.currentUser;
    final userEmail = user?.email ?? '';
    final rawDisplayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (userEmail.isNotEmpty ? userEmail.split('@').first : 'Pengguna');

    // Dapatkan TAG Mailcow Pengguna dengan Resolver Terintegrasi
    final userTag = UserTagResolver.resolve(
      email: userEmail,
      displayName: rawDisplayName,
      mailboxData: _liveMailboxData,
      fallbackRole: baknus.userRole,
    );

    final isInsideDirectRoom = _activeDirectPeerEmail != null;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: isInsideDirectRoom
            ? _buildDirectChatAppBar(isDark)
            : _buildStandardAppBar(isDark, userTag),
        body: Column(
          children: [
            // ==================== 1. 24-HOUR NOTICE STRIP ====================
            _build24HourNoticeStrip(isDark),

            // ==================== 2. CHAT CONTENT ====================
            Expanded(
              child: isInsideDirectRoom
                  ? _buildMessagesStream(userEmail, isDark)
                  : _buildDirectConversationsList(userEmail, isDark),
            ),

            // ==================== 3. INPUT BAR (HANYA SAAT DALAM ROOM CHAT) ====================
            if (isInsideDirectRoom)
              _buildInputBar(
                isDark: isDark,
                senderEmail: userEmail,
                senderName: rawDisplayName,
                senderTag: userTag,
              ),
          ],
        ),
        floatingActionButton: !isInsideDirectRoom
            ? FloatingActionButton.extended(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                elevation: 3,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: const Text(
                  'Mulai Chat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: () => _showNewDirectChatModal(context, userEmail),
              )
            : null,
      ),
    );
  }

  PreferredSizeWidget _buildStandardAppBar(bool isDark, String userTag) {
    final tagColor = UserTagResolver.getTagColor(userTag);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'BaknusChat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    // TAG Akun Saya Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tagColor, width: 0.8),
                      ),
                      child: Text(
                        'TAG: $userTag',
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Pesan Pribadi • 24 Jam',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          tooltip: 'Info Privasi & 24 Jam',
          onPressed: () => _showInfoDialog(userTag),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildDirectChatAppBar(bool isDark) {
    final peerTagColor = UserTagResolver.getTagColor(_activeDirectPeerTag ?? 'Siswa');

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          setState(() {
            _activeDirectPeerEmail = null;
            _activeDirectPeerName = null;
            _activeDirectPeerTag = null;
          });
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          UserAvatar(
            email: _activeDirectPeerEmail ?? '',
            name: _activeDirectPeerName ?? '',
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _activeDirectPeerName ?? 'Chat Pribadi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: peerTagColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: peerTagColor, width: 0.8),
                      ),
                      child: Text(
                        _activeDirectPeerTag ?? 'Siswa',
                        style: TextStyle(
                          color: peerTagColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Icon(Icons.chat_bubble_rounded, size: 10, color: Color(0xFFE11D48)),
                    SizedBox(width: 3),
                    Text(
                      'Pesan Pribadi • 24 Jam',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFE11D48),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build24HourNoticeStrip(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE11D48).withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 14,
            color: Color(0xFFE11D48),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Obrolan privat antar 2 akun. Pesan otomatis hilang dalam 24 jam.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFBE123C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectConversationsList(String currentEmail, bool isDark) {
    return Column(
      children: [
        // Search filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: 'Cari percakapan aktif...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _filterController.clear();
                          setState(() => _searchFilter = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
              onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<DirectConversationItem>>(
            stream: _chatService.getDirectConversationsStream(currentEmail),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final list = snapshot.data ?? [];
              final filtered = list.where((item) {
                if (_searchFilter.isEmpty) return true;
                return item.peerName.toLowerCase().contains(_searchFilter) ||
                    item.peerEmail.toLowerCase().contains(_searchFilter) ||
                    item.lastMessage.toLowerCase().contains(_searchFilter);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 42,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _searchFilter.isEmpty
                              ? 'Belum Ada Obrolan'
                              : 'Percakapan tidak ditemukan',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchFilter.isEmpty
                              ? 'Mulai obrolan 1-on-1 dengan guru, staff TU, atau siswa lain. Pesan otomatis hilang dalam 24 jam.'
                              : 'Coba kata kunci lain atau mulai chat baru dengan kontak sekolah.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE11D48),
                            side: const BorderSide(color: Color(0xFFE11D48)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.person_search_rounded, size: 16),
                          label: const Text('Cari Kontak Sekolah'),
                          onPressed: () => _showNewDirectChatModal(context, currentEmail),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final tagColor = UserTagResolver.getTagColor(item.peerTag);

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      _openDirectChat(
                        peerEmail: item.peerEmail,
                        peerName: item.peerName,
                        peerTag: item.peerTag,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            email: item.peerEmail,
                            name: item.peerName,
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.peerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: tagColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              item.peerTag,
                                              style: TextStyle(
                                                color: tagColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (item.unreadCount > 0) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE11D48),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${item.unreadCount}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.lastMessage,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesStream(String userEmail, bool isDark) {
    final targetRoomId =
        ChatService.getPrivateRoomId(userEmail, _activeDirectPeerEmail!);

    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getMessagesStream(targetRoomId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal memuat pesan: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];

        // Otomatis tandai pesan masuk sebagai 'dibaca' secara real-time saat pengguna berada di dalam room
        final hasUnreadIncoming = messages.any(
          (m) => m.senderEmail.toLowerCase() != userEmail.toLowerCase() && !m.isRead,
        );
        if (hasUnreadIncoming) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _chatService.markRoomMessagesAsRead(
              roomId: targetRoomId,
              readerEmail: userEmail,
            );
          });
        }

        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 44,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Mulai obrolan dengan ${_activeDirectPeerName ?? "kontak"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pesan japri bersifat rahasia dan akan terhapus otomatis dalam 24 jam.',
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

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderEmail.toLowerCase() == userEmail.toLowerCase();
            return _buildMessageBubble(
              message: message,
              isMe: isMe,
              isDark: isDark,
              currentEmail: userEmail,
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryStatus(ChatMessage message) {
    if (message.isPending) {
      return const Tooltip(
        message: 'Pending (Sedang mengirim...)',
        child: Icon(
          Icons.access_time_rounded,
          size: 11,
          color: Colors.white70,
        ),
      );
    }

    if (message.isRead) {
      return const Tooltip(
        message: 'Dibaca',
        child: Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Color(0xFF38BDF8), // WhatsApp Blue Tick style
        ),
      );
    }

    // Terkirim (Tersimpan di server)
    return const Tooltip(
      message: 'Terkirim',
      child: Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildMessageBubble({
    required ChatMessage message,
    required bool isMe,
    required bool isDark,
    required String currentEmail,
  }) {
    // Tentukan warna tag pengirim (Guru / TU / Siswa)
    final roleTag = message.senderRole.isNotEmpty ? message.senderRole : 'Siswa';
    final roleBadgeColor = UserTagResolver.getTagColor(roleTag);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            UserAvatar(
              email: message.senderEmail,
              name: message.senderName,
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                _showMessageOptions(message, isMe, currentEmail);
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe
                      ? null
                      : (isDark ? AppColors.darkSurfaceElevated : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender info + TAG Badge (Siswa, Guru, TU)
                    if (!isMe) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              message.senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: roleBadgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleTag,
                              style: TextStyle(
                                color: roleBadgeColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Image, File (Document/Archive), or Text Content
                    if (message.isImage)
                      _buildImageBubbleContent(message, isMe, isDark)
                    else if (message.isFile)
                      _buildFileBubbleContent(message, isMe, isDark)
                    else
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isMe
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Timestamp, Remaining Expiry Pill & Status Pengiriman
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.timeFormatted,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white70
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 9,
                                color: isMe ? Colors.white70 : Colors.grey,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                message.remainingTimeFormatted,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isMe
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 5),
                          _buildDeliveryStatus(message),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  void _showMessageOptions(ChatMessage message, bool isMe, String currentEmail) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe) ...[
              if (message.isRead && message.readAt != null)
                ListTile(
                  leading: const Icon(Icons.done_all_rounded, color: Color(0xFF38BDF8)),
                  title: const Text('Status: Sudah Dibaca'),
                  subtitle: Text(
                    'Dibaca pada ${message.readAt!.hour.toString().padLeft(2, '0')}:${message.readAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                )
              else if (!message.isPending)
                const ListTile(
                  leading: Icon(Icons.done_all_rounded, color: Colors.grey),
                  title: Text('Status: Terkirim'),
                  subtitle: Text(
                    'Pesan sudah tersimpan di server, menunggu dibuka oleh penerima.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Salin Teks'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Teks disalin ke clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text(
                  'Hapus Pesan Saya',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final targetRoomId =
                      ChatService.getPrivateRoomId(currentEmail, _activeDirectPeerEmail!);

                  final success =
                      await _chatService.deleteMessage(targetRoomId, message.id, currentEmail);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pesan berhasil dihapus')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description_rounded;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) return Icons.table_chart_rounded;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return Icons.slideshow_rounded;
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || lower.endsWith('.tar') || lower.endsWith('.gz')) return Icons.folder_zip_rounded;
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return Icons.article_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFEF4444);
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return const Color(0xFF2563EB);
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) return const Color(0xFF10B981);
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return const Color(0xFFF97316);
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || lower.endsWith('.tar') || lower.endsWith('.gz')) return const Color(0xFFD97706);
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return const Color(0xFF0D9488);
    return const Color(0xFF6366F1);
  }

  Widget _buildFileBubbleContent(ChatMessage message, bool isMe, bool isDark) {
    final fileUrl = message.effectiveFileUrl;
    final filename = message.fileName ?? message.text.replaceFirst(RegExp(r'^[📄📦📷]\s*'), '');
    final fileIcon = _getFileIcon(filename);
    final fileColor = _getFileColor(filename);

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            if (fileUrl.isNotEmpty) {
              final uri = Uri.parse(fileUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.15)
                  : (isDark ? Colors.black26 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.3)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.25)
                        : fileColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    fileIcon,
                    color: isMe ? Colors.white : fileColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filename,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isMe
                              ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            message.formattedFileSize.isNotEmpty
                                ? message.formattedFileSize
                                : 'BaknusDrive',
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe
                                  ? Colors.white70
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• Buka',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isMe ? Colors.white60 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: isMe ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (message.text.isNotEmpty &&
            message.text != filename &&
            !message.text.startsWith('📄') &&
            !message.text.startsWith('📦')) ...[
          const SizedBox(height: 6),
          Text(
            message.text,
            style: TextStyle(
              fontSize: 13.5,
              color: isMe
                  ? Colors.white
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageBubbleContent(ChatMessage message, bool isMe, bool isDark) {
    final imgUrl = message.imageUrl ?? '';
    if (imgUrl.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showFullImageDialog(imgUrl, message.text),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 220,
                maxWidth: 240,
              ),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 160,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 130,
                        padding: const EdgeInsets.all(12),
                        color: Colors.black12,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, color: Colors.grey, size: 30),
                            SizedBox(height: 4),
                            Text('Gagal memuat gambar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (message.text.isNotEmpty && message.text != '📷 Foto') ...[
          const SizedBox(height: 6),
          Text(
            message.text,
            style: TextStyle(
              fontSize: 13.5,
              color: isMe
                  ? Colors.white
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputBar({
    required bool isDark,
    required String senderEmail,
    required String senderName,
    required String senderTag,
  }) {
    return Container(
      padding: EdgeInsets.only(
        left: 10,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Tombol Pilih Berkas (Foto / Dokumen / ZIP)
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: Color(0xFFE11D48)),
            tooltip: 'Kirim Berkas (BaknusDrive)',
            onPressed: _isSending
                ? null
                : () => _showAttachmentPickerMenu(
                      senderEmail: senderEmail,
                      senderName: senderName,
                      senderTag: senderTag,
                    ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                maxLength: 500,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Pesan pribadi ke ${_activeDirectPeerName ?? "kontak"}...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _handleSendMessage(
                  senderEmail: senderEmail,
                  senderName: senderName,
                  senderTag: senderTag,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFFE11D48),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _isSending
                  ? null
                  : () => _handleSendMessage(
                        senderEmail: senderEmail,
                        senderName: senderName,
                        senderTag: senderTag,
                      ),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Pencarian Kontak Sekolah untuk Memulai Japri Baru
class _NewDirectChatModal extends StatefulWidget {
  final String currentEmail;
  final Function(String email, String name, String tag) onUserSelected;

  const _NewDirectChatModal({
    required this.currentEmail,
    required this.onUserSelected,
  });

  @override
  State<_NewDirectChatModal> createState() => _NewDirectChatModalState();
}

class _NewDirectChatModalState extends State<_NewDirectChatModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _mailboxes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMailboxes();
  }

  Future<void> _loadMailboxes() async {
    final apiService = context.read<MailcowApiService>();
    try {
      final list = await apiService.getAllMailboxes();
      if (mounted) {
        setState(() {
          _mailboxes = list.where((m) {
            final email = (m['username'] ?? m['email'] ?? '').toString().toLowerCase();
            return email.isNotEmpty && email != widget.currentEmail.toLowerCase();
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _mailboxes.where((m) {
      final email = (m['username'] ?? m['email'] ?? '').toString().toLowerCase();
      final name = (m['name'] ?? '').toString().toLowerCase();
      return email.contains(_searchQuery.toLowerCase()) ||
          name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.person_search_rounded, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text(
                'Mulai Chat Pribadi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Input Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Cari nama atau email rekan sekolah...',
                hintStyle: TextStyle(fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const SizedBox(height: 14),

          // Custom Input Option jika email tidak ada di list
          if (_searchQuery.contains('@'))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: const Icon(Icons.send_rounded, color: Color(0xFFE11D48)),
                title: Text('Chat langsung ke "$_searchQuery"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Kirim pesan ke alamat ini',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  final tag = UserTagResolver.resolve(email: _searchQuery, displayName: '');
                  widget.onUserSelected(_searchQuery, _searchQuery.split('@').first, tag);
                },
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Memuat direktori kontak...'
                              : 'Tidak ditemukan kontak dengan nama tersebut.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          final email = (m['username'] ?? m['email'] ?? '').toString();
                          final name = (m['name']?.toString().isNotEmpty == true)
                              ? m['name'].toString()
                              : email.split('@').first;
                          // Resolusi TAG akurat berdasarkan data mailbox Mailcow
                          final tag = UserTagResolver.resolve(
                            email: email,
                            displayName: name,
                            mailboxData: m,
                          );
                          final tagColor = UserTagResolver.getTagColor(tag);

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: UserAvatar(email: email, name: name, radius: 20),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: tagColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      color: tagColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(email, style: const TextStyle(fontSize: 11.5)),
                            trailing: const Icon(Icons.chat_bubble_outline_rounded,
                                size: 18, color: Color(0xFFE11D48)),
                            onTap: () => widget.onUserSelected(email, name, tag),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
