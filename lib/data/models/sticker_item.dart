class StickerItem {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final String? emoji;
  final bool isAnimated;

  const StickerItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    this.emoji,
    this.isAnimated = false,
  });

  bool get effectiveIsAnimated => isAnimated || imageUrl.toLowerCase().endsWith('.gif');

  factory StickerItem.fromMap(Map<String, dynamic> map) {
    return StickerItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Sticker',
      imageUrl: map['imageUrl']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Umum',
      emoji: map['emoji']?.toString(),
      isAnimated: map['isAnimated'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'category': category,
        if (emoji != null) 'emoji': emoji,
        'isAnimated': isAnimated,
      };
}

class StickerPack {
  final String id;
  final String name;
  final String icon;
  final List<StickerItem> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.icon,
    required this.stickers,
  });
}
