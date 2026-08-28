import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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
import '../widgets/story_viewer_dialog.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/user_avatar.dart';
import '../widgets/typing_indicator_widget.dart';
import '../widgets/voice_note_player_widget.dart';
import '../widgets/rich_link_preview_widget.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/group_info_dialog.dart';
import '../widgets/sticker_picker_dialog.dart';
import '../../data/models/custom_group.dart';
import '../../data/models/story_item.dart';
import '../../data/services/story_service.dart';
import '../widgets/room_media_gallery_dialog.dart';
import '../widgets/starred_messages_dialog.dart';
import '../widgets/baknus_drive_picker_dialog.dart';
import '../widgets/forward_message_dialog.dart';
import '../widgets/chat_backup_dialog.dart';
import '../widgets/linked_devices_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/utils/format_helper.dart';
import '../../data/models/jamendo_music.dart';
import '../widgets/jamendo_music_picker_dialog.dart';

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

class _BaknusChatScreenState extends State<BaknusChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final StoryService _storyService = StoryService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();

  // State untuk Chat Pribadi (Japri) & Grup Obrolan & Navigasi Tab Utama
  String? _activeDirectPeerEmail;
  String? _activeDirectPeerName;
  String? _activeDirectPeerTag;
  CustomGroup? _activeCustomGroup;
  int _selectedMainTabIndex = 0; // 0: Japri, 1: Grup, 2: Status

  // State untuk BaknusChat Web QR pairing
  String? _webSessionId;
  BaknusWebSession? _authenticatedWebSession;

  Map<String, dynamic>? _liveMailboxData;
  bool _isSending = false;
  String _searchFilter = '';
  int _messageLimit = 50;

  // Interaksi Obrolan State (Reply, Edit & Typing)
  ChatMessage? _replyToMessage;
  ChatMessage? _editingMessage;
  Timer? _typingTimer;

  // Voice Note Recording State (Max 10 Detik)
  late final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _recordDurationSec = 0;
  Timer? _recordTimer;
  String? _voicePath;

  Future<void> _startVoiceRecording() async {
    if (_isRecordingVoice) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _voicePath = '${tempDir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _voicePath!,
        );

        setState(() {
          _isRecordingVoice = true;
          _recordDurationSec = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          setState(() {
            _recordDurationSec++;
          });

          // Otomatis stop & send jika mencapai batas max 10 detik!
          if (_recordDurationSec >= 10) {
            _stopAndSendVoiceRecording();
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon diperlukan untuk merekam pesan suara.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    if (!_isRecordingVoice) return;

    _recordTimer?.cancel();
    final duration = _recordDurationSec;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecordingVoice = false;
        _recordDurationSec = 0;
      });

      if (path != null && path.isNotEmpty && duration > 0) {
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        final email = auth.currentUser?.email ?? '';
        final name = auth.currentUser?.displayName ?? 'Pengguna';
        final role = UserTagResolver.resolve(email: email, displayName: name);

        final String roomId;
        final String? rEmail;
        final String? rName;
        final String? rTag;

        if (_activeCustomGroup != null) {
          roomId = _activeCustomGroup!.id;
          rEmail = null;
          rName = null;
          rTag = null;
        } else if (_activeDirectPeerEmail != null && _activeDirectPeerEmail!.isNotEmpty) {
          roomId = ChatService.getPrivateRoomId(email, _activeDirectPeerEmail!);
          rEmail = _activeDirectPeerEmail;
          rName = _activeDirectPeerName;
          rTag = _activeDirectPeerTag;
        } else {
          return;
        }

        setState(() => _isSending = true);

        await _chatService.sendVoiceNoteMessage(
          roomId: roomId,
          filePath: path,
          durationSec: duration,
          senderEmail: email,
          senderName: name,
          senderRole: role,
          recipientEmail: rEmail,
          recipientName: rName,
          recipientTag: rTag,
          replyToId: _replyToMessage?.id,
          replyToSenderName: _replyToMessage?.senderName,
          replyToText: _replyToMessage?.text,
        );

        setState(() => _replyToMessage = null);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pesan suara: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecordingVoice) return;
    _recordTimer?.cancel();
    try {
      await _audioRecorder.stop();
      if (_voicePath != null) {
        final file = File(_voicePath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    setState(() {
      _isRecordingVoice = false;
      _recordDurationSec = 0;
    });
  }

  void _onTextChanged(String text) {
    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? '';
    final name = auth.currentUser?.displayName ?? '';
    if (email.isEmpty || _activeDirectPeerEmail == null) return;
    final roomId = ChatService.getPrivateRoomId(email, _activeDirectPeerEmail!);

    _chatService.setTypingStatus(
      roomId: roomId,
      userEmail: email,
      userName: name,
      isTyping: text.trim().isNotEmpty,
    );

    _typingTimer?.cancel();
    if (text.trim().isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.setTypingStatus(
          roomId: roomId,
          userEmail: email,
          userName: name,
          isTyping: false,
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialDirectPeerEmail != null) {
      _activeDirectPeerEmail = widget.initialDirectPeerEmail;
      _activeDirectPeerName =
          widget.initialDirectPeerName ?? widget.initialDirectPeerEmail!.split('@').first;
      _activeDirectPeerTag = widget.initialDirectPeerTag ?? 'Siswa';
    }

    // Ambil data mailbox Mailcow secara live untuk deteksi TAG yang 100% akurat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLiveMailboxInfo();
      _updateCurrentPresence(true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateCurrentPresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _updateCurrentPresence(false);
    }
  }

  void _updateCurrentPresence(bool isOnline) {
    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? '';
    if (email.isNotEmpty) {
      _chatService.updateUserPresence(email, isOnline);
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _updateCurrentPresence(false);
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _audioRecorder.dispose();
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
      _activeCustomGroup = null;
      _activeDirectPeerEmail = cleanPeer;
      _activeDirectPeerName = peerName;
      _activeDirectPeerTag = peerTag;
    });
  }

  Future<void> _openStarredMessageRoom(ChatMessage msg) async {
    final auth = context.read<AuthProvider>();
    final userEmail = (auth.currentUser?.email ?? '').toLowerCase().trim();

    if (msg.roomId == 'publik' || msg.roomId.isEmpty) {
      setState(() {
        _activeDirectPeerEmail = null;
        _activeCustomGroup = null;
      });
      return;
    }

    if (!msg.roomId.startsWith('dm_') && !msg.roomId.startsWith('private_')) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('baknus_custom_groups')
            .doc(msg.roomId)
            .get();
        if (doc.exists) {
          final group = CustomGroup.fromFirestore(doc);
          setState(() {
            _activeDirectPeerEmail = null;
            _activeCustomGroup = group;
          });
          return;
        }
      } catch (e) {
        debugPrint('Error opening starred group: $e');
      }
      setState(() {
        _activeDirectPeerEmail = null;
        _activeCustomGroup = null;
      });
      return;
    }

    String peerEmail = '';
    String peerName = 'Pengguna';
    String peerTag = 'Siswa';

    final senderClean = msg.senderEmail.toLowerCase().trim();
    if (senderClean.isNotEmpty && senderClean != userEmail) {
      peerEmail = senderClean;
      peerName = msg.senderName;
      peerTag = msg.senderRole;
    } else {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('baknus_chat_direct_conversations')
            .doc(userEmail)
            .collection('peers')
            .get();

        for (final doc in snap.docs) {
          final pEmail = (doc.data()['peerEmail']?.toString() ?? doc.id).toLowerCase().trim();
          if (ChatService.getPrivateRoomId(userEmail, pEmail) == msg.roomId) {
            peerEmail = pEmail;
            peerName = doc.data()['peerName']?.toString() ?? pEmail.split('@').first;
            peerTag = doc.data()['peerTag']?.toString() ?? 'Siswa';
            break;
          }
        }
      } catch (e) {
        debugPrint('Error looking up peer for starred DM: $e');
      }
    }

    if (peerEmail.isNotEmpty) {
      _openDirectChat(
        peerEmail: peerEmail,
        peerName: peerName,
        peerTag: peerTag,
      );
    }
  }

  Future<void> _handleSendMessage({
    required String senderEmail,
    required String senderName,
    required String senderTag,
  }) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final String targetRoomId;
    final String? rEmail;
    final String? rName;
    final String? rTag;

    if (_activeCustomGroup != null) {
      targetRoomId = _activeCustomGroup!.id;
      rEmail = null;
      rName = null;
      rTag = null;
    } else if (_activeDirectPeerEmail != null && _activeDirectPeerEmail!.isNotEmpty) {
      targetRoomId = ChatService.getPrivateRoomId(senderEmail, _activeDirectPeerEmail!);
      rEmail = _activeDirectPeerEmail;
      rName = _activeDirectPeerName;
      rTag = _activeDirectPeerTag;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kontak atau grup tujuan terlebih dahulu.')),
      );
      return;
    }

    if (_editingMessage != null) {
      final msgToEdit = _editingMessage!;
      setState(() => _isSending = true);
      _textController.clear();

      try {
        final success = await _chatService.editMessage(
          roomId: targetRoomId,
          messageId: msgToEdit.id,
          newText: text,
          userEmail: senderEmail,
        );
        if (mounted && success) {
          setState(() {
            _editingMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pesan berhasil diperbarui'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengedit pesan: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
        }
      }
      return;
    }

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await _chatService.sendMessage(
        roomId: targetRoomId,
        text: text,
        senderEmail: senderEmail,
        senderName: senderName,
        senderRole: senderTag,
        recipientEmail: rEmail,
        recipientName: rName,
        recipientTag: rTag,
        replyToId: _replyToMessage?.id,
        replyToSenderName: _replyToMessage?.senderName,
        replyToText: _replyToMessage?.text,
      );
      if (mounted) {
        setState(() => _replyToMessage = null);
      }
      _chatService.setTypingStatus(
        roomId: targetRoomId,
        userEmail: senderEmail,
        userName: senderName,
        isTyping: false,
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
    final String targetRoomId;
    final String? rEmail;
    final String? rName;
    final String? rTag;

    if (_activeCustomGroup != null) {
      targetRoomId = _activeCustomGroup!.id;
      rEmail = null;
      rName = null;
      rTag = null;
    } else if (_activeDirectPeerEmail != null && _activeDirectPeerEmail!.isNotEmpty) {
      targetRoomId = ChatService.getPrivateRoomId(senderEmail, _activeDirectPeerEmail!);
      rEmail = _activeDirectPeerEmail;
      rName = _activeDirectPeerName;
      rTag = _activeDirectPeerTag;
    } else {
      return;
    }

    if (_isSending) return;

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
        recipientEmail: rEmail,
        recipientName: rName,
        recipientTag: rTag,
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

  Future<void> _handleCaptureAndSendPhoto({
    required String senderEmail,
    required String senderName,
    required String senderTag,
  }) async {
    final String targetRoomId;
    final String? rEmail;
    final String? rName;
    final String? rTag;

    if (_activeCustomGroup != null) {
      targetRoomId = _activeCustomGroup!.id;
      rEmail = null;
      rName = null;
      rTag = null;
    } else if (_activeDirectPeerEmail != null && _activeDirectPeerEmail!.isNotEmpty) {
      targetRoomId = ChatService.getPrivateRoomId(senderEmail, _activeDirectPeerEmail!);
      rEmail = _activeDirectPeerEmail;
      rName = _activeDirectPeerName;
      rTag = _activeDirectPeerTag;
    } else {
      return;
    }

    if (_isSending) return;

    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo == null) return; // Dibatalkan oleh pengguna

      final filePath = photo.path;
      final fileBytes = await photo.readAsBytes();
      final timestampStr = DateTime.now().millisecondsSinceEpoch;
      final filename = 'IMG_$timestampStr.jpg';
      final fileSize = fileBytes.length;

      final caption = await _showFileCaptionDialog(filename, fileSize);
      if (caption == null) return; // Dibatalkan oleh pengguna

      setState(() => _isSending = true);

      await _chatService.sendFileMessage(
        roomId: targetRoomId,
        senderEmail: senderEmail,
        senderName: senderName,
        senderRole: senderTag,
        caption: caption.isEmpty ? '📷 Foto Kamera' : caption,
        filePath: filePath,
        fileBytes: fileBytes,
        filename: filename,
        fileSize: fileSize,
        recipientEmail: rEmail,
        recipientName: rName,
        recipientTag: rTag,
      );

      _scrollToBottom();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto kamera berhasil dikirim & tersimpan di BaknusDrive!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil/mengirim foto kamera: $e'),
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

  void _showStickerPickerSheet({
    required String senderEmail,
    required String senderName,
    required String senderTag,
  }) {
    final String targetRoomId;
    final String? rEmail;
    final String? rName;
    final String? rTag;

    if (_activeCustomGroup != null) {
      targetRoomId = _activeCustomGroup!.id;
      rEmail = null;
      rName = null;
      rTag = null;
    } else if (_activeDirectPeerEmail != null && _activeDirectPeerEmail!.isNotEmpty) {
      targetRoomId = ChatService.getPrivateRoomId(senderEmail, _activeDirectPeerEmail!);
      rEmail = _activeDirectPeerEmail;
      rName = _activeDirectPeerName;
      rTag = _activeDirectPeerTag;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kontak atau grup tujuan terlebih dahulu.')),
      );
      return;
    }

    StickerPickerDialog.show(
      context,
      onStickerSelected: (sticker) async {
        setState(() => _isSending = true);
        try {
          await _chatService.sendStickerMessage(
            roomId: targetRoomId,
            stickerUrl: sticker.imageUrl,
            stickerName: sticker.name,
            senderEmail: senderEmail,
            senderName: senderName,
            senderRole: senderTag,
            recipientEmail: rEmail,
            recipientName: rName,
            recipientTag: rTag,
          );
          _scrollToBottom();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal mengirim stiker: $e'), backgroundColor: AppColors.error),
            );
          }
        } finally {
          if (mounted) setState(() => _isSending = false);
        }
      },
      onCustomStickerSelected: (xFile) async {
        final filePath = xFile.path;
        final fileBytes = await xFile.readAsBytes();
        final timestampStr = DateTime.now().millisecondsSinceEpoch;
        final filename = 'STICKER_$timestampStr.png';

        setState(() => _isSending = true);
        try {
          await _chatService.sendFileMessage(
            roomId: targetRoomId,
            senderEmail: senderEmail,
            senderName: senderName,
            senderRole: senderTag,
            caption: '🏷️ Stiker Kustom',
            filePath: filePath,
            fileBytes: fileBytes,
            filename: filename,
            fileSize: fileBytes.length,
            recipientEmail: rEmail,
            recipientName: rName,
            recipientTag: rTag,
          );
          _scrollToBottom();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal mengirim stiker kustom: $e'), backgroundColor: AppColors.error),
            );
          }
        } finally {
          if (mounted) setState(() => _isSending = false);
        }
      },
    );
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
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFF0284C7),
                      title: 'Kamera HP',
                      subtitle: 'Foto Langsung',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleCaptureAndSendPhoto(
                          senderEmail: senderEmail,
                          senderName: senderName,
                          senderTag: senderTag,
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.image_rounded,
                      color: const Color(0xFFE11D48),
                      title: 'Galeri Foto',
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
                      subtitle: 'Pilih dari Perangkat',
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
                    _buildAttachmentOption(
                      icon: Icons.cloud_circle_rounded,
                      color: const Color(0xFF2563EB),
                      title: 'BaknusDrive',
                      subtitle: 'Pilih Berkas Cloud',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        final targetRoomId = _activeCustomGroup?.id ??
                            (_activeDirectPeerEmail != null
                                ? ChatService.getPrivateRoomId(senderEmail, _activeDirectPeerEmail!)
                                : 'publik');
                        BaknusDrivePickerDialog.show(
                          context,
                          userEmail: senderEmail,
                          onFileSelected: (fileName, fileUrl, fileSize, type) {
                            _chatService.sendDocumentFileMessage(
                              roomId: targetRoomId,
                              fileUrl: fileUrl,
                              filename: fileName,
                              fileSize: fileSize,
                              mimeType: type,
                              senderEmail: senderEmail,
                              senderName: senderName,
                              senderRole: senderTag,
                            );
                          },
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
                    'Chat tersimpan secara permanen dan aman. Anda dapat menghapus pesan kapan saja secara manual.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel_outlined, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tata Tertib & Audit IT: Layanan ini adalah fasilitas resmi sekolah. Pihak manajemen sekolah berhak melakukan audit obrolan demi menjaga ketertiban, etika, dan mencegah perundungan.',
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

    // Jika dibuka di browser web dan belum diautentikasi lewat QR Mobile
    if (kIsWeb && _authenticatedWebSession == null && userEmail.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildWebQrLoginScreen(isDark),
      );
    }

    final isInsideRoom = _activeDirectPeerEmail != null || _activeCustomGroup != null;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _activeCustomGroup != null
            ? _buildGroupChatAppBar(isDark)
            : (_activeDirectPeerEmail != null
                ? _buildDirectChatAppBar(isDark, userEmail)
                : _buildStandardAppBar(isDark, userTag, userEmail)),
        body: Column(
          children: [
            // ==================== 1. 24-HOUR NOTICE STRIP ====================
            _build24HourNoticeStrip(isDark),

            // ==================== 2. TAB NAVIGASI UTAMA (Japri, Grup, Status) ====================
            if (!isInsideRoom) _buildMainTabSegmentedBar(isDark),

            // ==================== 3. CHAT CONTENT BERDASARKAN TAB ====================
            Expanded(
              child: isInsideRoom
                  ? _buildMessagesStream(userEmail, isDark)
                  : (_selectedMainTabIndex == 0
                      ? _buildDirectConversationsList(userEmail, isDark)
                      : (_selectedMainTabIndex == 1
                          ? _buildGroupsListTab(userEmail, isDark)
                          : _buildStatusTabFullView(
                              currentEmail: userEmail,
                              currentName: rawDisplayName,
                              currentTag: userTag,
                              isDark: isDark,
                            ))),
            ),

            // ==================== 4. INPUT BAR (HANYA SAAT DALAM ROOM CHAT) ====================
            if (isInsideRoom)
              _buildInputBar(
                isDark: isDark,
                senderEmail: userEmail,
                senderName: rawDisplayName,
                senderTag: userTag,
              ),
          ],
        ),
        floatingActionButton: !isInsideRoom
            ? (_selectedMainTabIndex == 0
                ? FloatingActionButton.extended(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text(
                      'Mulai Japri',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: () => _showNewDirectChatModal(context, userEmail),
                  )
                : (_selectedMainTabIndex == 1
                    ? FloatingActionButton.extended(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        icon: const Icon(Icons.group_add_rounded, size: 20),
                        label: const Text(
                          'Buat Grup Baru',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        onPressed: () {
                          CreateGroupDialog.show(
                            context,
                            onGroupCreated: () => setState(() {}),
                          );
                        },
                      )
                    : FloatingActionButton.extended(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        icon: const Icon(Icons.add_a_photo_rounded, size: 20),
                        label: const Text(
                          'Status Baru',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        onPressed: () => _showCreateStoryModal(
                          currentEmail: userEmail,
                          currentName: rawDisplayName,
                          currentTag: userTag,
                        ),
                      )))
            : null,
      ),
    );
  }

  Widget _buildMainTabSegmentedBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTabSegmentItem(
            index: 0,
            icon: Icons.chat_bubble_rounded,
            label: 'Japri',
            isDark: isDark,
          ),
          _buildTabSegmentItem(
            index: 1,
            icon: Icons.groups_rounded,
            label: 'Grup',
            isDark: isDark,
          ),
          _buildTabSegmentItem(
            index: 2,
            icon: Icons.circle_notifications_rounded,
            label: 'Status',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabSegmentItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedMainTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMainTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkSurface : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFFE11D48)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initWebQrSession() {
    if (_webSessionId != null) return;
    _chatService.createWebQrSession().then((id) {
      if (mounted) {
        setState(() {
          _webSessionId = id;
        });
      }
    });
  }

  Widget _buildWebQrLoginScreen(bool isDark) {
    if (_webSessionId == null) {
      _initWebQrSession();
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<BaknusWebSession?>(
      stream: _chatService.streamWebQrSession(_webSessionId!),
      builder: (context, snapshot) {
        final session = snapshot.data;

        if (session != null && session.status == 'authenticated' && session.userEmail != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_authenticatedWebSession?.sessionId != session.sessionId) {
              setState(() {
                _authenticatedWebSession = session;
              });
            }
          });
        }

        if (session != null && (session.status == 'expired' || session.status == 'revoked')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _webSessionId = null;
            });
          });
        }

        return Container(
          color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 860),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset('assets/images/app_logo.png', width: 44, height: 44),
                              const SizedBox(width: 12),
                              Text(
                                'BaknusChat Web',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Gunakan BaknusChat di Komputer Anda:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildInstructionStep('1', 'Buka aplikasi BaknusID di HP Anda'),
                          const SizedBox(height: 12),
                          _buildInstructionStep('2', 'Ketuk Menu [⋮] di pojok kanan atas BaknusChat'),
                          const SizedBox(height: 12),
                          _buildInstructionStep('3', 'Pilih Perangkat Tertaut lalu ketuk Tautkan Perangkat'),
                          const SizedBox(height: 12),
                          _buildInstructionStep('4', 'Arahkan kamera HP ke layar ini untuk melakukan scan'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300, width: 2),
                            ),
                            child: QrImageView(
                              data: _webSessionId!,
                              version: QrVersions.auto,
                              size: 220.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sync_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'QR Code memperbarui secara real-time',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(String stepNumber, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE11D48),
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildStandardAppBar(bool isDark, String userTag, String userEmail) {
    final tagColor = UserTagResolver.getTagColor(userTag);
    final auth = context.read<AuthProvider>();
    final rawDisplayName = auth.currentUser?.displayName.isNotEmpty == true
        ? auth.currentUser!.displayName
        : (userEmail.isNotEmpty ? userEmail.split('@').first : 'Pengguna');

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 12,
      title: Row(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BaknusChat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: tagColor, width: 0.8),
                      ),
                      child: Text(
                        userTag,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Obrolan Resmi Sekolah',
                  style: TextStyle(
                    fontSize: 10.5,
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
      actions: [
        IconButton(
          icon: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981)),
          tooltip: 'Backup & Restore BaknusChat',
          onPressed: () {
            ChatBackupDialog.show(context, userEmail);
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          tooltip: 'Menu Opsi Chat',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (value) {
            if (value == 'starred') {
              StarredMessagesDialog.show(
                context,
                userEmail: userEmail,
                onMessageTap: (msg) => _openStarredMessageRoom(msg),
              );
            } else if (value == 'create_group') {
              CreateGroupDialog.show(
                context,
                onGroupCreated: () => setState(() {}),
              );
            } else if (value == 'linked_devices') {
              LinkedDevicesDialog.show(
                context,
                userEmail: userEmail,
                userName: rawDisplayName,
                userRole: userTag,
              );
            } else if (value == 'info') {
              _showInfoDialog(userTag);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'linked_devices',
              child: Row(
                children: [
                  Icon(Icons.devices_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Text('Perangkat Tertaut'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'starred',
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Text('Pesan Berbintang'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'create_group',
              child: Row(
                children: [
                  Icon(Icons.group_add_rounded, color: Color(0xFFE11D48), size: 20),
                  SizedBox(width: 10),
                  Text('Buat Grup Baru'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Text('Tata Tertib Obrolan'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildGroupChatAppBar(bool isDark) {
    final group = _activeCustomGroup!;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          setState(() {
            _activeCustomGroup = null;
          });
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_rounded, color: Color(0xFFE11D48), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${group.members.length} Anggota • Oleh ${group.creatorName}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.perm_media_rounded, color: Color(0xFFE11D48)),
          tooltip: 'Galeri Media & Dokumen',
          onPressed: () {
            RoomMediaGalleryDialog.show(
              context,
              roomId: group.id,
              roomTitle: group.name,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          tooltip: 'Detail & Anggota Grup',
          onPressed: () {
            GroupInfoDialog.show(
              context,
              group: group,
              onGroupUpdated: () {
                setState(() {});
              },
            );
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _buildDirectChatAppBar(bool isDark, String userEmail) {
    final peerEmail = _activeDirectPeerEmail ?? '';
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
      title: InkWell(
        onTap: () {
          _showUserProfileDialog(
            peerEmail: peerEmail,
            peerName: _activeDirectPeerName ?? 'Chat Pribadi',
            peerTag: _activeDirectPeerTag ?? 'Siswa',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: StreamBuilder<UserPresence>(
            stream: _chatService.getUserPresenceStream(peerEmail),
            builder: (context, presenceSnap) {
          final isOnline = presenceSnap.data?.isOnline ?? false;

          return Row(
            children: [
              Stack(
                children: [
                  UserAvatar(
                    email: peerEmail,
                    name: _activeDirectPeerName ?? '',
                    radius: 18,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 7,
                          color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline
                              ? 'Sedang Online'
                              : FormatHelper.formatLastSeen(presenceSnap.data?.lastSeen),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isOnline ? const Color(0xFF10B981) : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
  actions: [
        IconButton(
          icon: const Icon(Icons.perm_media_rounded, color: Color(0xFFE11D48)),
          tooltip: 'Galeri Media & Dokumen',
          onPressed: () {
            final roomId = ChatService.getPrivateRoomId(userEmail, peerEmail);
            final title = _activeDirectPeerName ?? 'Chat Pribadi';
            RoomMediaGalleryDialog.show(
              context,
              roomId: roomId,
              roomTitle: title,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          tooltip: 'Hapus Percakapan Ini',
          onPressed: () => _confirmAndDeleteDirectConversation(
            userEmail,
            peerEmail,
            _activeDirectPeerName ?? 'Pengguna',
          ),
        ),
      ],
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
              'Silahkan Chat dengan mematuhi tatakrama dan kebijakan etika yang berlaku',
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
                              ? 'Mulai obrolan 1-on-1 dengan guru, staff TU, atau siswa lain. Chat tersimpan secara permanen.'
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

                  return StreamBuilder<UserPresence>(
                    stream: _chatService.getUserPresenceStream(item.peerEmail),
                    builder: (context, presenceSnap) {
                      final isOnline = presenceSnap.data?.isOnline ?? false;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _openDirectChat(
                            peerEmail: item.peerEmail,
                            peerName: item.peerName,
                            peerTag: item.peerTag,
                          );
                        },
                        onLongPress: () {
                          _showDirectConversationOptionsModal(
                            context,
                            currentEmail: currentEmail,
                            peerEmail: item.peerEmail,
                            peerName: item.peerName,
                            isPinned: item.isPinned,
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
                              Stack(
                                children: [
                                  UserAvatar(
                                    email: item.peerEmail,
                                    name: item.peerName,
                                    radius: 22,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? AppColors.darkSurface : Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
                                              if (isOnline) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 2.5,
                                                        backgroundColor: Color(0xFF10B981),
                                                      ),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'Online',
                                                        style: TextStyle(
                                                          color: Color(0xFF10B981),
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
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
                                        if (item.isPinned) ...[
                                          const Icon(
                                            Icons.push_pin_rounded,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
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
          );
        },
      ),
    ),
  ],
    );
  }

  Widget _buildGroupsListTab(String currentEmail, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF881337), const Color(0xFF4C0519)]
                    : [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE11D48).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE11D48),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Grup Obrolan Sekolah',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      Text(
                        'Diskusi kelompok belajar & kelas. Kuota: Max 2 grup buatan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    CreateGroupDialog.show(
                      context,
                      onGroupCreated: () => setState(() {}),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Buat Grup', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<CustomGroup>>(
            stream: _chatService.getUserGroupsStream(currentEmail),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final groups = snapshot.data ?? [];
              if (groups.isEmpty) {
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
                            Icons.groups_outlined,
                            size: 44,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Belum Ada Grup Obrolan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Anda belum bergabung ke grup manapun. Buat grup obrolan baru untuk kelompok belajar Anda (Maksimal 2 grup).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.group_add_rounded, size: 18),
                          label: const Text('Buat Grup Obrolan Baru'),
                          onPressed: () {
                            CreateGroupDialog.show(
                              context,
                              onGroupCreated: () => setState(() {}),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final isCreator = group.isCreator(currentEmail);

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _activeDirectPeerEmail = null;
                        _activeCustomGroup = group;
                      });
                    },
                    onLongPress: () {
                      _showGroupOptionsModal(
                        context,
                        currentEmail: currentEmail,
                        group: group,
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
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE11D48),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        group.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCreator) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ADMIN',
                                          style: TextStyle(
                                            color: Color(0xFFE11D48),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  group.description.isNotEmpty
                                      ? group.description
                                      : '${group.members.length} anggota • Oleh ${group.creatorName}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (group.lastMessage.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    group.lastMessage,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey,
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

  Widget _buildStatusTabFullView({
    required String currentEmail,
    required String currentName,
    required String currentTag,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status Avatars Horizontal Tray (Status Saya & Civitas)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle_notifications_rounded, size: 16, color: Color(0xFFE11D48)),
                      const SizedBox(width: 6),
                      const Text(
                        'Cerita & Status 24 Jam',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        'Otomatis hilang 24j',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _buildStoryTray(
                  currentEmail: currentEmail,
                  currentName: currentName,
                  currentTag: currentTag,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Banner Informasi & Pembuat Status Cepat
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF881337), const Color(0xFF4C0519)]
                    : [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE11D48).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE11D48),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bagikan Pembaruan & Status Hari Ini',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          Text(
                            'Status akan dapat dilihat oleh seluruh guru & siswa selama 24 jam.',
                            style: TextStyle(fontSize: 11, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCreateStoryModal(
                          currentEmail: currentEmail,
                          currentName: currentName,
                          currentTag: currentTag,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          side: const BorderSide(color: Color(0xFFE11D48)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Foto / Galeri', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Header Feed Cerita Civitas
          Row(
            children: [
              const Icon(Icons.dynamic_feed_rounded, size: 18, color: Color(0xFFE11D48)),
              const SizedBox(width: 8),
              Text(
                'Feed Status Civitas Sekolah',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Feed Stream Cards
          StreamBuilder<List<StoryItem>>(
            stream: _storyService.getStoriesStream(
              currentUserEmail: currentEmail,
              currentUserTag: currentTag,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final stories = snapshot.data ?? [];

              if (stories.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_rounded,
                          size: 38,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum Ada Status Hari Ini',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jadilah yang pertama membagikan pengumuman atau momen belajar di SMK Bakti Nusantara 666!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                        label: const Text('Buat Status Pertama'),
                        onPressed: () => _showCreateStoryModal(
                          currentEmail: currentEmail,
                          currentName: currentName,
                          currentTag: currentTag,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final story = stories[index];
                  final tagColor = UserTagResolver.getTagColor(story.userTag);

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      _openStoryViewer(
                        stories: stories,
                        initialIndex: index,
                        currentEmail: currentEmail,
                        currentName: currentName,
                        currentTag: currentTag,
                        onAddStory: () => _showCreateStoryModal(
                          currentEmail: currentEmail,
                          currentName: currentName,
                          currentTag: currentTag,
                        ),
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
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: UserAvatar(
                              email: story.userEmail,
                              name: story.userName,
                              radius: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        story.userName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: tagColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        story.userTag,
                                        style: TextStyle(
                                          color: tagColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  story.isVideoStory
                                      ? (story.caption.isNotEmpty ? '📹 ${story.caption}' : '📹 Berbagi video baru')
                                      : (story.isTextStory
                                          ? '✏️ ${story.caption}'
                                          : (story.caption.isNotEmpty ? '📸 ${story.caption}' : '📸 Berbagi foto baru')),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (story.isVideoStory)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam_rounded, color: Color(0xFF8B5CF6), size: 20),
                                  SizedBox(height: 1),
                                  Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (story.imageBase64.isNotEmpty)
                            Builder(
                              builder: (_) {
                                if (story.imageBase64.startsWith('http')) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      story.imageBase64,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 24, color: Colors.grey),
                                    ),
                                  );
                                }
                                try {
                                  String clean = story.imageBase64.trim();
                                  if (clean.contains(',')) {
                                    clean = clean.split(',').last;
                                  }
                                  clean = clean.replaceAll(RegExp(r'\s+'), '');
                                  final bytes = base64Decode(clean);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      bytes,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 24, color: Colors.grey),
                                    ),
                                  );
                                } catch (_) {
                                  return const Icon(Icons.image_outlined, size: 24, color: Colors.grey);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMessagesStream(String userEmail, bool isDark) {
    final targetRoomId = _activeCustomGroup?.id ??
        (_activeDirectPeerEmail != null
            ? ChatService.getPrivateRoomId(userEmail, _activeDirectPeerEmail!)
            : 'publik');

    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getMessagesStream(targetRoomId, limit: _messageLimit),
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
                    'Obrolan tersimpan secara permanen dan aman.',
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

        return Column(
          children: [
            _buildPinnedMessageBanner(messages, targetRoomId, isDark),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: messages.length + (messages.length >= _messageLimit ? 1 : 0),
                itemBuilder: (context, index) {
                  if (messages.length >= _messageLimit && index == 0) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 4),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _messageLimit += 50;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Muat pesan sebelumnya (+50)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final msgIndex = messages.length >= _messageLimit ? index - 1 : index;
                  final message = messages[msgIndex];
                  final isMe = message.senderEmail.toLowerCase() == userEmail.toLowerCase();
                  return _buildMessageBubble(
                    message: message,
                    isMe: isMe,
                    isDark: isDark,
                    currentEmail: userEmail,
                  );
                },
              ),
            ),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getTypingStatusStream(targetRoomId, userEmail),
              builder: (context, typingSnap) {
                final typingUsers = typingSnap.data ?? [];
                if (typingUsers.isEmpty) return const SizedBox.shrink();
                final firstName = typingUsers.first['userName']?.toString() ?? 'Seseorang';
                return TypingIndicatorWidget(
                  userName: firstName,
                  isDark: isDark,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildReplyPreviewBar(bool isDark) {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          left: const BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Membalas ${_replyToMessage!.senderName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!.text.isNotEmpty
                      ? _replyToMessage!.text
                      : (_replyToMessage!.isImage ? '[Foto]' : '[Berkas]'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _replyToMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEditingPreviewBar(bool isDark) {
    if (_editingMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.amber.shade50,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          left: const BorderSide(color: Color(0xFFD97706), width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text(
                      'Edit Pesan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _editingMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _textController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageBanner(List<ChatMessage> messages, String targetRoomId, bool isDark) {
    final pinnedMsg = messages.firstWhere((m) => m.isPinned, orElse: () => ChatMessage(
      id: '',
      senderEmail: '',
      senderName: '',
      senderRole: '',
      text: '',
      timestamp: DateTime.now(),
      expiresAt: DateTime.now(),
      roomId: targetRoomId,
    ));
    if (pinnedMsg.id.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pesan Disematkan',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${pinnedMsg.senderName}: ${pinnedMsg.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              _chatService.togglePinMessage(
                roomId: targetRoomId,
                messageId: pinnedMsg.id,
                currentPinState: true,
              );
            },
          ),
        ],
      ),
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
    // Tentukan warna & badge tag pengirim secara akurat (Guru / TU / Siswa)
    final roleTag = UserTagResolver.resolve(
      email: message.senderEmail,
      displayName: message.senderName,
      fallbackRole: message.senderRole,
    );
    final roleBadgeColor = UserTagResolver.getTagColor(roleTag);

    if (message.isSticker) {
      final stickerUrl = message.effectiveFileUrl;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              UserAvatar(
                email: message.senderEmail,
                name: message.senderName,
                radius: 14,
              ),
              const SizedBox(width: 6),
            ],
            GestureDetector(
              onLongPress: () => _showMessageOptions(message, isMe, currentEmail),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: roleBadgeColor,
                      ),
                    ),
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(4),
                    child: Image.network(
                      stickerUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(message.text, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.timeFormatted,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildDeliveryStatus(message),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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

                    // Quote Box if Replying
                    if (message.replyToSenderName != null && message.replyToSenderName!.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: isMe ? 0.15 : 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe ? Colors.white : AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyToSenderName!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.white : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.replyToText ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Audio (Voice Note), Image, File, or Text Content + Rich Link Preview
                    if (message.isAudio)
                      VoiceNotePlayerWidget(
                        audioUrl: message.effectiveFileUrl,
                        initialDurationSec: message.audioDuration,
                        isMe: isMe,
                        isDark: isDark,
                      )
                    else if (message.isImage)
                      _buildImageBubbleContent(message, isMe, isDark)
                    else if (message.isFile)
                      _buildFileBubbleContent(message, isMe, isDark)
                    else ...[
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
                      if (message.hasLinkPreview)
                        RichLinkPreviewWidget(
                          title: message.linkTitle!,
                          description: message.linkDescription ?? '',
                          imageUrl: message.linkImageUrl,
                          url: message.linkUrl!,
                          isMe: isMe,
                          isDark: isDark,
                        ),
                    ],
                    const SizedBox(height: 6),

                    // Timestamp, Remaining Expiry Pill & Status Pengiriman
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isStarredBy(currentEmail)) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: isMe ? Colors.amber[200] : Colors.amber[800],
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (message.isPinned) ...[
                          Icon(
                            Icons.push_pin_rounded,
                            size: 10,
                            color: isMe ? Colors.white70 : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          message.isEdited
                              ? '${message.timeFormatted} • Edited'
                              : message.timeFormatted,
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: message.isEdited ? FontStyle.italic : FontStyle.normal,
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
                    // Reaksi Emoji Badge di Bawah Pesan
                    if (message.reactions != null && message.reactions!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: message.reactions!.entries.map((entry) {
                          final emoji = entry.key;
                          final userList = entry.value;
                          final hasReacted = userList.contains(currentEmail.toLowerCase().trim());

                          return GestureDetector(
                            onTap: () {
                              final roomId = ChatService.getPrivateRoomId(currentEmail, _activeDirectPeerEmail!);
                              _chatService.toggleReaction(
                                roomId: roomId,
                                messageId: message.id,
                                emoji: emoji,
                                userEmail: currentEmail,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasReacted
                                    ? AppColors.primary.withValues(alpha: 0.18)
                                    : (isDark ? AppColors.darkSurface : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasReacted ? AppColors.primary : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$emoji ${userList.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Deretan Reaksi Emoji Cepat
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['👍', '❤️', '😂', '😮', '🙏', '💡'].map((emoji) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(ctx);
                          final roomId = ChatService.getPrivateRoomId(currentEmail, _activeDirectPeerEmail!);
                          _chatService.toggleReaction(
                            roomId: roomId,
                            messageId: message.id,
                            emoji: emoji,
                            userEmail: currentEmail,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
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
                  leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
                  title: const Text('Balas Pesan'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _replyToMessage = message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: Text(
                    isMe ? 'Hapus Pesan Saya' : 'Hapus Pesan dari Obrolan',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Hapus pesan ini dari ruang obrolan'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final targetRoomId = _activeCustomGroup != null
                        ? _activeCustomGroup!.id
                        : (_activeDirectPeerEmail != null
                            ? ChatService.getPrivateRoomId(currentEmail, _activeDirectPeerEmail!)
                            : message.roomId);
                    _confirmAndDeleteMessage(message, targetRoomId, currentEmail);
                  },
                ),
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
                ListTile(
                  leading: const Icon(Icons.forward_rounded, color: Color(0xFFE11D48)),
                  title: const Text('Teruskan Pesan (Max 5 Target)'),
                  subtitle: const Text('Kirim pesan ke beberapa kontak/grup sekaligus'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ForwardMessageDialog.show(
                      context,
                      userEmail: currentEmail,
                      onForwardConfirmed: (recipients) async {
                        await _chatService.forwardMessageToMultipleRecipients(
                          originalMessage: message,
                          targetRecipients: recipients,
                          senderEmail: currentEmail,
                          senderName: currentEmail.split('@').first,
                          senderRole: UserTagResolver.resolve(email: currentEmail, displayName: currentEmail.split('@').first),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pesan berhasil diteruskan ke ${recipients.length} target obrolan! 🚀'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mark_as_unread_rounded, color: Color(0xFFE11D48)),
                  title: const Text('Teruskan ke BaknusMail (Draft/Kirim)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final bodyText = '--- Pesan Teruskan dari BaknusChat ---\n'
                        'Pengirim: ${message.senderName} (${message.senderEmail})\n'
                        'Tanggal: ${FormatHelper.formatFullDateTime(message.timestamp)}\n\n'
                        '${message.text}';
                    Navigator.pushNamed(
                      context,
                      '/compose',
                      arguments: {
                        'initialBody': bodyText,
                        'initialSubject': 'Fwd Chat: ${message.senderName}',
                        'initialTo': isMe ? '' : message.senderEmail,
                      },
                    );
                  },
                ),
                if (isMe && !message.isAudio && !message.isSticker)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: Color(0xFFD97706)),
                    title: const Text('Edit Pesan'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _editingMessage = message;
                        _replyToMessage = null;
                        _textController.text = message.text;
                      });
                    },
                  ),
                ListTile(
                  leading: Icon(
                    message.isStarredBy(currentEmail) ? Icons.star_border_rounded : Icons.star_rounded,
                    color: Colors.amber,
                  ),
                  title: Text(message.isStarredBy(currentEmail) ? 'Hapus Bintang' : 'Beri Bintang'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final roomId = message.roomId.isNotEmpty
                        ? message.roomId
                        : (_activeCustomGroup != null
                            ? _activeCustomGroup!.id
                            : (_activeDirectPeerEmail != null
                                ? ChatService.getPrivateRoomId(currentEmail, _activeDirectPeerEmail!)
                                : ''));
                    if (roomId.isNotEmpty) {
                      _chatService.toggleStarMessage(
                        roomId: roomId,
                        messageId: message.id,
                        userEmail: currentEmail,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    message.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    color: const Color(0xFFD97706),
                  ),
                  title: Text(message.isPinned ? 'Lepas Sematan Pesan' : 'Sematkan Pesan'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final roomId = _activeCustomGroup != null
                        ? _activeCustomGroup!.id
                        : (_activeDirectPeerEmail != null
                            ? ChatService.getPrivateRoomId(currentEmail, _activeDirectPeerEmail!)
                            : message.roomId);
                    _chatService.togglePinMessage(
                      roomId: roomId,
                      messageId: message.id,
                      currentPinState: message.isPinned,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteMessage(
    ChatMessage message,
    String roomId,
    String currentEmail,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pesan?'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus pesan ini? Pesan yang dihapus tidak dapat dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _chatService.deleteMessage(roomId, message.id, currentEmail);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesan berhasil dihapus')),
        );
      }
    }
  }

  void _showDirectConversationOptionsModal(
    BuildContext context, {
    required String currentEmail,
    required String peerEmail,
    required String peerName,
    bool isPinned = false,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
              title: Text('Buka Obrolan dengan $peerName'),
              onTap: () {
                Navigator.pop(ctx);
                _openDirectChat(
                  peerEmail: peerEmail,
                  peerName: peerName,
                  peerTag: UserTagResolver.resolve(email: peerEmail, displayName: peerName),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: Colors.amber[700],
              ),
              title: Text(isPinned ? 'Lepas Pin Percakapan' : 'Sematkan (Pin) Percakapan Ini'),
              subtitle: Text(
                isPinned
                    ? 'Lepaskan sematan percakapan dari posisi paling atas'
                    : 'Sematkan di posisi paling atas (Maksimal 3 percakapan)',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final success = await _chatService.togglePinConversation(
                  userEmail: currentEmail,
                  peerEmail: peerEmail,
                  isPinned: !isPinned,
                );

                if (!mounted) return;
                if (!success && !isPinned) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Maksimal 3 percakapan yang dapat disematkan (pin).'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.amber[800],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        !isPinned
                            ? 'Percakapan dengan $peerName berhasil disematkan di paling atas.'
                            : 'Sematan percakapan dengan $peerName telah dilepas.',
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Hapus Percakapan Ini', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              subtitle: const Text('Hapus seluruh riwayat pesan dengan pengguna ini'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmAndDeleteDirectConversation(currentEmail, peerEmail, peerName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteDirectConversation(
    String currentEmail,
    String peerEmail,
    String peerName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Percakapan dengan $peerName?'),
        content: const Text(
          'Seluruh riwayat obrolan ini akan dihapus secara permanen dari daftar obrolan Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Percakapan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _chatService.deleteDirectConversation(
        currentEmail: currentEmail,
        peerEmail: peerEmail,
      );
      if (!mounted) return;
      if (success) {
        messenger.showSnackBar(
          SnackBar(content: Text('Percakapan dengan $peerName berhasil dihapus.')),
        );
        if (_activeDirectPeerEmail == peerEmail) {
          setState(() {
            _activeDirectPeerEmail = null;
          });
        }
      }
    }
  }

  void _showGroupOptionsModal(
    BuildContext context, {
    required String currentEmail,
    required CustomGroup group,
  }) {
    final isCreator = group.isCreator(currentEmail);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
              title: Text('Masuk Obrolan ${group.name}'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _activeDirectPeerEmail = null;
                  _activeCustomGroup = group;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: Color(0xFFE11D48)),
              title: const Text('Info & Anggota Grup'),
              onTap: () {
                Navigator.pop(ctx);
                GroupInfoDialog.show(
                  context,
                  group: group,
                  onGroupUpdated: () => setState(() {}),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(
                isCreator ? 'Hapus & Bubarkan Grup' : 'Keluar & Hapus Grup',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isCreator
                    ? 'Grup obrolan akan dihapus secara permanen untuk semua anggota'
                    : 'Keluarkan akun Anda dari grup obrolan ini',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(isCreator ? 'Hapus & Bubarkan Grup?' : 'Keluar & Hapus Grup?'),
                    content: Text(
                      isCreator
                          ? 'Apakah Anda yakin ingin menghapus grup "${group.name}"? Seluruh obrolan grup akan dihapus.'
                          : 'Apakah Anda yakin ingin keluar dan menghapus grup "${group.name}" dari daftar Anda?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text(isCreator ? 'Hapus Grup' : 'Keluar'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final success = await _chatService.deleteGroup(
                    groupId: group.id,
                    userEmail: currentEmail,
                  );
                  if (!mounted) return;
                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Grup "${group.name}" berhasil dihapus.')),
                    );
                    if (_activeCustomGroup?.id == group.id) {
                      setState(() {
                        _activeCustomGroup = null;
                      });
                    } else {
                      setState(() {});
                    }
                  }
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
          onDoubleTap: () => _handleDownloadFile(fileUrl, filename),
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
                            '• Buka / Unduh',
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
                InkWell(
                  onTap: () => _handleDownloadFile(fileUrl, filename),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildReplyPreviewBar(isDark),
        _buildEditingPreviewBar(isDark),
        Container(
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
          child: _isRecordingVoice
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE11D48), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record_rounded, color: Color(0xFFE11D48), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '00:${_recordDurationSec.toString().padLeft(2, '0')} / 00:10',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Merekam suara...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 22),
                        onPressed: _cancelVoiceRecording,
                        tooltip: 'Batal Rekam',
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFFE11D48), size: 22),
                        onPressed: () => _stopAndSendVoiceRecording(),
                        tooltip: 'Kirim Pesan Suara',
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Tombol Kamera Cepat
                    IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE11D48)),
                      tooltip: 'Ambil Foto Kamera',
                      onPressed: _isSending
                          ? null
                          : () => _handleCaptureAndSendPhoto(
                                senderEmail: senderEmail,
                                senderName: senderName,
                                senderTag: senderTag,
                              ),
                    ),
                    // Tombol Stiker BaknusChat
                    IconButton(
                      icon: const Icon(Icons.style_rounded, color: Color(0xFFE11D48)),
                      tooltip: 'Pilih Stiker BaknusChat',
                      onPressed: _isSending
                          ? null
                          : () => _showStickerPickerSheet(
                                senderEmail: senderEmail,
                                senderName: senderName,
                                senderTag: senderTag,
                              ),
                    ),
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
                          onChanged: (val) {
                            _onTextChanged(val);
                            setState(() {}); // Trigger rebuild to toggle Mic / Send icon
                          },
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
                            : () {
                                if (_textController.text.trim().isEmpty) {
                                  _startVoiceRecording();
                                } else {
                                  _handleSendMessage(
                                    senderEmail: senderEmail,
                                    senderName: senderName,
                                    senderTag: senderTag,
                                  );
                                }
                              },
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
                              : Icon(
                                  _textController.text.trim().isEmpty
                                      ? Icons.mic_rounded
                                      : Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStoryThumbnailAvatar({
    StoryItem? story,
    required String imageBase64,
    required String fallbackEmail,
    required String fallbackName,
    double radius = 25,
  }) {
    if (story != null && story.isVideoStory) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            UserAvatar(
              email: fallbackEmail,
              name: fallbackName,
              radius: radius - 3,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.40),
                shape: BoxShape.circle,
              ),
            ),
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      );
    }
    if (imageBase64.isNotEmpty && !imageBase64.startsWith('http')) {
      try {
        String clean = imageBase64;
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        final bytes = base64Decode(clean);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return UserAvatar(
                email: fallbackEmail,
                name: fallbackName,
                radius: radius,
              );
            },
          ),
        );
      } catch (_) {}
    }
    return UserAvatar(
      email: fallbackEmail,
      name: fallbackName,
      radius: radius,
    );
  }

  Widget _buildStoryTray({
    required String currentEmail,
    required String currentName,
    required String currentTag,
    required bool isDark,
  }) {
    return StreamBuilder<List<StoryItem>>(
      stream: _storyService.getStoriesStream(
        currentUserEmail: currentEmail,
        currentUserTag: currentTag,
      ),
      builder: (context, snapshot) {
        final allStories = snapshot.data ?? [];

        // Kelompokkan story berdasarkan userEmail (maksimal 3 story per user)
        final Map<String, List<StoryItem>> storiesGroupedByUser = {};
        for (final s in allStories) {
          final clean = s.userEmail.toLowerCase().trim();
          final userList = storiesGroupedByUser.putIfAbsent(clean, () => []);
          if (userList.length < 3) {
            userList.add(s);
          }
        }

        // Story milik user sendiri
        final myStories = storiesGroupedByUser[currentEmail.toLowerCase().trim()] ?? [];

        // Story milik user lain
        final otherUserEmails = storiesGroupedByUser.keys
            .where((e) => e != currentEmail.toLowerCase().trim())
            .toList();

        void triggerCreateStory() {
          if (myStories.length >= 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Batas maksimal 3 story foto telah tercapai. Hapus story lama untuk membuat story baru.'),
                backgroundColor: AppColors.error,
              ),
            );
          } else {
            _showCreateStoryModal(
              currentEmail: currentEmail,
              currentName: currentName,
              currentTag: currentTag,
            );
          }
        }

        return Container(
          height: 96,
          margin: const EdgeInsets.only(top: 2, bottom: 4),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: 1 + otherUserEmails.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                // Item 0: Story Saya (Tambah Story / Lihat Story Saya)
                final hasMyStory = myStories.isNotEmpty;
                final myLatestStory = hasMyStory ? myStories.first : null;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (hasMyStory) {
                              _openStoryViewer(
                                stories: myStories,
                                initialIndex: 0,
                                currentEmail: currentEmail,
                                currentName: currentName,
                                currentTag: currentTag,
                                onAddStory: triggerCreateStory,
                              );
                            } else {
                              triggerCreateStory();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasMyStory
                                  ? const LinearGradient(
                                      colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
                                    )
                                  : null,
                              border: !hasMyStory
                                  ? Border.all(
                                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: hasMyStory && myLatestStory != null
                                ? _buildStoryThumbnailAvatar(
                                    story: myLatestStory,
                                    imageBase64: myLatestStory.imageBase64,
                                    fallbackEmail: currentEmail,
                                    fallbackName: currentName,
                                    radius: 25,
                                  )
                                : UserAvatar(
                                    email: currentEmail,
                                    name: currentName,
                                    radius: 25,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: triggerCreateStory,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE11D48),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 62,
                      child: Text(
                        hasMyStory ? 'Story Saya' : 'Tambah Story',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }

              // Item > 0: Story Civitas Lain
              final peerEmail = otherUserEmails[index - 1];
              final userStories = storiesGroupedByUser[peerEmail] ?? [];
              if (userStories.isEmpty) return const SizedBox.shrink();

              final firstStory = userStories.first;
              final hasUnviewed = userStories.any((s) => !s.isViewedBy(currentEmail));

              return GestureDetector(
                onTap: () {
                  _openStoryViewer(
                    stories: userStories,
                    initialIndex: 0,
                    currentEmail: currentEmail,
                    currentName: currentName,
                    currentTag: currentTag,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasUnviewed
                            ? const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
                              )
                            : null,
                        border: !hasUnviewed
                            ? Border.all(
                                color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: _buildStoryThumbnailAvatar(
                        story: firstStory,
                        imageBase64: firstStory.imageBase64,
                        fallbackEmail: peerEmail,
                        fallbackName: firstStory.userName,
                        radius: 25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 62,
                      child: Text(
                        firstStory.userName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: hasUnviewed ? FontWeight.bold : FontWeight.normal,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showCreateStoryModal({
    required String currentEmail,
    required String currentName,
    required String currentTag,
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
                  'Buat Status Civitas 24 Jam',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status otomatis terhapus setelah 24 jam • 0% Beban Server',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    // Opsi Status Tulisan
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleCreateTextStory(
                            currentEmail: currentEmail,
                            currentName: currentName,
                            currentTag: currentTag,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED), size: 28),
                              SizedBox(height: 8),
                              Text('Tulisan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Teks & Warna', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Opsi Kamera
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handlePickAndPostStory(
                            source: ImageSource.camera,
                            currentEmail: currentEmail,
                            currentName: currentName,
                            currentTag: currentTag,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Color(0xFFE11D48), size: 28),
                              SizedBox(height: 8),
                              Text('Kamera HP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Jepret Foto', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                      const SizedBox(width: 10),
                      // Opsi Galeri Foto
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(ctx);
                            _handlePickAndPostStory(
                              source: ImageSource.gallery,
                              currentEmail: currentEmail,
                              currentName: currentName,
                              currentTag: currentTag,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB), size: 28),
                                SizedBox(height: 8),
                                Text('Galeri Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                SizedBox(height: 2),
                                Text('Pilih Foto', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Opsi Rekam Video 10 Detik
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(ctx);
                            _handlePickAndPostVideoStory(
                              source: ImageSource.camera,
                              currentEmail: currentEmail,
                              currentName: currentName,
                              currentTag: currentTag,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.videocam_rounded, color: Color(0xFF8B5CF6), size: 28),
                                SizedBox(height: 6),
                                Text('Rekam Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                SizedBox(height: 2),
                                Text('Max 10 Detik', style: TextStyle(fontSize: 10.5, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Opsi Galeri Video 10 Detik
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(ctx);
                            _handlePickAndPostVideoStory(
                              source: ImageSource.gallery,
                              currentEmail: currentEmail,
                              currentName: currentName,
                              currentTag: currentTag,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.video_library_rounded, color: Color(0xFF10B981), size: 28),
                                SizedBox(height: 6),
                                Text('Galeri Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                SizedBox(height: 2),
                                Text('Max 10 Detik', style: TextStyle(fontSize: 10.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
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

  Future<void> _handleCreateTextStory({
    required String currentEmail,
    required String currentName,
    required String currentTag,
  }) async {
    final textController = TextEditingController();
    String selectedColor = '#E11D48';
    List<String> selectedAudience = ['Semua'];
    JamendoMusic? selectedMusic;

    final colorOptions = [
      {'name': 'Merah Crimson', 'hex': '#E11D48', 'color': const Color(0xFFE11D48)},
      {'name': 'Biru Indigo', 'hex': '#2563EB', 'color': const Color(0xFF2563EB)},
      {'name': 'Hijau Emerald', 'hex': '#059669', 'color': const Color(0xFF059669)},
      {'name': 'Ungu Violet', 'hex': '#7C3AED', 'color': const Color(0xFF7C3AED)},
      {'name': 'Amber Gold', 'hex': '#D97706', 'color': const Color(0xFFD97706)},
      {'name': 'Rose Pink', 'hex': '#DB2777', 'color': const Color(0xFFDB2777)},
      {'name': 'Teal Ocean', 'hex': '#0D9488', 'color': const Color(0xFF0D9488)},
      {'name': 'Dark Charcoal', 'hex': '#1E293B', 'color': const Color(0xFF1E293B)},
    ];

    Color parseHex(String hex) {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    }

    final result = await showModalBottomSheet<_TextStoryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void toggleAudience(String tag) {
              setModalState(() {
                if (tag == 'Semua') {
                  selectedAudience = ['Semua'];
                } else {
                  selectedAudience.remove('Semua');
                  if (selectedAudience.contains(tag)) {
                    selectedAudience.remove(tag);
                  } else {
                    selectedAudience.add(tag);
                  }
                  if (selectedAudience.isEmpty ||
                      (selectedAudience.contains('Siswa') &&
                          selectedAudience.contains('Guru') &&
                          selectedAudience.contains('TU'))) {
                    selectedAudience = ['Semua'];
                  }
                }
              });
            }

            final activeBgColor = parseHex(selectedColor);

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              decoration: BoxDecoration(
                color: activeBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header Bar Editor
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                            onPressed: () => Navigator.pop(ctx, null),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Status Tulisan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: activeBgColor,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 15),
                            label: const Text('Posting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () {
                              final text = textController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Tulis status terlebih dahulu.')),
                                );
                                return;
                              }
                              Navigator.pop(
                                ctx,
                                _TextStoryResult(
                                  text: text,
                                  bgColor: selectedColor,
                                  targetAudience: List.from(selectedAudience),
                                  music: selectedMusic,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Area Input Teks Utama (Centered Live Preview)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: TextField(
                            controller: textController,
                            autofocus: true,
                            maxLines: null,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black38, offset: Offset(0, 1)),
                              ],
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Ketik status atau pengumuman di sini...',
                              hintStyle: TextStyle(
                                color: Colors.white60,
                                fontSize: 20,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Panel Bawah: Palette Warna, Musik Jamendo & Visibilitas Audiens
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tombol Pilihan Musik Jamendo
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                icon: const Icon(Icons.music_note_rounded, size: 16, color: Color(0xFFF43F5E)),
                                label: Text(
                                  selectedMusic != null ? '🎵 ${selectedMusic!.name}' : '🎵 Tambah Musik Jamendo',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                onPressed: () async {
                                  final music = await JamendoMusicPickerDialog.show(ctx, initialSelected: selectedMusic);
                                  setModalState(() {
                                    selectedMusic = music;
                                  });
                                },
                              ),
                              if (selectedMusic != null) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.cancel_rounded, color: Colors.white70, size: 20),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedMusic = null;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Pilih Warna Latar (Background):',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: colorOptions.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, idx) {
                                final opt = colorOptions[idx];
                                final hex = opt['hex'] as String;
                                final col = opt['color'] as Color;
                                final isSelected = selectedColor == hex;

                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() => selectedColor = hex);
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: col,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.white38,
                                        width: isSelected ? 3 : 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Dapat dilihat oleh:',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildAudienceChip(
                                label: 'Semua Civitas',
                                icon: Icons.public_rounded,
                                color: Colors.white,
                                isSelected: selectedAudience.contains('Semua'),
                                onTap: () => toggleAudience('Semua'),
                                isDark: true,
                              ),
                              _buildAudienceChip(
                                label: 'Siswa',
                                icon: Icons.person_rounded,
                                color: Colors.white,
                                isSelected: selectedAudience.contains('Siswa'),
                                onTap: () => toggleAudience('Siswa'),
                                isDark: true,
                              ),
                              _buildAudienceChip(
                                label: 'Guru',
                                icon: Icons.school_rounded,
                                color: Colors.white,
                                isSelected: selectedAudience.contains('Guru'),
                                onTap: () => toggleAudience('Guru'),
                                isDark: true,
                              ),
                              _buildAudienceChip(
                                label: 'TU',
                                icon: Icons.badge_rounded,
                                color: Colors.white,
                                isSelected: selectedAudience.contains('TU'),
                                onTap: () => toggleAudience('TU'),
                                isDark: true,
                              ),
                            ],
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
    );

    if (result == null) return;

    setState(() => _isSending = true);

    try {
      await _storyService.createStory(
        userEmail: currentEmail,
        userName: currentName,
        userTag: currentTag,
        caption: result.text,
        bgColor: result.bgColor,
        targetAudience: result.targetAudience,
        type: 'text',
        musicTitle: result.music?.name,
        artistName: result.music?.artistName,
        musicAudioUrl: result.music?.audioUrl,
        musicCoverUrl: result.music?.coverUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status Tulisan berhasil dipublikasikan!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat status: $e'),
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

  Future<void> _handlePickAndPostStory({
    required ImageSource source,
    required String currentEmail,
    required String currentName,
    required String currentTag,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: source,
        imageQuality: 65,
        maxWidth: 800,
        maxHeight: 1000,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) return;

      if (!mounted) return;

      final captionController = TextEditingController();
      List<String> selectedAudience = ['Semua'];
      JamendoMusic? selectedMusic;

      final publishResult = await showModalBottomSheet<_StoryPublishResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return StatefulBuilder(
            builder: (context, setModalState) {
              void toggleAudience(String tag) {
                setModalState(() {
                  if (tag == 'Semua') {
                    selectedAudience = ['Semua'];
                  } else {
                    selectedAudience.remove('Semua');
                    if (selectedAudience.contains(tag)) {
                      selectedAudience.remove(tag);
                    } else {
                      selectedAudience.add(tag);
                    }
                    if (selectedAudience.isEmpty ||
                        (selectedAudience.contains('Siswa') &&
                            selectedAudience.contains('Guru') &&
                            selectedAudience.contains('TU'))) {
                      selectedAudience = ['Semua'];
                    }
                  }
                });
              }

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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Unggah Story Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Akan hilang dalam 24 jam secara otomatis', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                              foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.music_note_rounded, size: 16, color: Color(0xFFF43F5E)),
                            label: Text(
                              selectedMusic != null ? '🎵 ${selectedMusic!.name}' : '🎵 Tambah Musik Jamendo',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () async {
                              final music = await JamendoMusicPickerDialog.show(ctx, initialSelected: selectedMusic);
                              setModalState(() {
                                selectedMusic = music;
                              });
                            },
                          ),
                          if (selectedMusic != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 20),
                              onPressed: () {
                                setModalState(() {
                                  selectedMusic = null;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Dapat dilihat oleh:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildAudienceChip(
                            label: 'Semua Civitas',
                            icon: Icons.public_rounded,
                            color: const Color(0xFF2563EB),
                            isSelected: selectedAudience.contains('Semua'),
                            onTap: () => toggleAudience('Semua'),
                            isDark: isDark,
                          ),
                          _buildAudienceChip(
                            label: 'Siswa',
                            icon: Icons.person_rounded,
                            color: const Color(0xFF059669),
                            isSelected: selectedAudience.contains('Siswa'),
                            onTap: () => toggleAudience('Siswa'),
                            isDark: isDark,
                          ),
                          _buildAudienceChip(
                            label: 'Guru',
                            icon: Icons.school_rounded,
                            color: const Color(0xFFD97706),
                            isSelected: selectedAudience.contains('Guru'),
                            onTap: () => toggleAudience('Guru'),
                            isDark: isDark,
                          ),
                          _buildAudienceChip(
                            label: 'TU',
                            icon: Icons.badge_rounded,
                            color: const Color(0xFF7C3AED),
                            isSelected: selectedAudience.contains('TU'),
                            onTap: () => toggleAudience('TU'),
                            isDark: isDark,
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
                            hintText: 'Tambah keterangan story (opsional)...',
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
                              onPressed: () => Navigator.pop(
                                ctx,
                                _StoryPublishResult(
                                  caption: captionController.text.trim(),
                                  targetAudience: List.from(selectedAudience),
                                  music: selectedMusic,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Posting Story'),
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
        },
      );

      if (publishResult == null) return; // Dibatalkan oleh pengguna

      setState(() => _isSending = true);

      await _storyService.createStory(
        userEmail: currentEmail,
        userName: currentName,
        userTag: currentTag,
        imageBytes: bytes,
        caption: publishResult.caption,
        targetAudience: publishResult.targetAudience,
        musicTitle: publishResult.music?.name,
        artistName: publishResult.music?.artistName,
        musicAudioUrl: publishResult.music?.audioUrl,
        musicCoverUrl: publishResult.music?.coverUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story Foto 24 jam berhasil dipublikasikan!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat story: $e'),
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

  Future<void> _handlePickAndPostVideoStory({
    required ImageSource source,
    required String currentEmail,
    required String currentName,
    required String currentTag,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 10),
      );

      if (video == null) return;

      final bytes = await video.readAsBytes();
      if (bytes.isEmpty) return;

      if (!mounted) return;

      final captionController = TextEditingController();
      List<String> selectedAudience = ['Semua'];
      JamendoMusic? selectedMusic;

      final publishResult = await showModalBottomSheet<_StoryPublishResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return StatefulBuilder(
            builder: (context, setModalState) {
              void toggleAudience(String tag) {
                setModalState(() {
                  if (tag == 'Semua') {
                    selectedAudience = ['Semua'];
                  } else {
                    selectedAudience.remove('Semua');
                    if (selectedAudience.contains(tag)) {
                      selectedAudience.remove(tag);
                    } else {
                      selectedAudience.add(tag);
                    }
                    if (selectedAudience.isEmpty ||
                        (selectedAudience.contains('Siswa') &&
                            selectedAudience.contains('Guru') &&
                            selectedAudience.contains('TU'))) {
                      selectedAudience = ['Semua'];
                    }
                  }
                });
              }

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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.videocam_rounded, color: Color(0xFF8B5CF6), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Unggah Story Video (Max 10 Detik)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Video akan otomatis hilang dalam 24 jam', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                              foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.music_note_rounded, size: 16, color: Color(0xFFF43F5E)),
                            label: Text(
                              selectedMusic != null ? '🎵 ${selectedMusic!.name}' : '🎵 Tambah Musik Jamendo',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () async {
                              final music = await JamendoMusicPickerDialog.show(ctx, initialSelected: selectedMusic);
                              setModalState(() {
                                selectedMusic = music;
                              });
                            },
                          ),
                          if (selectedMusic != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 20),
                              onPressed: () {
                                setModalState(() {
                                  selectedMusic = null;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
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
                            hintText: 'Tambah keterangan video (opsional)...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Visibilitas Audiens:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildAudienceChip(
                            label: 'Semua Civitas',
                            icon: Icons.public_rounded,
                            color: AppColors.primary,
                            isSelected: selectedAudience.contains('Semua'),
                            onTap: () => toggleAudience('Semua'),
                            isDark: isDark,
                          ),
                          _buildAudienceChip(
                            label: 'Siswa',
                            icon: Icons.person_rounded,
                            color: const Color(0xFF3B82F6),
                            isSelected: selectedAudience.contains('Siswa'),
                            onTap: () => toggleAudience('Siswa'),
                            isDark: isDark,
                          ),
                          _buildAudienceChip(
                            label: 'Guru',
                            icon: Icons.school_rounded,
                            color: const Color(0xFF10B981),
                            isSelected: selectedAudience.contains('Guru'),
                            onTap: () => toggleAudience('Guru'),
                            isDark: isDark,
                          ),
                          _buildAudienceChip(
                            label: 'TU',
                            icon: Icons.badge_rounded,
                            color: const Color(0xFF8B5CF6),
                            isSelected: selectedAudience.contains('TU'),
                            onTap: () => toggleAudience('TU'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
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
                              onPressed: () => Navigator.pop(
                                ctx,
                                _StoryPublishResult(
                                  caption: captionController.text.trim(),
                                  targetAudience: List.from(selectedAudience),
                                  music: selectedMusic,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Posting Video'),
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
        },
      );

      if (publishResult == null) return;

      setState(() => _isSending = true);

      // Upload file video ke BaknusDrive API (bebas batas ukuran 1MB Firestore)
      String? mediaUrl;
      try {
        final filename = 'story_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final uploadRes = await _chatService.uploadFileToBaknusDrive(
          senderEmail: currentEmail,
          fileBytes: bytes,
          filename: filename,
        );
        if (uploadRes != null && uploadRes['file_url'] != null) {
          mediaUrl = uploadRes['file_url'].toString();
        }
      } catch (e) {
        debugPrint('BaknusDrive video upload exception: $e');
      }

      await _storyService.createStory(
        userEmail: currentEmail,
        userName: currentName,
        userTag: currentTag,
        mediaBytes: bytes,
        mediaUrl: mediaUrl,
        caption: publishResult.caption,
        targetAudience: publishResult.targetAudience,
        type: 'video',
        musicTitle: publishResult.music?.name,
        artistName: publishResult.music?.artistName,
        musicAudioUrl: publishResult.music?.audioUrl,
        musicCoverUrl: publishResult.music?.coverUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Story Video (Max 10 Detik) berhasil dipublikasikan!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat story video: $e'),
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

  Widget _buildAudienceChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? color : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }



  Future<void> _handleDownloadFile(String url, String filename) async {
    if (url.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mengunduh berkas "$filename" ke HP...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );

    try {
      final uri = Uri.parse(url);
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched && await canLaunchUrl(uri)) {
        await launchUrl(uri);
        launched = true;
      }

      if (!launched) {
        throw Exception('Tidak dapat menemukan aplikasi/peramban pengunduh di perangkat.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh berkas: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showUserProfileDialog({
    required String peerEmail,
    required String peerName,
    required String peerTag,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagColor = UserTagResolver.getTagColor(peerTag);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // Full Profile Avatar (Tap to zoom in/view full photo)
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black87,
                      insetPadding: const EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              email: peerEmail,
                              name: peerName,
                              radius: 80,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              peerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              peerEmail,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Tutup Foto Profil'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    UserAvatar(
                      email: peerEmail,
                      name: peerName,
                      radius: 46,
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE11D48),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Name
              Text(
                peerName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Email
              const SizedBox(height: 2),
              Text(
                peerEmail,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 8),

              // Role Tag Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tagColor, width: 1.0),
                ),
                child: Text(
                  'AKUN $peerTag',
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Kirim Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/compose', arguments: {
                        'initialTo': peerEmail,
                        'initialSubject': 'Pesan dari BaknusChat',
                      });
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.perm_media_rounded, size: 16, color: Color(0xFFE11D48)),
                    label: const Text('Media & Dokumen', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final roomId = ChatService.getPrivateRoomId(peerEmail, _activeDirectPeerEmail ?? '');
                      RoomMediaGalleryDialog.show(context, roomId: roomId, roomTitle: peerName);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStoryViewer({
    required List<StoryItem> stories,
    required int initialIndex,
    required String currentEmail,
    required String currentName,
    required String currentTag,
    VoidCallback? onAddStory,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StoryViewerDialog(
        stories: stories,
        initialIndex: initialIndex,
        currentUserEmail: currentEmail,
        currentUserName: currentName,
        currentUserTag: currentTag,
        onAddStory: onAddStory,
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

class _StoryPublishResult {
  final String caption;
  final List<String> targetAudience;
  final JamendoMusic? music;

  _StoryPublishResult({
    required this.caption,
    required this.targetAudience,
    this.music,
  });
}

class _TextStoryResult {
  final String text;
  final String bgColor;
  final List<String> targetAudience;
  final JamendoMusic? music;

  _TextStoryResult({
    required this.text,
    required this.bgColor,
    required this.targetAudience,
    this.music,
  });
}

