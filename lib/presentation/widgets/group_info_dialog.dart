import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_tag_resolver.dart';
import '../../data/models/custom_group.dart';
import '../../data/services/chat_service.dart';
import '../../providers/auth_provider.dart';

class GroupInfoDialog extends StatefulWidget {
  final CustomGroup group;
  final VoidCallback onGroupUpdated;

  const GroupInfoDialog({
    super.key,
    required this.group,
    required this.onGroupUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomGroup group,
    required VoidCallback onGroupUpdated,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => GroupInfoDialog(group: group, onGroupUpdated: onGroupUpdated),
    );
  }

  @override
  State<GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends State<GroupInfoDialog> {
  final ChatService _chatService = ChatService();
  final _addEmailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _addEmailController.dispose();
    super.dispose();
  }

  Future<void> _handleAddMember() async {
    final email = _addEmailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email BaknusID yang valid.')),
      );
      return;
    }

    final name = email.split('@').first;
    final tag = UserTagResolver.resolve(email: email, displayName: name);

    setState(() => _isLoading = true);
    try {
      await _chatService.addMemberToGroup(
        groupId: widget.group.id,
        memberEmail: email,
        memberName: name,
        memberTag: tag,
      );

      if (mounted) {
        _addEmailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 $email berhasil ditambahkan ke grup.')),
        );
        widget.onGroupUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah anggota: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteGroup() async {
    final auth = context.read<AuthProvider>();
    final userEmail = auth.currentUser?.email ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Grup Obrolan?'),
        content: const Text(
          'Grup obrolan ini akan dihapus secara permanen. Kuota pembuatan grup Anda akan kembali berkurang.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Grup'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _chatService.deleteGroup(groupId: widget.group.id, userEmail: userEmail);
        if (mounted) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grup obrolan berhasil dihapus.')),
          );
          widget.onGroupUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus grup: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final currentUserEmail = auth.currentUser?.email ?? '';
    final isCreator = widget.group.isCreator(currentUserEmail);

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
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded, color: Color(0xFFE11D48), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Pembuat: ${widget.group.creatorName} ${isCreator ? "(Anda)" : ""}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (widget.group.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  widget.group.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
              const Divider(height: 24),

              // Members List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Anggota Grup (${widget.group.members.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (isCreator)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ADMIN GRUP',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Member List
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.group.members.length,
                  itemBuilder: (context, index) {
                    final memberEmail = widget.group.members[index];
                    final memberName = widget.group.memberNames[memberEmail] ?? memberEmail.split('@').first;
                    final memberTag = widget.group.memberTags[memberEmail] ?? 'Siswa';
                    final isMemberAdmin = widget.group.isCreator(memberEmail);
                    final tagColor = UserTagResolver.getTagColor(memberTag);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: tagColor.withValues(alpha: 0.15),
                            child: Text(
                              memberName.isNotEmpty ? memberName[0].toUpperCase() : 'U',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tagColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$memberName ${isMemberAdmin ? "👑" : ""}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                Text(memberEmail, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: tagColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              memberTag,
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: tagColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Admin Action: Add Member Input
              if (isCreator) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addEmailController,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Tambah Email Anggota (cth: siswa@...)',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleAddMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Tambah', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Admin Delete Group Button
              if (isCreator)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleDeleteGroup,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('Hapus Grup Obrolan Ini'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
