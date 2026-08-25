import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/app_colors.dart';

class VoiceNotePlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int? initialDurationSec;
  final bool isMe;
  final bool isDark;

  const VoiceNotePlayerWidget({
    super.key,
    required this.audioUrl,
    this.initialDurationSec,
    required this.isMe,
    required this.isDark,
  });

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    if (widget.initialDurationSec != null && widget.initialDurationSec! > 0) {
      _duration = Duration(seconds: widget.initialDurationSec!);
    }

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = false;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.audioUrl.isEmpty) return;
      setState(() => _isLoading = true);
      try {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMe ? Colors.white : AppColors.primary;
    final inactiveColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.4)
        : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder);

    final totalSec = _duration.inSeconds > 0 ? _duration.inSeconds : (widget.initialDurationSec ?? 10);
    final currentSec = _position.inSeconds.clamp(0, totalSec);
    final progress = totalSec > 0 ? currentSec / totalSec : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.black.withValues(alpha: 0.15)
            : (widget.isDark ? AppColors.darkSurface : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isMe
              ? Colors.white24
              : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause Button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: widget.isMe ? 0.25 : 0.15),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: activeColor,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: activeColor,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Audio Waveform Bar & Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform bar visualizer
                SizedBox(
                  height: 20,
                  child: Row(
                    children: List.generate(24, (index) {
                      final itemProgress = index / 24;
                      final isActive = itemProgress <= progress;
                      // Simulated waveform heights
                      final heights = [8.0, 14.0, 18.0, 10.0, 16.0, 6.0, 12.0, 18.0, 14.0, 8.0, 16.0, 10.0, 18.0, 12.0, 6.0, 14.0, 16.0, 10.0, 18.0, 12.0, 8.0, 14.0, 10.0, 6.0];
                      final barHeight = heights[index % heights.length];

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isActive ? activeColor : inactiveColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.isMe ? Colors.white70 : (widget.isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 11,
                          color: widget.isMe ? Colors.white70 : AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatDuration(_duration.inSeconds > 0 ? _duration : Duration(seconds: totalSec)),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.isMe ? Colors.white70 : (widget.isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                        ),
                      ],
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
}
