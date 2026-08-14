import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgAsset = isDark ? 'assets/images/bg_dark.png' : 'assets/images/bg_light.png';

    return Stack(
      children: [
        // Gambar Background utama berdasar tema aktif
        Positioned.fill(
          child: Image.asset(
            bgAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
        // Overlay proteksi kontras warna agar teks & komponen UI tetap terlihat sangat jelas
        Positioned.fill(
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        // Konten Layanan / Halaman
        Positioned.fill(child: child),
      ],
    );
  }
}
