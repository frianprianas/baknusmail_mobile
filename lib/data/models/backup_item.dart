import 'baknus_service_models.dart';

class BackupItem {
  final String backupId;
  final String filename;
  final int fileSize;
  final String backupType;
  final int messageCount;
  final DateTime createdAt;
  final String downloadUrl;

  BackupItem({
    required this.backupId,
    required this.filename,
    required this.fileSize,
    required this.backupType,
    required this.messageCount,
    required this.createdAt,
    required this.downloadUrl,
  });

  factory BackupItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BackupItem(
      backupId: json['backup_id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'backup.json',
      fileSize: int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      backupType: json['backup_type']?.toString() ?? 'auto',
      messageCount: int.tryParse(json['message_count']?.toString() ?? '0') ?? 0,
      createdAt: parseDate(json['created_at']),
      downloadUrl: json['download_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backup_id': backupId,
      'filename': filename,
      'file_size': fileSize,
      'backup_type': backupType,
      'message_count': messageCount,
      'created_at': createdAt.toIso8601String(),
      'download_url': downloadUrl,
    };
  }

  BaknusDriveBackup toBaknusDriveBackup() {
    return BaknusDriveBackup(
      backupId: backupId,
      filename: filename,
      fileSize: fileSize,
      backupType: backupType,
      messageCount: messageCount,
      createdAt: createdAt,
      downloadUrl: downloadUrl,
    );
  }
}
