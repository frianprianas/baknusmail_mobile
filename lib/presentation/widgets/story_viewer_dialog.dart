import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_tag_resolver.dart';
import '../../data/models/story_item.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/story_service.dart';
import 'user_avatar.dart';

class StoryViewerDialog extends StatefulWidget {
  final List<StoryItem> stories;
  final int initialIndex;
  final String currentUserEmail;
  final String currentUserName;
  final String currentUserTag;
  final VoidCallback? onAddStory;

  const StoryViewerDialog({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.currentUserEmail,
    required this.currentUserName,
    required this.currentUserTag,
    this.onAddStory,
  });

  @override
  State<StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends State<StoryViewerDialog>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animController;
  final StoryService _storyService = StoryService();
  final ChatService _chatService = ChatService();
  final TextEditingController _replyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPaused = false;
  bool _isSendingReply = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCurrentStory();
    });
  }

  void _startCurrentStory() {
    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) return;

    final story = widget.stories[_currentIndex];

    // Tandai story telah dilihat
    _storyService.markStoryAsViewed(
      storyId: story.id,
      viewerEmail: widget.currentUserEmail,
      viewerName: widget.currentUserName,
      viewerTag: widget.currentUserTag,
    );

    // Jika story berupa video, durasinya 10 detik. Jika memiliki musik, 15 detik.
    final storyDurationSec = story.isVideoStory ? 10 : (story.hasMusic ? 15 : 5);
    _animController.duration = Duration(seconds: storyDurationSec);

    _playStoryAudio(story);

    _animController.stop();
    _animController.reset();
    _animController.forward();
  }

  Future<void> _playStoryAudio(StoryItem story) async {
    try {
      await _audioPlayer.stop();
      if (story.hasMusic && story.musicAudioUrl != null && story.musicAudioUrl!.isNotEmpty) {
        await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
        debugPrint('Playing story music: ${story.musicTitle} -> ${story.musicAudioUrl}');
        await _audioPlayer.play(UrlSource(story.musicAudioUrl!));
      }
    } catch (e) {
      debugPrint('Error playing story audio: $e');
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startCurrentStory();
    } else {
      _audioPlayer.stop();
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startCurrentStory();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _pauseTimer() {
    if (!_isPaused) {
      _isPaused = true;
      _animController.stop();
      _audioPlayer.pause();
    }
  }

  void _resumeTimer() {
    if (_isPaused) {
      _isPaused = false;
      _animController.forward();
      _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _animController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String base64Data) {
    try {
      String clean = base64Data;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      final bytes = base64Decode(clean);
      return MemoryImage(bytes);
    } catch (_) {
      return const AssetImage('assets/images/logo.png');
    }
  }

  Future<void> _handleSendReply(StoryItem currentStory) async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSendingReply) return;

    _pauseTimer();
    setState(() => _isSendingReply = true);
    _replyController.clear();

    try {
      final roomId = ChatService.getPrivateRoomId(
        widget.currentUserEmail,
        currentStory.userEmail,
      );

      final replyMessage = '📲 *Membalas Story Foto:*\n"${currentStory.caption.isNotEmpty ? currentStory.caption : "📷 Foto"}"\n\n💬 $text';

      await _chatService.sendMessage(
        roomId: roomId,
        text: replyMessage,
        senderEmail: widget.currentUserEmail,
        senderName: widget.currentUserName,
        senderRole: widget.currentUserTag,
        recipientEmail: currentStory.userEmail,
        recipientName: currentStory.userName,
        recipientTag: currentStory.userTag,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Balasan terkirim ke ${currentStory.userName}!'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim balasan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
        _resumeTimer();
      }
    }
  }

  void _showViewersModal(StoryItem currentStory) {
    _pauseTimer();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final viewers = currentStory.viewers;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded, color: Color(0xFFE11D48), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Dilihat oleh ${viewers.length} Civitas',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (viewers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Belum ada yang melihat story ini.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: viewers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final v = viewers[idx];
                        final tagColor = UserTagResolver.getTagColor(v.tag);
                        final timeAgo = _formatTimeAgo(v.viewedAt);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: UserAvatar(email: v.email, name: v.name, radius: 18),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  v.name,
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
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  v.tag,
                                  style: TextStyle(
                                    color: tagColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            v.email,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          trailing: Text(
                            timeAgo,
                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).then((_) => _resumeTimer());
  }

  Future<void> _handleDeleteStory(StoryItem currentStory) async {
    _pauseTimer();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Story?'),
        content: const Text('Story ini akan dihapus permanen dari BaknusChat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storyService.deleteStory(currentStory.id, widget.currentUserEmail);
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      _resumeTimer();
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }
  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty || _currentIndex >= widget.stories.length) {
      return const SizedBox.shrink();
    }

    final currentStory = widget.stories[_currentIndex];
    final isMe = currentStory.userEmail.toLowerCase().trim() ==
        widget.currentUserEmail.toLowerCase().trim();
    final tagColor = UserTagResolver.getTagColor(currentStory.userTag);
    final timeAgo = _formatTimeAgo(currentStory.createdAt);

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onLongPressStart: (_) => _pauseTimer(),
        onLongPressEnd: (_) => _resumeTimer(),
        child: Stack(
          children: [
            // ==================== BACKGROUND STORY (FOTO / VIDEO / TULISAN) ====================
            Positioned.fill(
              child: currentStory.isVideoStory
                  ? StoryVideoPlayer(
                      videoUrl: currentStory.imageBase64,
                      hasMusic: currentStory.hasMusic,
                    )
                  : (currentStory.isTextStory
                      ? Container(
                          color: _parseHexColor(currentStory.bgColor),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            child: Text(
                              currentStory.caption,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                                shadows: [
                                  Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Image(
                          image: _getImageProvider(currentStory.imageBase64),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60),
                          ),
                        )),
            ),

            // ==================== NAVIGASI KIRI & KANAN TAP ====================
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _previousStory,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _nextStory,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),

            // ==================== OVERLAY PROGRESS BARS & HEADER ====================
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  // Progress Bars per Story
                  Row(
                    children: List.generate(widget.stories.length, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              height: 3,
                              child: index < _currentIndex
                                  ? Container(color: Colors.white)
                                  : index == _currentIndex
                                      ? AnimatedBuilder(
                                          animation: _animController,
                                          builder: (context, child) {
                                            return LinearProgressIndicator(
                                              value: _animController.value,
                                              backgroundColor: Colors.white30,
                                              valueColor: const AlwaysStoppedAnimation<Color>(
                                                Color(0xFFE11D48),
                                              ),
                                            );
                                          },
                                        )
                                      : Container(color: Colors.white30),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Header Info Pengirim Story
                  Row(
                    children: [
                      UserAvatar(
                        email: currentStory.userEmail,
                        name: currentStory.userName,
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
                                    currentStory.userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: tagColor.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: tagColor, width: 0.8),
                                  ),
                                  child: Text(
                                    currentStory.userTag,
                                    style: TextStyle(
                                      color: tagColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  timeAgo,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                  ),
                                ),
                                const Text(' • ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                Icon(
                                  currentStory.targetAudience.contains('Semua')
                                      ? Icons.public_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 11,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    currentStory.targetAudience.contains('Semua')
                                        ? 'Semua Civitas'
                                        : 'Khusus ${currentStory.targetAudience.join(', ')}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (currentStory.hasMusic) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.music_note_rounded, color: Color(0xFFF43F5E), size: 13),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${currentStory.musicTitle ?? "Lagu Jamendo"} • ${currentStory.artistName ?? "Jamendo"}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (currentStory.hasMusic) ...[
                        IconButton(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: _isMuted ? 'Nyalakan Suara' : 'Matikan Suara',
                          onPressed: _toggleMute,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isMe) ...[
                        if (widget.stories.length < 3 && widget.onAddStory != null) ...[
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                            tooltip: 'Tambah Story Foto (${widget.stories.length}/3)',
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onAddStory!();
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                          tooltip: 'Hapus Story Saya',
                          onPressed: () => _handleDeleteStory(currentStory),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==================== CAPTION & FOOTER BAR ====================
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 14,
              left: 14,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!currentStory.isTextStory && currentStory.caption.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        currentStory.caption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.3,
                        ),
                      ),
                    ),

                  if (isMe)
                    // Baris Khusus Pemilik Story (Lihat Penonton)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showViewersModal(currentStory),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.remove_red_eye_rounded, color: Color(0xFFE11D48), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Dilihat oleh ${currentStory.viewers.length} civitas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 18),
                          ],
                        ),
                      ),
                    )
                  else
                    // Baris Balas Story untuk Pengguna Lain
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Balas story ini ke Japri...',
                                hintStyle: TextStyle(color: Colors.white54, fontSize: 12.5),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              onTap: _pauseTimer,
                              onSubmitted: (_) => _handleSendReply(currentStory),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                          ),
                          icon: _isSendingReply
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          onPressed: () => _handleSendReply(currentStory),
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
  }

  Color _parseHexColor(String hexString, {Color fallback = const Color(0xFFE11D48)}) {
    try {
      var hex = hexString.replaceAll('#', '').trim();
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}

class StoryVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool hasMusic;

  const StoryVideoPlayer({
    super.key,
    required this.videoUrl,
    this.hasMusic = false,
  });

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        if (mounted) {
          if (widget.hasMusic) {
            _controller.setVolume(0.0);
          } else {
            _controller.setVolume(1.0);
          }
          _controller.setLooping(true);
          _controller.play();
          setState(() => _isInitialized = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
