import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/avatar_api_service.dart';
import '../../data/services/baknus_ai_client_service.dart';
import '../../data/services/baknusmail_profile_service.dart';
import '../../providers/auth_provider.dart';

class AvatarPickerDialog extends StatefulWidget {
  const AvatarPickerDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AvatarPickerDialog(),
    );
  }

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  Uint8List? _selectedBytes;
  String? _base64Image;
  bool _isProcessing = false;
  bool _validateWithAI = true;
  String _statusText = '';

  /// Resize & optimasi image bytes
  Future<Uint8List> _optimizeImage(Uint8List originalBytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: 400,
        targetHeight: 400,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error resizing image: $e');
    }
    return originalBytes;
  }

  /// 1. Pilih Foto dari Galeri/Kamera dengan ImagePicker / FilePicker
  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final rawBytes = await pickedFile.readAsBytes();
        setState(() {
          _isProcessing = true;
          _statusText = 'Mengompresi foto...';
        });

        final optimizedBytes = await _optimizeImage(rawBytes);
        final base64Str = 'data:image/jpeg;base64,${base64Encode(optimizedBytes)}';

        setState(() {
          _selectedBytes = optimizedBytes;
          _base64Image = base64Str;
          _isProcessing = false;
          _statusText = '';
        });
        return;
      }
    } catch (_) {
      // Fallback ke FilePicker jika ImagePicker tidak tersedia / error
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final rawBytes = result.files.single.bytes;
        if (rawBytes != null) {
          setState(() {
            _isProcessing = true;
            _statusText = 'Mengompresi foto...';
          });

          final optimizedBytes = await _optimizeImage(rawBytes);
          final base64Str = 'data:image/jpeg;base64,${base64Encode(optimizedBytes)}';

          setState(() {
            _selectedBytes = optimizedBytes;
            _base64Image = base64Str;
            _isProcessing = false;
            _statusText = '';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
  }

  /// 2. Proses Unggah Foto Profil ke Server BaknusMail
  Future<void> _processUpload() async {
    if (_base64Image == null) return;

    // 1. Cek Kuota Harian (Maksimal 2x Per Hari)
    final canUpload = await BaknusAIClientService.canChangeAvatarToday();
    if (!canUpload) {
      if (mounted) {
        await _showResultDialog(
          title: 'Batas Kuota Harian',
          message: 'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.',
          isWarning: true,
        );
      }
      return;
    }

    final auth = context.read<AuthProvider>();
    final userEmail = auth.currentUser?.email ?? '';

    setState(() {
      _isProcessing = true;
      _statusText = 'sedang discan oleh BaknusAI';
    });

    if (_validateWithAI) {
      final aiResult = await BaknusAIClientService.validateProfilePhoto(
        base64Image: _base64Image!,
      );

      if (!mounted) return;

      if (aiResult['isApproved'] != true) {
        setState(() {
          _isProcessing = false;
          _statusText = '';
        });

        final reason = aiResult['reason']?.toString() ??
            'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.';
        await _showResultDialog(
          title: 'Hasil Scan BaknusAI',
          message: reason,
          isWarning: true,
        );
        return;
      }
    }

    setState(() {
      _statusText = 'Mengunggah foto profil ke server...';
    });

    // Upload ke server backend
    final res = await BaknusMailProfileService.updateProfile(
      email: userEmail,
      avatarBase64: _base64Image,
      validateWithAI: false,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      await BaknusAIClientService.incrementDailyAvatarCount();
      await auth.updateAvatarState(_base64Image!);
      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(res['message'] ?? 'Foto profil berhasil diperbarui!')),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isProcessing = false;
        _statusText = '';
      });

      final errMsg = res['error']?.toString() ??
          'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Dialog Peringatan jika Foto Ditolak AI atau Kuota Habis
  Future<void> _showResultDialog({
    required String title,
    required String message,
    required bool isWarning,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              color: isWarning ? Colors.orange : AppColors.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ganti Foto Profil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Pemindai Otomatis BaknusAI',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

            // Preview Circle Avatar dengan Animasi Scan BaknusAI
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 115,
                    height: 115,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isProcessing
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _selectedBytes != null
                          ? Image.memory(
                              _selectedBytes!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 54,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),

                  // Overlay Animasi Loading Scan BaknusAI
                  if (_isProcessing)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          shape: BoxShape.circle,
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SpinKitRipple(
                              color: AppColors.primary,
                              size: 60,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status Text / Info Scan BaknusAI
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SpinKitThreeBounce(
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusText.isNotEmpty ? _statusText : 'sedang discan oleh BaknusAI',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Foto akan di-scan BaknusAI (Maks 1 orang, tanpa vape/rokok/nude/gestur tidak sopan). Maks 2x/hari.',
                        style: TextStyle(fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Switch Toggle Verifikasi AI Opsional
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _validateWithAI,
              activeTrackColor: AppColors.primary,
              title: const Text(
                'Verifikasi dengan BaknusAI',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Opsional: Memeriksa keselarasan wajah sebelum upload',
                style: TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
              onChanged: _isProcessing
                  ? null
                  : (val) {
                      setState(() => _validateWithAI = val);
                    },
            ),

            const SizedBox(height: 12),

            // Tombol Pilih Foto Galeri & Kamera
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 16),
                    label: const Text(
                      'Galeri HP',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text(
                      'Kamera',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: (_isProcessing || _base64Image == null) ? null : _processUpload,
          child: Text(
            _validateWithAI ? 'Verifikasi & Simpan' : 'Simpan Foto Profil',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
