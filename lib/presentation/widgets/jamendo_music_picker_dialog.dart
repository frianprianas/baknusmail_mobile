import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/jamendo_music.dart';
import '../../data/services/jamendo_service.dart';

class JamendoMusicPickerDialog extends StatefulWidget {
  final JamendoMusic? initialSelected;

  const JamendoMusicPickerDialog({
    super.key,
    this.initialSelected,
  });

  static Future<JamendoMusic?> show(BuildContext context, {JamendoMusic? initialSelected}) {
    return showModalBottomSheet<JamendoMusic?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JamendoMusicPickerDialog(initialSelected: initialSelected),
    );
  }

  @override
  State<JamendoMusicPickerDialog> createState() => _JamendoMusicPickerDialogState();
}

class _JamendoMusicPickerDialogState extends State<JamendoMusicPickerDialog> {
  final JamendoService _service = JamendoService();
  final AudioPlayer _previewPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  List<JamendoMusic> _tracks = [];
  JamendoMusic? _selectedMusic;
  String? _currentlyPlayingId;
  bool _isLoading = true;
  bool _isPlaying = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedMusic = widget.initialSelected;
    _fetchInitialTracks();

    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _previewPlayer.stop();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialTracks() async {
    setState(() {
      _isLoading = true;
    });
    final results = await _service.fetchTrendingTracks();
    if (mounted) {
      setState(() {
        _tracks = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isLoading = true;
      });
      final results = await _service.searchTracks(query);
      if (mounted) {
        setState(() {
          _tracks = results;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _togglePreview(JamendoMusic track) async {
    if (_currentlyPlayingId == track.id && _isPlaying) {
      await _previewPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _previewPlayer.stop();
      if (track.audioUrl.isNotEmpty) {
        await _previewPlayer.play(UrlSource(track.audioUrl));
        setState(() {
          _currentlyPlayingId = track.id;
          _isPlaying = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Color(0xFFE11D48), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Musik Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Cari ribuan lagu populer, instrumen & audio preview',
                        style: TextStyle(
                          fontSize: 11,
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

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cari judul lagu atau nama artis...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Track List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                  )
                : _tracks.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada lagu yang ditemukan',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          final isSelected = _selectedMusic?.id == track.id;
                          final isThisPlaying = _currentlyPlayingId == track.id && _isPlaying;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE11D48).withValues(alpha: 0.12)
                                  : (isDark ? AppColors.darkSurfaceElevated.withValues(alpha: 0.5) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFE11D48)
                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: track.coverUrl.isNotEmpty
                                        ? Image.network(
                                            track.coverUrl,
                                            width: 46,
                                            height: 46,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 46,
                                              height: 46,
                                              color: Colors.grey.shade300,
                                              child: const Icon(Icons.music_note, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            width: 46,
                                            height: 46,
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.music_note, color: Colors.grey),
                                          ),
                                  ),
                                  InkWell(
                                    onTap: () => _togglePreview(track),
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                track.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13.5,
                                  color: isSelected
                                      ? const Color(0xFFE11D48)
                                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                ),
                              ),
                              subtitle: Text(
                                track.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                  color: isSelected ? const Color(0xFFE11D48) : Colors.grey,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedMusic = track;
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedMusic = track;
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_selectedMusic != null)
                    TextButton.icon(
                      icon: const Icon(Icons.music_off_rounded, color: Colors.redAccent, size: 18),
                      label: const Text('Hapus Musik', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                      onPressed: () {
                        setState(() {
                          _selectedMusic = null;
                        });
                        Navigator.pop(context, null);
                      },
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _selectedMusic != null ? 'Gunakan Musik Ini' : 'Selesai',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: () {
                      Navigator.pop(context, _selectedMusic);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
