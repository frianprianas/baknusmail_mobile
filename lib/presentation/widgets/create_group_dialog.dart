import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_tag_resolver.dart';
import '../../data/services/chat_service.dart';
import '../../providers/auth_provider.dart';

class CreateGroupDialog extends StatefulWidget {
  final VoidCallback onGroupCreated;

  const CreateGroupDialog({super.key, required this.onGroupCreated});

  static Future<void> show(BuildContext context, {required VoidCallback onGroupCreated}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateGroupDialog(onGroupCreated: onGroupCreated),
    );
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final ChatService _chatService = ChatService();

  bool _isLoading = false;
  int _createdGroupsCount = 0;
  bool _isCheckingQuota = true;

  @override
  void initState() {
    super.initState();
    _checkQuota();
  }

  Future<void> _checkQuota() async {
    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? '';
    if (email.isNotEmpty) {
      final count = await _chatService.getUserCreatedGroupsCount(email);
      if (mounted) {
        setState(() {
          _createdGroupsCount = count;
          _isCheckingQuota = false;
        });
      }
    } else {
      if (mounted) setState(() => _isCheckingQuota = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email ?? '';
    final name = auth.currentUser?.displayName ?? 'Pengguna';
    final tag = UserTagResolver.resolve(email: email, displayName: name);

    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _chatService.createCustomGroup(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        creatorEmail: email,
        creatorName: name,
        creatorTag: tag,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Grup obrolan baru berhasil dibuat!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onGroupCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isQuotaFull = _createdGroupsCount >= 2;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Quota Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.group_add_rounded,
                          color: Color(0xFFE11D48),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Buat Grup Obrolan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quota Counter Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isQuotaFull
                      ? Colors.amber.withValues(alpha: 0.15)
                      : const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isQuotaFull ? Colors.amber : const Color(0xFF38BDF8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isQuotaFull ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: isQuotaFull ? Colors.amber.shade800 : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCheckingQuota
                            ? 'Memeriksa kuota grup...'
                            : 'Kuota Pembuatan Grup: $_createdGroupsCount / 2 Grup Dibuat',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isQuotaFull
                              ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
                              : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (isQuotaFull) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '⚠️ Anda telah mencapai batas maksimal 2 grup buatan. Hapus salah satu grup buatan Anda jika ingin membuat grup baru.',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: 'Nama Grup',
                          hintText: 'Contoh: Kelompok Belajar XI RPL 1',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama grup tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descController,
                        maxLength: 100,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Deskripsi / Tujuan Grup (Opsional)',
                          hintText: 'Contoh: Wadah diskusi tugas & materi RPL',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  if (!isQuotaFull) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading || _isCheckingQuota ? null : _handleCreateGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isLoading ? 'Membuat...' : 'Buat Grup'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
