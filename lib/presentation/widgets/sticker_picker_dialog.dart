import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/sticker_item.dart';
import '../../data/services/sticker_service.dart';

class StickerPickerDialog extends StatefulWidget {
  final Function(StickerItem sticker) onStickerSelected;
  final Function(XFile customImage)? onCustomStickerSelected;

  const StickerPickerDialog({
    super.key,
    required this.onStickerSelected,
    this.onCustomStickerSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(StickerItem sticker) onStickerSelected,
    Function(XFile customImage)? onCustomStickerSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StickerPickerDialog(
        onStickerSelected: onStickerSelected,
        onCustomStickerSelected: onCustomStickerSelected,
      ),
    );
  }

  @override
  State<StickerPickerDialog> createState() => _StickerPickerDialogState();
}

class _StickerPickerDialogState extends State<StickerPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<StickerPack> _packs = StickerService.getPacks;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _packs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomSticker() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null && mounted) {
        Navigator.pop(context);
        widget.onCustomStickerSelected?.call(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih stiker kustom: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Drag Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.style_rounded, color: Color(0xFFE11D48), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Pilih Stiker BaknusChat',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _pickCustomSticker,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                        label: const Text(
                          'Stiker Kustom',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Bar Navigation
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFE11D48),
              labelColor: const Color(0xFFE11D48),
              unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12.5),
              tabs: _packs.map((pack) {
                return Tab(
                  text: pack.name,
                );
              }).toList(),
            ),

            const Divider(height: 1),

            // Tab Content Grid View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _packs.map((pack) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: pack.stickers.length,
                    itemBuilder: (context, index) {
                      final sticker = pack.stickers[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onStickerSelected(sticker);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Image.network(
                                      sticker.imageUrl,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) {
                                        return Text(
                                          sticker.emoji ?? '🏷️',
                                          style: const TextStyle(fontSize: 28),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sticker.name,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              if (sticker.effectiveIsAnimated)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE11D48),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'GIF',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
