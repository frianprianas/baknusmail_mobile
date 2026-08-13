import 'dart:typed_data';

class AttachmentItem {
  final String fileName;
  final String mimeType;
  final int sizeInBytes;
  final String? contentId;
  final Uint8List? data;
  final String? localFilePath;
  final bool isInline;

  AttachmentItem({
    required this.fileName,
    required this.mimeType,
    required this.sizeInBytes,
    this.contentId,
    this.data,
    this.localFilePath,
    this.isInline = false,
  });

  bool get isImage =>
      mimeType.startsWith('image/') ||
      fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png') ||
      fileName.endsWith('.gif') ||
      fileName.endsWith('.webp');

  bool get isPdf =>
      mimeType == 'application/pdf' || fileName.endsWith('.pdf');

  bool get isDocument =>
      fileName.endsWith('.doc') ||
      fileName.endsWith('.docx') ||
      fileName.endsWith('.xls') ||
      fileName.endsWith('.xlsx') ||
      fileName.endsWith('.ppt') ||
      fileName.endsWith('.pptx');

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'mimeType': mimeType,
        'sizeInBytes': sizeInBytes,
        'contentId': contentId,
        'localFilePath': localFilePath,
        'isInline': isInline,
      };

  factory AttachmentItem.fromJson(Map<String, dynamic> json) => AttachmentItem(
        fileName: json['fileName'] ?? '',
        mimeType: json['mimeType'] ?? 'application/octet-stream',
        sizeInBytes: json['sizeInBytes'] ?? 0,
        contentId: json['contentId'],
        localFilePath: json['localFilePath'],
        isInline: json['isInline'] ?? false,
      );
}
