import 'attachment_item.dart';

class EmailAddressItem {
  final String name;
  final String email;

  EmailAddressItem({required this.name, required this.email});

  String get displayName => name.isNotEmpty ? name : email;

  Map<String, dynamic> toJson() => {'name': name, 'email': email};

  factory EmailAddressItem.fromJson(Map<String, dynamic> json) =>
      EmailAddressItem(
        name: json['name'] ?? '',
        email: json['email'] ?? '',
      );

  @override
  String toString() => name.isNotEmpty ? '$name <$email>' : email;
}

class EmailMessage {
  final int? sequenceId;
  final String messageId;
  final EmailAddressItem from;
  final List<EmailAddressItem> to;
  final List<EmailAddressItem> cc;
  final List<EmailAddressItem> bcc;
  final String subject;
  final String snippet;
  final String bodyText;
  final String? bodyHtml;
  final DateTime dateTime;
  final bool isRead;
  final bool isStarred;
  final bool isAnswered;
  final bool hasAttachments;
  final List<AttachmentItem> attachments;
  final String folder;
  final int sizeInBytes;

  EmailMessage({
    this.sequenceId,
    required this.messageId,
    required this.from,
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    required this.subject,
    required this.snippet,
    required this.bodyText,
    this.bodyHtml,
    required this.dateTime,
    this.isRead = false,
    this.isStarred = false,
    this.isAnswered = false,
    this.hasAttachments = false,
    this.attachments = const [],
    this.folder = 'INBOX',
    this.sizeInBytes = 0,
  });

  EmailMessage copyWith({
    int? sequenceId,
    String? messageId,
    EmailAddressItem? from,
    List<EmailAddressItem>? to,
    List<EmailAddressItem>? cc,
    List<EmailAddressItem>? bcc,
    String? subject,
    String? snippet,
    String? bodyText,
    String? bodyHtml,
    DateTime? dateTime,
    bool? isRead,
    bool? isStarred,
    bool? isAnswered,
    bool? hasAttachments,
    List<AttachmentItem>? attachments,
    String? folder,
    int? sizeInBytes,
  }) {
    return EmailMessage(
      sequenceId: sequenceId ?? this.sequenceId,
      messageId: messageId ?? this.messageId,
      from: from ?? this.from,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      bodyText: bodyText ?? this.bodyText,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      dateTime: dateTime ?? this.dateTime,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      isAnswered: isAnswered ?? this.isAnswered,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      attachments: attachments ?? this.attachments,
      folder: folder ?? this.folder,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'sequenceId': sequenceId,
        'messageId': messageId,
        'from': from.toJson(),
        'to': to.map((e) => e.toJson()).toList(),
        'cc': cc.map((e) => e.toJson()).toList(),
        'bcc': bcc.map((e) => e.toJson()).toList(),
        'subject': subject,
        'snippet': snippet,
        'bodyText': bodyText,
        'bodyHtml': bodyHtml,
        'dateTime': dateTime.toIso8601String(),
        'isRead': isRead,
        'isStarred': isStarred,
        'isAnswered': isAnswered,
        'hasAttachments': hasAttachments,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'folder': folder,
        'sizeInBytes': sizeInBytes,
      };

  factory EmailMessage.fromJson(Map<String, dynamic> json) => EmailMessage(
        sequenceId: json['sequenceId'],
        messageId: json['messageId'] ?? '',
        from: EmailAddressItem.fromJson(json['from'] ?? {}),
        to: (json['to'] as List? ?? [])
            .map((e) => EmailAddressItem.fromJson(e))
            .toList(),
        cc: (json['cc'] as List? ?? [])
            .map((e) => EmailAddressItem.fromJson(e))
            .toList(),
        bcc: (json['bcc'] as List? ?? [])
            .map((e) => EmailAddressItem.fromJson(e))
            .toList(),
        subject: json['subject'] ?? '',
        snippet: json['snippet'] ?? '',
        bodyText: json['bodyText'] ?? '',
        bodyHtml: json['bodyHtml'],
        dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
        isRead: json['isRead'] ?? false,
        isStarred: json['isStarred'] ?? false,
        isAnswered: json['isAnswered'] ?? false,
        hasAttachments: json['hasAttachments'] ?? false,
        attachments: (json['attachments'] as List? ?? [])
            .map((e) => AttachmentItem.fromJson(e))
            .toList(),
        folder: json['folder'] ?? 'INBOX',
        sizeInBytes: json['sizeInBytes'] ?? 0,
      );
}
