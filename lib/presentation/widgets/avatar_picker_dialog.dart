import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/avatar_api_service.dart';
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
  String _statusText = '';

  /// Resize image bytes to 128x128 pixel & return PNG/JPEG bytes
  Future<Uint8List> _resizeTo128(Uint8List originalBytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: 128,
        targetHeight: 128,
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

  /// 1. Pilih Foto dari Galeri/Perangkat
  Future<void> _pickImage() async {
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
            _statusText = 'Mengompresi foto ke 128x128...';
          });

          // Crop & Resize ke 128x128
          final resizedBytes = await _resizeTo128(rawBytes);
          final base64Str = 'data:image/jpeg;base64,${base64Encode(resizedBytes)}';

          setState(() {
            _selectedBytes = resizedBytes;
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

  /// 2. Proses Verifikasi Smart Hybrid AI (Online Gemini -> Auto-Fallback Local -> Simpan Profil)
  Future<void> _processUpload() async {
    if (_base64Image == null) return;

    final auth = context.read<AuthProvider>();
    final avatarApi = context.read<AvatarApiService>();
    final jwtToken = auth.currentUser?.password ?? '';

    setState(() {
      _isProcessing = true;
      _statusText = 'Memeriksa foto dengan Baknus AI Online...';
    });

    await avatarApi.processSmartAvatarUpload(
      jwtToken: jwtToken,
      base64Image: _base64Image!,
      onStatusUpdate: (statusMsg) {
        if (mounted) {
          setState(() {
            _statusText = statusMsg;
          });
        }
      },
      onSuccess: (successMsg) async {
        // Simpan di state local AuthProvider & StorageService
        await auth.updateAvatarState(_base64Image!);

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(successMsg),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
            ),
          );

          Navigator.of(context).pop(true);
        }
      },
      onError: (errorMsg) async {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusText = '';
          });

          await _showResultDialog(
            title: errorMsg.contains("Habis") || errorMsg.contains("Batas")
                ? 'Batas Kuota Harian Habis'
                : 'Foto Ditolak oleh AI',
            message: errorMsg,
            isWarning: true,
          );
        }
      },
    );
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
            child: const Text('Pilih Foto Lain', style: TextStyle(color: Colors.white)),
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
                  'Verifikasi Otomatis BaknusAI',
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

            // Preview Circle Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 12,
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

                  // Overlay Loading Spinner jika sedang verifikasi AI
                  if (_isProcessing)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status Text / Info AI
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                        'Foto akan diverifikasi AI (128x128). Pastikan foto wajah Anda terlihat jelas.',
                        style: TextStyle(fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Tombol Pilih Foto Galeri
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isProcessing ? null : _pickImage,
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: Text(
                  _selectedBytes != null ? 'Pilih Foto Lain' : 'Pilih Foto dari Galeri',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
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
          child: const Text('Verifikasi & Simpan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
