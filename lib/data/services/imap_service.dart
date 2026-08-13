import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import '../../core/config/mailcow_config.dart';
import '../models/email_message.dart';
import '../models/attachment_item.dart';
import '../models/folder_info.dart';

class ImapService {
  ImapClient? _client;
  bool _isConnected = false;

  bool get isConnected => _isConnected && (_client?.isLoggedIn ?? false);

  // Connect and login to IMAP server
  Future<bool> connectAndLogin(String email, String password) async {
    if (kIsWeb) return false;
    try {
      await disconnect();

      _client = ImapClient(isLogEnabled: false);
      await _client!.connectToServer(
        MailcowConfig.mailHost,
        MailcowConfig.imapPort,
        isSecure: MailcowConfig.useSsl,
      );

      await _client!.login(email, password);
      _isConnected = _client!.isLoggedIn;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // Disconnect from IMAP server
  Future<void> disconnect() async {
    try {
      if (_client != null && _client!.isConnected) {
        if (_client!.isLoggedIn) {
          await _client!.logout();
        }
        await _client!.disconnect();
      }
    } catch (_) {}
    _client = null;
    _isConnected = false;
  }

  // List all mailbox folders
  Future<List<FolderInfo>> listFolders() async {
    if (!isConnected) return FolderInfo.getDefaultFolders();

    try {
      final mailboxes = await _client!.listMailboxes();
      if (mailboxes.isNotEmpty) {
        final folders = <FolderInfo>[];

        for (final mb in mailboxes) {
          final path = mb.encodedPath;
          FolderType type = FolderType.custom;
          String displayName = mb.name;
          IconData icon = Icons.folder_rounded;

          final lowerPath = path.toLowerCase();
          if (lowerPath == 'inbox') {
            type = FolderType.inbox;
            displayName = 'Kotak Masuk';
            icon = Icons.inbox_rounded;
          } else if (lowerPath.contains('sent')) {
            type = FolderType.sent;
            displayName = 'Terkirim';
            icon = Icons.send_outlined;
          } else if (lowerPath.contains('draft')) {
            type = FolderType.drafts;
            displayName = 'Draf';
            icon = Icons.drafts_outlined;
          } else if (lowerPath.contains('trash') || lowerPath.contains('bin')) {
            type = FolderType.trash;
            displayName = 'Sampah';
            icon = Icons.delete_outline_rounded;
          } else if (lowerPath.contains('junk') || lowerPath.contains('spam')) {
            type = FolderType.spam;
            displayName = 'Spam';
            icon = Icons.report_gmailerrorred_rounded;
          } else if (lowerPath.contains('archive')) {
            type = FolderType.archive;
            displayName = 'Arsip';
            icon = Icons.archive_outlined;
          }

          folders.add(FolderInfo(
            name: displayName,
            path: path,
            type: type,
            unreadCount: mb.messagesExists,
            totalCount: mb.messagesExists,
            icon: icon,
          ));
        }

        // Include Starred folder if not present
        if (!folders.any((f) => f.type == FolderType.starred)) {
          folders.add(FolderInfo(
            name: 'Berbintang',
            path: 'STARRED',
            type: FolderType.starred,
            icon: Icons.star_outline_rounded,
          ));
        }

        // Sort by Gmail priority order (Inbox at top, then Starred, Sent, Drafts, Archive, Spam, Trash)
        folders.sort((a, b) => a.priority.compareTo(b.priority));

        if (folders.isNotEmpty) return folders;
      }
    } catch (_) {}

    return FolderInfo.getDefaultFolders();
  }

  // Fetch messages in selected folder
  Future<List<EmailMessage>> fetchMessages({
    String folderPath = 'INBOX',
    int count = 30,
  }) async {
    if (!isConnected) return [];

    try {
      final mailbox = await _client!.selectMailboxByPath(folderPath);
      final totalMessages = mailbox.messagesExists;
      if (totalMessages == 0) return [];

      final fetchCount = count > totalMessages ? totalMessages : count;
      final fetchResult = await _client!.fetchRecentMessages(
        messageCount: fetchCount,
        criteria: 'BODY.PEEK[]',
      );

      final messages = <EmailMessage>[];
      for (final mimeMsg in fetchResult.messages) {
        final email = _convertMimeToEmailMessage(mimeMsg, folderPath);
        messages.add(email);
      }

      // Sort latest first
      messages.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return messages;
    } catch (e) {
      return [];
    }
  }

  // Mark message as read/unread
  Future<bool> markAsRead(int sequenceId, {bool isRead = true}) async {
    if (!isConnected) return false;
    try {
      final sequence = MessageSequence()..add(sequenceId);
      final flag = MessageFlags.seen;
      if (isRead) {
        await _client!.store(sequence, [flag], action: StoreAction.add);
      } else {
        await _client!.store(sequence, [flag], action: StoreAction.remove);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Flag/Star message
  Future<bool> toggleStarred(int sequenceId, {required bool isStarred}) async {
    if (!isConnected) return false;
    try {
      final sequence = MessageSequence()..add(sequenceId);
      final flag = MessageFlags.flagged;
      if (isStarred) {
        await _client!.store(sequence, [flag], action: StoreAction.add);
      } else {
        await _client!.store(sequence, [flag], action: StoreAction.remove);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Delete message (Move to Trash or flag deleted)
  Future<bool> deleteMessage(int sequenceId) async {
    if (!isConnected) return false;
    try {
      final sequence = MessageSequence()..add(sequenceId);
      await _client!.store(sequence, [MessageFlags.deleted], action: StoreAction.add);
      await _client!.expunge();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Append sent email to Sent mailbox on Mailcow Dovecot server
  Future<bool> appendSentMessage(MimeMessage message, {String folderPath = 'Sent'}) async {
    if (!isConnected) return false;
    try {
      await _client!.appendMessage(
        message,
        targetMailboxPath: folderPath,
        flags: [MessageFlags.seen],
      );
      return true;
    } catch (_) {
      try {
        await _client!.selectMailboxByPath(folderPath);
        await _client!.appendMessage(
          message,
          flags: [MessageFlags.seen],
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // Helper to convert MimeMessage to our EmailMessage
  EmailMessage _convertMimeToEmailMessage(MimeMessage msg, String folder) {
    // From
    final fromMailAddress = msg.from?.isNotEmpty == true ? msg.from!.first : null;
    final fromItem = EmailAddressItem(
      name: fromMailAddress?.personalName ?? '',
      email: fromMailAddress?.email ?? 'unknown@smk.baktinusantara666.sch.id',
    );

    // To
    final toList = <EmailAddressItem>[];
    if (msg.to != null) {
      for (final a in msg.to!) {
        toList.add(EmailAddressItem(
          name: a.personalName ?? '',
          email: a.email,
        ));
      }
    }

    // CC
    final ccList = <EmailAddressItem>[];
    if (msg.cc != null) {
      for (final a in msg.cc!) {
        ccList.add(EmailAddressItem(
          name: a.personalName ?? '',
          email: a.email,
        ));
      }
    }

    // Body
    MimePart? htmlPart;
    MimePart? plainPart;

    if (msg.parts != null) {
      for (final p in msg.parts!) {
        final mime = p.mediaType.text.toLowerCase();
        if (mime.contains('html')) {
          htmlPart = p;
        } else if (mime.contains('plain')) {
          plainPart = p;
        }
      }
    }

    final bodyHtml = htmlPart?.decodeContentText();
    final bodyPlain = plainPart?.decodeContentText() ?? msg.decodeContentText() ?? '';
    final snippet = bodyPlain.isNotEmpty
        ? bodyPlain.replaceAll(RegExp(r'\s+'), ' ').trim()
        : (bodyHtml != null
            ? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()
            : '');

    // Attachments
    final attachments = <AttachmentItem>[];
    if (msg.parts != null && msg.parts!.isNotEmpty) {
      for (final part in msg.parts!) {
        final dispHeader = part.getHeader('Content-Disposition');
        final disposition = dispHeader?.map((h) => h.value).join(' ').toLowerCase() ?? '';
        final isAtt = disposition.contains('attachment') || part.decodeFileName() != null;
        if (isAtt) {
          final fileName = part.decodeFileName() ?? 'lampiran_${attachments.length + 1}';
          final mimeType = part.mediaType.text;
          final contentId = part.getHeader('Content-ID')?.map((h) => h.value).join(' ');

          attachments.add(AttachmentItem(
            fileName: fileName,
            mimeType: mimeType,
            sizeInBytes: 0,
            contentId: contentId,
            data: part.decodeContentBinary(),
            isInline: false,
          ));
        }
      }
    }

    final isRead = msg.hasFlag(MessageFlags.seen);
    final isStarred = msg.hasFlag(MessageFlags.flagged);
    final isAnswered = msg.hasFlag(MessageFlags.answered);

    return EmailMessage(
      sequenceId: msg.sequenceId,
      messageId: msg.sequenceId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      from: fromItem,
      to: toList.isNotEmpty
          ? toList
          : [EmailAddressItem(name: '', email: 'me@smk.baktinusantara666.sch.id')],
      cc: ccList,
      subject: msg.decodeSubject() ?? '(Tanpa Subjek)',
      snippet: snippet.length > 120 ? '${snippet.substring(0, 120)}...' : snippet,
      bodyText: bodyPlain,
      bodyHtml: bodyHtml,
      dateTime: msg.decodeDate() ?? DateTime.now(),
      isRead: isRead,
      isStarred: isStarred,
      isAnswered: isAnswered,
      hasAttachments: attachments.isNotEmpty,
      attachments: attachments,
      folder: folder,
      sizeInBytes: 0,
    );
  }
}
