import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';
import '../../data/models/attachment_item.dart';
import '../../data/models/email_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mail_provider.dart';
import '../../providers/mailcow_provider.dart';
import '../widgets/user_avatar.dart';

import '../widgets/app_background.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  final FocusNode _toFocusNode = FocusNode();
  final FocusNode _bodyFocusNode = FocusNode();

  final List<String> _toRecipients = [];
  final List<String> _ccRecipients = [];
  final List<String> _bccRecipients = [];
  final List<AttachmentItem> _attachments = [];

  bool _showCcBcc = false;
  bool _isSending = false;
  bool _isInitialized = false;

  List<Map<String, String>> _galSuggestions = [];
  String _activeField = 'to';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _handleArguments();
    }
  }

  void _handleArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final EmailMessage? replyTo = args['replyTo'];
      final String type = args['type'] ?? '';

      if (replyTo != null) {
        if (type == 'reply') {
          _toRecipients.add(replyTo.from.email);
          _subjectController.text = replyTo.subject.startsWith('Re:')
              ? replyTo.subject
              : 'Re: ${replyTo.subject}';
          _bodyController.text =
              '\n\n---\nPada ${FormatHelper.formatFullDateTime(replyTo.dateTime)}, ${replyTo.from.displayName} menulis:\n> ${replyTo.snippet}';
        } else if (type == 'reply_all') {
          _toRecipients.add(replyTo.from.email);
          for (final t in replyTo.to) {
            if (!_toRecipients.contains(t.email)) {
              _toRecipients.add(t.email);
            }
          }
          _subjectController.text = replyTo.subject.startsWith('Re:')
              ? replyTo.subject
              : 'Re: ${replyTo.subject}';
          _bodyController.text =
              '\n\n---\nPada ${FormatHelper.formatFullDateTime(replyTo.dateTime)}, ${replyTo.from.displayName} menulis:\n> ${replyTo.snippet}';
        } else if (type == 'forward') {
          _subjectController.text = replyTo.subject.startsWith('Fwd:')
              ? replyTo.subject
              : 'Fwd: ${replyTo.subject}';
          _bodyController.text =
              '\n\n---------- Pesan yang Diteruskan ---------\nPengirim: ${replyTo.from.displayName} <${replyTo.from.email}>\nTanggal: ${FormatHelper.formatFullDateTime(replyTo.dateTime)}\nSubjek: ${replyTo.subject}\n\n${replyTo.bodyText}';
        }
      }
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _toFocusNode.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            _attachments.add(
              AttachmentItem(
                fileName: f.name,
                mimeType: 'application/octet-stream',
                sizeInBytes: f.size,
                localFilePath: f.path,
                data: f.bytes,
              ),
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _searchGal(String query, String field) async {
    _activeField = field;
    if (query.trim().isEmpty) {
      setState(() => _galSuggestions = []);
      return;
    }
    final mailcow = context.read<MailcowProvider>();
    final results = await mailcow.searchDirectory(query);
    if (mounted) {
      setState(() => _galSuggestions = results);
    }
  }

  void _addRecipient(
      String input, List<String> targetList, TextEditingController controller) {
    var email = input.trim();
    if (email.isEmpty) return;
    if (!email.contains('@')) {
      email = '$email@${MailcowConfig.domain}';
    }
    if (!targetList.contains(email)) {
      setState(() {
        targetList.add(email);
        controller.clear();
        _galSuggestions = [];
      });
    }
  }

  Future<void> _sendEmail() async {
    // Check pending text in input fields
    if (_toController.text.trim().isNotEmpty) {
      _addRecipient(_toController.text, _toRecipients, _toController);
    }
    if (_ccController.text.trim().isNotEmpty) {
      _addRecipient(_ccController.text, _ccRecipients, _ccController);
    }
    if (_bccController.text.trim().isNotEmpty) {
      _addRecipient(_bccController.text, _bccRecipients, _bccController);
    }

    if (_toRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap tambahkan minimal satu penerima (Kepada)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final mail = context.read<MailProvider>();
    final subject = _subjectController.text.trim().isNotEmpty
        ? _subjectController.text.trim()
        : '(Tanpa Subjek)';
    final body = _bodyController.text;

    final success = await mail.sendEmail(
      recipients: _toRecipients,
      cc: _ccRecipients,
      bcc: _bccRecipients,
      subject: subject,
      bodyText: body,
      attachments: _attachments,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Pesan berhasil dikirim via Mailcow Server'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim pesan. Periksa koneksi SMTP.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyQuickFormat(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      _bodyController.text = newText;
      _bodyController.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.end + prefix.length,
      );
    } else {
      _bodyController.text = '$text$prefix$suffix';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
        title: const Text(
          'Tulis Pesan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          // Attach File Button with Count Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file_rounded),
                tooltip: 'Lampirkan Berkas',
                onPressed: _pickAttachment,
              ),
              if (_attachments.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_attachments.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Send Button
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
              icon: _isSending
                  ? const SpinKitFadingCircle(color: Colors.white, size: 16)
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _isSending ? 'Mengirim...' : 'Kirim',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _isSending ? null : _sendEmail,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Sender (Dari) Header Card
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          email: currentUser?.email ?? '',
                          name: currentUser?.displayName ?? 'User',
                          radius: 14,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Dari:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${currentUser?.displayName} <${currentUser?.email}>',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Recipients: Kepada (To)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: 60,
                            child: Text(
                              'Kepada:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ..._toRecipients.map((r) => _buildRecipientChip(
                                    email: r,
                                    onDeleted: () => setState(
                                        () => _toRecipients.remove(r)),
                                    isDark: isDark,
                                  )),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minWidth: 140),
                                child: TextField(
                                  controller: _toController,
                                  focusNode: _toFocusNode,
                                  onChanged: (val) => _searchGal(val, 'to'),
                                  onSubmitted: (val) => _addRecipient(
                                      val, _toRecipients, _toController),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Ketik username / nama guru/siswa...',
                                    border: InputBorder.none,
                                    isDense: true,
                                    filled: false,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Toggle CC/BCC Button
                        InkWell(
                          onTap: () =>
                              setState(() => _showCcBcc = !_showCcBcc),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _showCcBcc
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : (isDark
                                      ? AppColors.darkSurfaceElevated
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _showCcBcc ? 'Tutup' : 'Cc/Bcc',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _showCcBcc
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. CC / BCC Expandable Fields
                  if (_showCcBcc) ...[
                    // CC Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: 60,
                              child: Text(
                                'Cc:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ..._ccRecipients.map((r) => _buildRecipientChip(
                                      email: r,
                                      onDeleted: () => setState(
                                          () => _ccRecipients.remove(r)),
                                      isDark: isDark,
                                    )),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minWidth: 120),
                                  child: TextField(
                                    controller: _ccController,
                                    onChanged: (val) => _searchGal(val, 'cc'),
                                    onSubmitted: (val) => _addRecipient(
                                        val, _ccRecipients, _ccController),
                                    decoration: const InputDecoration(
                                      hintText: 'Email CC...',
                                      border: InputBorder.none,
                                      isDense: true,
                                      filled: false,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // BCC Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: 60,
                              child: Text(
                                'Bcc:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ..._bccRecipients.map((r) => _buildRecipientChip(
                                      email: r,
                                      onDeleted: () => setState(
                                          () => _bccRecipients.remove(r)),
                                      isDark: isDark,
                                    )),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minWidth: 120),
                                  child: TextField(
                                    controller: _bccController,
                                    onChanged: (val) =>
                                        _searchGal(val, 'bcc'),
                                    onSubmitted: (val) => _addRecipient(
                                        val, _bccRecipients, _bccController),
                                    decoration: const InputDecoration(
                                      hintText: 'Email BCC...',
                                      border: InputBorder.none,
                                      isDense: true,
                                      filled: false,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 4. GAL Directory Auto-Complete Suggestions Dropdown
                  if (_galSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _galSuggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                        itemBuilder: (context, idx) {
                          final item = _galSuggestions[idx];
                          final name = item['name'] ?? '';
                          final email = item['email'] ?? '';
                          return ListTile(
                            dense: true,
                            leading: UserAvatar(
                              email: email,
                              name: name,
                              radius: 16,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            onTap: () {
                              if (_activeField == 'cc') {
                                _addRecipient(
                                    email, _ccRecipients, _ccController);
                              } else if (_activeField == 'bcc') {
                                _addRecipient(
                                    email, _bccRecipients, _bccController);
                              } else {
                                _addRecipient(
                                    email, _toRecipients, _toController);
                              }
                            },
                          );
                        },
                      ),
                    ),

                  // 5. Subject Row
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: TextField(
                      controller: _subjectController,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Subjek Pesan',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),

                  // 6. Formatting Quick Toolbar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildFormatBtn(
                          icon: Icons.format_bold_rounded,
                          tooltip: 'Tebal',
                          onTap: () => _applyQuickFormat('**', '**'),
                        ),
                        _buildFormatBtn(
                          icon: Icons.format_italic_rounded,
                          tooltip: 'Miring',
                          onTap: () => _applyQuickFormat('*', '*'),
                        ),
                        _buildFormatBtn(
                          icon: Icons.format_list_bulleted_rounded,
                          tooltip: 'Daftar Poin',
                          onTap: () => _applyQuickFormat('\n- ', ''),
                        ),
                        _buildFormatBtn(
                          icon: Icons.format_quote_rounded,
                          tooltip: 'Kutipan',
                          onTap: () => _applyQuickFormat('\n> ', ''),
                        ),
                        const Spacer(),
                        Text(
                          '${_bodyController.text.length} karakter',
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

                  // 7. Attachments Preview List
                  if (_attachments.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : const Color(0xFFF8FAFC),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.attachment_rounded,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Lampiran (${_attachments.length} berkas)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _attachments.map((att) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 160),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            att.fileName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            FormatHelper.formatFileSize(
                                                att.sizeInBytes),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppColors.darkTextMuted
                                                  : AppColors.lightTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => setState(
                                          () => _attachments.remove(att)),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                  // 8. Body Text Area
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: TextField(
                      controller: _bodyController,
                      focusNode: _bodyFocusNode,
                      maxLines: null,
                      minLines: 16,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Tulis isi pesan email Anda di sini...',
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFormatBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      onPressed: onTap,
    );
  }

  Widget _buildRecipientChip({
    required String email,
    required VoidCallback onDeleted,
    required bool isDark,
  }) {
    final name = FormatHelper.extractNameFromEmail(email);
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 6, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryDark.withValues(alpha: 0.35)
            : AppColors.primaryLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            email: email,
            name: name,
            radius: 10,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              email,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
