class JamendoMusic {
  final String id;
  final String name;
  final String artistName;
  final String audioUrl;
  final String coverUrl;
  final int duration; // dalam detik

  JamendoMusic({
    required this.id,
    required this.name,
    required this.artistName,
    required this.audioUrl,
    required this.coverUrl,
    this.duration = 0,
  });

  factory JamendoMusic.fromJson(Map<String, dynamic> json) {
    return JamendoMusic(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Tanpa Judul',
      artistName: json['artist_name']?.toString() ?? 'Unknown Artist',
      audioUrl: json['audio']?.toString() ?? '',
      coverUrl: json['image']?.toString() ?? json['album_image']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] : (int.tryParse(json['duration']?.toString() ?? '0') ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artist_name': artistName,
        'audio': audioUrl,
        'image': coverUrl,
        'duration': duration,
      };
}
