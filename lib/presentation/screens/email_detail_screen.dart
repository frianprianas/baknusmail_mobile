import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';
import '../../data/models/email_message.dart';
import '../../data/models/attachment_item.dart';
import '../../providers/mail_provider.dart';
import '../widgets/user_avatar.dart';

import '../widgets/app_background.dart';


class EmailDetailScreen extends StatelessWidget {
  const EmailDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! EmailMessage) {
      return const Scaffold(
        body: Center(child: Text('Email tidak ditemukan')),
      );
    }
    final email = args;
    final mail = context.watch<MailProvider>();

    final currentEmail = mail.filteredEmails.firstWhere(
      (e) => e.messageId == email.messageId,
      orElse: () => email,
    );

    final senderName = currentEmail.from.name.isNotEmpty
        ? currentEmail.from.name
        : FormatHelper.extractNameFromEmail(currentEmail.from.email);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              currentEmail.isStarred
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: currentEmail.isStarred ? AppColors.gold : null,
            ),
            tooltip: currentEmail.isStarred ? 'Hapus Bintang' : 'Beri Bintang',
            onPressed: () => mail.toggleStar(currentEmail),
          ),
          IconButton(
            icon: const Icon(Icons.reply_rounded),
            tooltip: 'Balas',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/compose',
                arguments: {
                  'replyTo': currentEmail,
                  'type': 'reply',
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Hapus',
            onPressed: () {
              mail.deleteEmail(currentEmail);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pesan dipindahkan ke Sampah'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject
            Text(
              currentEmail.subject,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),

            // Sender & Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    email: currentEmail.from.email,
                    name: senderName,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          currentEmail.from.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Kepada: ',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                currentEmail.to.map((t) => t.displayName).join(', '),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatHelper.formatFullDateTime(currentEmail.dateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Email Body
            Builder(builder: (context) {
              // Determine what to render
              final htmlToRender = currentEmail.bodyHtml != null &&
                      currentEmail.bodyHtml!.isNotEmpty
                  ? currentEmail.bodyHtml!
                  : _looksLikeHtml(currentEmail.bodyText)
                      ? currentEmail.bodyText
                      : null;

              if (htmlToRender != null) {
                return HtmlWidget(
                  htmlToRender,
                  textStyle: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                );
              } else {
                return SelectableText(
                  currentEmail.bodyText,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                );
              }
            }),

            // Attachments Section
            if (currentEmail.hasAttachments && currentEmail.attachments.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Lampiran (${currentEmail.attachments.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: currentEmail.attachments
                    .map((att) => _buildAttachmentCard(context, att, isDark))
                    .toList(),
              ),
            ],

            const SizedBox(height: 36),

            // Bottom Reply / Forward Bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.reply_rounded, size: 18),
                    label: const Text('Balas'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/compose',
                        arguments: {
                          'replyTo': currentEmail,
                          'type': 'reply',
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.reply_all_rounded, size: 18),
                    label: const Text('Balas Semua'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/compose',
                        arguments: {
                          'replyTo': currentEmail,
                          'type': 'reply_all',
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.forward_rounded, size: 18),
                    label: const Text('Teruskan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/compose',
                        arguments: {
                          'replyTo': currentEmail,
                          'type': 'forward',
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}

  static bool _looksLikeHtml(String text) {
    final t = text.trim().toLowerCase();
    // Check common HTML document starters
    if (t.startsWith('<!doctype html') || t.startsWith('<html')) return true;
    // Check common HTML tag starters (email bodies often start directly with <div> or <table>)
    const htmlTags = ['<div', '<table', '<span', '<p ', '<p>', '<h1', '<h2', '<h3', '<ul', '<ol'];
    for (final tag in htmlTags) {
      if (t.startsWith(tag)) return true;
    }
    // Fallback: detect inline-styled HTML elements anywhere in the first 200 chars
    final preview = t.length > 200 ? t.substring(0, 200) : t;
    return RegExp(r'<(div|table|span|p|h[1-6]|body)\s[^>]*style=').hasMatch(preview);
  }

  Widget _buildAttachmentCard(
      BuildContext context, AttachmentItem att, bool isDark) {
    IconData icon = Icons.insert_drive_file_rounded;
    Color iconColor = AppColors.primary;

    if (att.isPdf) {
      icon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.redAccent;
    } else if (att.isImage) {
      icon = Icons.image_rounded;
      iconColor = Colors.teal;
    } else if (att.isDocument) {
      icon = Icons.description_rounded;
      iconColor = Colors.blue;
    }

    return InkWell(
      onTap: () => _openAttachment(context, att),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.fileName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    FormatHelper.formatFileSize(att.sizeInBytes),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.download_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, AttachmentItem att) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lampiran "${att.fileName}" (${FormatHelper.formatFileSize(att.sizeInBytes)}) siap.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (att.data != null && att.data!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${att.fileName}';
        final file = File(filePath);
        await file.writeAsBytes(att.data!);

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File tersimpan di: $filePath (${result.message})'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (att.localFilePath != null && att.localFilePath!.isNotEmpty) {
        await OpenFilex.open(att.localFilePath!);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Konten lampiran "${att.fileName}" tidak dapat diunduh atau kosong.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka lampiran: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

