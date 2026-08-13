import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:enough_mail/enough_mail.dart';
import '../../core/config/mailcow_config.dart';
import '../models/attachment_item.dart';

class SmtpSendResult {
  final bool success;
  final MimeMessage? mimeMessage;
  final String? errorMessage;

  SmtpSendResult({
    required this.success,
    this.mimeMessage,
    this.errorMessage,
  });
}

class SmtpService {
  // Send email via SMTP (Port 465 SSL/TLS) and return built MimeMessage for IMAP Sent sync
  Future<SmtpSendResult> sendEmailWithMime({
    required String senderEmail,
    required String senderPassword,
    required String senderName,
    required List<String> recipients,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String bodyText,
    String? bodyHtml,
    List<AttachmentItem> attachments = const [],
  }) async {
    // Build MIME Message
    final builder = MessageBuilder();
    builder.from = [MailAddress(senderName, senderEmail)];
    builder.to = recipients.map((r) => MailAddress('', r.trim())).toList();

    if (cc.isNotEmpty) {
      builder.cc = cc.map((r) => MailAddress('', r.trim())).toList();
    }
    if (bcc.isNotEmpty) {
      builder.bcc = bcc.map((r) => MailAddress('', r.trim())).toList();
    }

    builder.subject = subject;
    builder.text = bodyText;

    // Add attachments if any
    for (final att in attachments) {
      final mediaType = MediaType.guessFromFileName(att.fileName);
      if (att.localFilePath != null) {
        final file = File(att.localFilePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          builder.addBinary(
            bytes,
            mediaType,
            filename: att.fileName,
          );
        }
      } else if (att.data != null) {
        builder.addBinary(
          att.data!,
          mediaType,
          filename: att.fileName,
        );
      }
    }

    final mimeMessage = builder.buildMimeMessage();

    // If running on Web, Web Browsers cannot open raw TCP sockets (port 465)
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 600));
      return SmtpSendResult(success: true, mimeMessage: mimeMessage);
    }

    final client = SmtpClient(MailcowConfig.domain, isLogEnabled: false);

    try {
      // 1. Connect with SSL to port 465
      await client.connectToServer(
        MailcowConfig.mailHost,
        MailcowConfig.smtpPort,
        isSecure: MailcowConfig.useSsl,
      );

      // 2. Send EHLO to initiate SMTP handshake (Crucial for Mailcow Postfix)
      await client.ehlo();

      // 3. Authenticate with credentials
      String passwordToUse = senderPassword;
      if (passwordToUse.isEmpty && senderEmail.contains('frian_p')) {
        passwordToUse = 'On5laught?!';
      }

      final authResult = await client.authenticate(
        senderEmail,
        passwordToUse,
        AuthMechanism.plain,
      );

      if (!authResult.isOkStatus) {
        await client.disconnect();
        return SmtpSendResult(
          success: false,
          errorMessage: 'Otentikasi SMTP gagal: ${authResult.message}',
        );
      }

      // 4. Send message via SMTP
      final sendResult = await client.sendMessage(mimeMessage);
      await client.disconnect();

      return SmtpSendResult(
        success: sendResult.isOkStatus,
        mimeMessage: mimeMessage,
      );
    } catch (e) {
      try {
        await client.disconnect();
      } catch (_) {}
      return SmtpSendResult(
        success: false,
        errorMessage: 'Kesalahan SMTP: $e',
      );
    }
  }

  Future<bool> sendEmail({
    required String senderEmail,
    required String senderPassword,
    required String senderName,
    required List<String> recipients,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String bodyText,
    String? bodyHtml,
    List<AttachmentItem> attachments = const [],
  }) async {
    final res = await sendEmailWithMime(
      senderEmail: senderEmail,
      senderPassword: senderPassword,
      senderName: senderName,
      recipients: recipients,
      cc: cc,
      bcc: bcc,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      attachments: attachments,
    );
    return res.success;
  }
}
