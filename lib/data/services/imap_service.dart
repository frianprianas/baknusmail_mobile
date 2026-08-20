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
  String? _savedEmail;
  String? _savedPassword;

  bool get isConnected => _isConnected && (_client?.isLoggedIn ?? false);

  // Connect and login to IMAP server
  Future<bool> connectAndLogin(String email, String password) async {
    if (kIsWeb) return false;
    _savedEmail = email;
    _savedPassword = password;
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

  // Ensure IMAP is connected, auto-reconnecting if socket dropped
  Future<bool> ensureConnected([String? email, String? password]) async {
    if (email != null && email.isNotEmpty) _savedEmail = email;
    if (password != null && password.isNotEmpty) _savedPassword = password;

    if (isConnected) return true;
    if (_savedEmail != null && _savedPassword != null && _savedPassword!.isNotEmpty) {
      return await connectAndLogin(_savedEmail!, _savedPassword!);
    }
    return false;
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
    if (!await ensureConnected()) return FolderInfo.getDefaultFolders();

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

        // Sort by Gmail priority order
        folders.sort((a, b) => a.priority.compareTo(b.priority));

        if (folders.isNotEmpty) return folders;
      }
    } catch (_) {
      _isConnected = false;
    }

    return FolderInfo.getDefaultFolders();
  }

  // Fetch messages in selected folder (with pagination)
  Future<List<EmailMessage>> fetchMessages({
    String folderPath = 'INBOX',
    int count = 30,
    int offset = 0,
  }) async {
    if (!await ensureConnected()) return [];

    try {
      final mailbox = await _client!.selectMailboxByPath(folderPath);
      try {
        await _client!.noop(); // Force server to report newly arrived messages
      } catch (_) {}

      final totalMessages = mailbox.messagesExists;
      if (totalMessages == 0) return [];

      int endId = totalMessages - offset;
      if (endId <= 0) return []; // No more messages to fetch

      int startId = endId - count + 1;
      if (startId <= 0) startId = 1;

      final sequence = MessageSequence()..addRange(startId, endId);
      final fetchResult = await _client!.fetchMessages(
        sequence,
        '(FLAGS UID BODY.PEEK[])',
      );

      final messages = <EmailMessage>[];
      for (final mimeMsg in fetchResult.messages) {
        final email = _convertMimeToEmailMessage(mimeMsg, folderPath);
        messages.add(email);
      }

      // Sort latest first (by date and sequence ID)
      messages.sort((a, b) {
        final dateCmp = b.dateTime.compareTo(a.dateTime);
        if (dateCmp != 0) return dateCmp;
        return (b.sequenceId ?? 0).compareTo(a.sequenceId ?? 0);
      });
      return messages;
    } catch (e) {
      debugPrint('IMAP fetch error: $e. Reconnecting...');
      _isConnected = false;
      if (await ensureConnected()) {
        try {
          final mailbox = await _client!.selectMailboxByPath(folderPath);
          try {
            await _client!.noop();
          } catch (_) {}

          final totalMessages = mailbox.messagesExists;
          if (totalMessages == 0) return [];

          int endId = totalMessages - offset;
          if (endId <= 0) return []; // No more messages to fetch

          int startId = endId - count + 1;
          if (startId <= 0) startId = 1;

          final sequence = MessageSequence()..addRange(startId, endId);
          final fetchResult = await _client!.fetchMessages(
            sequence,
            '(FLAGS UID BODY.PEEK[])',
          );

          final messages = <EmailMessage>[];
          for (final mimeMsg in fetchResult.messages) {
            final email = _convertMimeToEmailMessage(mimeMsg, folderPath);
            messages.add(email);
          }

          messages.sort((a, b) {
            final dateCmp = b.dateTime.compareTo(a.dateTime);
            if (dateCmp != 0) return dateCmp;
            return (b.sequenceId ?? 0).compareTo(a.sequenceId ?? 0);
          });
          return messages;
        } catch (_) {}
      }
      return [];
    }
  }

  // Mark message as read/unread
  Future<bool> markAsRead(int sequenceId, {bool isRead = true, String folderPath = 'INBOX'}) async {
    if (!isConnected) return false;
    try {
      await _client!.selectMailboxByPath(folderPath);
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

  // Mark message as read/unread using UID
  Future<bool> markAsReadByUid(int uid, {bool isRead = true, String folderPath = 'INBOX'}) async {
    if (!isConnected) return false;
    try {
      await _client!.selectMailboxByPath(folderPath);
      final sequence = MessageSequence()..add(uid);
      final flag = MessageFlags.seen;
      if (isRead) {
        await _client!.uidStore(sequence, [flag], action: StoreAction.add);
      } else {
        await _client!.uidStore(sequence, [flag], action: StoreAction.remove);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Flag/Star message
  Future<bool> toggleStarred(int sequenceId, {required bool isStarred, String folderPath = 'INBOX'}) async {
    if (!isConnected) return false;
    try {
      await _client!.selectMailboxByPath(folderPath);
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

  // Flag/Star message using UID
  Future<bool> toggleStarredByUid(int uid, {required bool isStarred, String folderPath = 'INBOX'}) async {
    if (!isConnected) return false;
    try {
      await _client!.selectMailboxByPath(folderPath);
      final sequence = MessageSequence()..add(uid);
      final flag = MessageFlags.flagged;
      if (isStarred) {
        await _client!.uidStore(sequence, [flag], action: StoreAction.add);
      } else {
        await _client!.uidStore(sequence, [flag], action: StoreAction.remove);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Delete message (Move to Trash or flag deleted)
  Future<bool> deleteMessage(int sequenceId, {String folderPath = 'INBOX'}) async {
    if (!isConnected) return false;
    try {
      await _client!.selectMailboxByPath(folderPath);
      final sequence = MessageSequence()..add(sequenceId);
      await _client!.store(sequence, [MessageFlags.deleted], action: StoreAction.add);
      await _client!.expunge();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Delete message using UID
  Future<bool> deleteMessageByUid(int uid, {String folderPath = 'INBOX'}) async {
    if (!isConnected) return false;
    try {
      await _client!.selectMailboxByPath(folderPath);
      final sequence = MessageSequence()..add(uid);
      await _client!.uidStore(sequence, [MessageFlags.deleted], action: StoreAction.add);
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

    void findParts(List<MimePart> parts) {
      for (final p in parts) {
        final mime = p.mediaType.text.toLowerCase();
        if (mime.contains('html') && htmlPart == null) {
          htmlPart = p;
        } else if (mime.contains('plain') && plainPart == null) {
          plainPart = p;
        }
        if (p.parts != null && p.parts!.isNotEmpty) {
          findParts(p.parts!);
        }
      }
    }

    if (msg.parts != null && msg.parts!.isNotEmpty) {
      findParts(msg.parts!);
    }

    final rawBodyHtml = htmlPart?.decodeContentText();
    final rawBodyPlain = plainPart?.decodeContentText() ?? msg.decodeContentText() ?? '';

    // Strip HTML tags and common HTML entities for a clean plain-text snippet
    String stripHtml(String html) {
      return html
          .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), ' ')
          .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    // Detect if the "plain" body is actually HTML (e.g. email sent as text/plain but body is HTML)
    bool isHtmlContent(String text) {
      final t = text.trim().toLowerCase();
      if (t.startsWith('<!doctype html') || t.startsWith('<html')) return true;
      const htmlTags = ['<div', '<table', '<span', '<p ', '<p>', '<h1', '<h2', '<h3', '<ul', '<ol'];
      for (final tag in htmlTags) {
        if (t.startsWith(tag)) return true;
      }
      final preview = t.length > 200 ? t.substring(0, 200) : t;
      return RegExp(r'<(div|table|span|p|h[1-6]|body)\s[^>]*style=').hasMatch(preview);
    }

    // If bodyPlain looks like HTML, promote it to bodyHtml
    final String? bodyHtml =
        rawBodyHtml ?? (isHtmlContent(rawBodyPlain) ? rawBodyPlain : null);
    final String bodyPlain =
        isHtmlContent(rawBodyPlain) ? stripHtml(rawBodyPlain) : rawBodyPlain;

    final snippet = bodyPlain.trim().isNotEmpty
        ? bodyPlain.replaceAll(RegExp(r'\s+'), ' ').trim()
        : (bodyHtml != null ? stripHtml(bodyHtml) : '');

    // Attachments
    final attachments = <AttachmentItem>[];

    void processPart(MimePart part) {
      final dispHeader = part.getHeader('Content-Disposition');
      final disposition = dispHeader?.map((h) => h.value).join(' ').toLowerCase() ?? '';
      final fileName = part.decodeFileName();
      final mimeType = part.mediaType.text.toLowerCase();

      final isExplicitAttachment = disposition.contains('attachment');
      final hasFileName = fileName != null && fileName.trim().isNotEmpty;
      final isInlineWithFileName = disposition.contains('inline') && hasFileName;
      final isNonTextAttachment = !mimeType.contains('text/plain') &&
          !mimeType.contains('text/html') &&
          !mimeType.contains('multipart/') &&
          hasFileName;

      if (isExplicitAttachment || isInlineWithFileName || isNonTextAttachment) {
        final ext = part.mediaType.text.contains('/') ? part.mediaType.text.split('/').last : 'bin';
        final finalFileName = hasFileName
            ? fileName
            : 'lampiran_${attachments.length + 1}.$ext';
        final contentId = part.getHeader('Content-ID')?.map((h) => h.value).join(' ');
        final binaryData = part.decodeContentBinary();

        int calcSize = binaryData?.length ?? 0;
        if (calcSize == 0) {
          final contentLengthHeader = part.getHeader('Content-Length');
          if (contentLengthHeader != null && contentLengthHeader.isNotEmpty) {
            final headerVal = contentLengthHeader.first.value;
            if (headerVal != null) {
              calcSize = int.tryParse(headerVal.trim()) ?? 0;
            }
          }
        }

        attachments.add(AttachmentItem(
          fileName: finalFileName,
          mimeType: part.mediaType.text,
          sizeInBytes: calcSize,
          contentId: contentId,
          data: binaryData,
          isInline: disposition.contains('inline'),
        ));
      }

      // Check child parts (e.g. multipart/mixed, multipart/related, etc.)
      if (part.parts != null && part.parts!.isNotEmpty) {
        for (final child in part.parts!) {
          processPart(child);
        }
      }
    }

    if (msg.parts != null && msg.parts!.isNotEmpty) {
      for (final p in msg.parts!) {
        processPart(p);
      }
    } else if (msg.decodeFileName() != null) {
      final binaryData = msg.decodeContentBinary();
      int calcSize = binaryData?.length ?? 0;
      if (calcSize == 0) {
        final contentLengthHeader = msg.getHeader('Content-Length');
        if (contentLengthHeader != null && contentLengthHeader.isNotEmpty) {
          final headerVal = contentLengthHeader.first.value;
          if (headerVal != null) {
            calcSize = int.tryParse(headerVal.trim()) ?? 0;
          }
        }
      }

      attachments.add(AttachmentItem(
        fileName: msg.decodeFileName()!,
        mimeType: msg.mediaType.text,
        sizeInBytes: calcSize,
        data: binaryData,
      ));
    }



    final isRead = msg.hasFlag(MessageFlags.seen);
    final isStarred = msg.hasFlag(MessageFlags.flagged);
    final isAnswered = msg.hasFlag(MessageFlags.answered);

    return EmailMessage(
      sequenceId: msg.sequenceId,
      messageId: msg.uid?.toString() ?? msg.sequenceId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
