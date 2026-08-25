import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/user_tag_resolver.dart';
import '../../data/models/custom_group.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/mailcow_api_service.dart';
import 'user_avatar.dart';

typedef OnForwardConfirmed = void Function(List<Map<String, dynamic>> selectedRecipients);

class ForwardMessageDialog extends StatefulWidget {
  final String userEmail;
  final OnForwardConfirmed onForwardConfirmed;

  const ForwardMessageDialog({
    super.key,
    required this.userEmail,
    required this.onForwardConfirmed,
  });

  static void show(
    BuildContext context, {
    required String userEmail,
    required OnForwardConfirmed onForwardConfirmed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ForwardMessageDialog(
        userEmail: userEmail,
        onForwardConfirmed: onForwardConfirmed,
      ),
    );
  }

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedRecipients = [];
  final ChatService _chatService = ChatService();
  
  List<Map<String, dynamic>> _allMailboxes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDirectoryMailboxes();
  }

  Future<void> _loadDirectoryMailboxes() async {
    try {
      final apiService = context.read<MailcowApiService>();
      final list = await apiService.getAllMailboxes();
      if (mounted) {
        setState(() {
          _allMailboxes = list.where((m) {
            final email = (m['username'] ?? m['email'] ?? '').toString().toLowerCase();
            return email.isNotEmpty && email != widget.userEmail.toLowerCase();
          }).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(Map<String, dynamic> recipientKey) {
    final String targetId = recipientKey['roomId'] ?? '';
    final existingIndex = _selectedRecipients.indexWhere((r) => r['roomId'] == targetId);

    if (existingIndex >= 0) {
      setState(() {
        _selectedRecipients.removeAt(existingIndex);
      });
    } else {
      if (_selectedRecipients.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batas maksimal 5 penerima tercapai.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      setState(() {
        _selectedRecipients.add(recipientKey);
      });
    }
  }

  bool _isSelected(String roomId) {
    return _selectedRecipients.any((r) => r['roomId'] == roomId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanUserEmail = widget.userEmail.toLowerCase().trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.forward_rounded,
                    color: Color(0xFFE11D48),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teruskan Pesan (Maksimal 5)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pilih hingga 5 orang atau grup obrolan sekaligus',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Selected Counter Chip & Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedRecipients.isEmpty
                            ? Colors.grey.shade300.withValues(alpha: 0.5)
                            : const Color(0xFFE11D48).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRecipients.isEmpty
                              ? Colors.grey.shade400
                              : const Color(0xFFE11D48),
                        ),
                      ),
                      child: Text(
                        'Terpilih: ${_selectedRecipients.length} / 5',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedRecipients.isEmpty
                              ? Colors.grey[700]
                              : const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_selectedRecipients.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _selectedRecipients.clear()),
                        child: const Text(
                          'Bersihkan Pilihan',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama, email, atau nama grup...',
                      hintStyle: TextStyle(fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Stream Target List: Groups + DMs + Mailboxes
          Expanded(
            child: StreamBuilder<List<CustomGroup>>(
              stream: _chatService.getUserGroupsStream(cleanUserEmail),
              builder: (context, groupsSnap) {
                return StreamBuilder<List<DirectConversationItem>>(
                  stream: _chatService.getDirectConversationsStream(cleanUserEmail),
                  builder: (context, dmsSnap) {
                    final groups = groupsSnap.data ?? [];
                    final dms = dmsSnap.data ?? [];

                    // Filter Groups
                    final filteredGroups = groups.where((g) {
                      return _searchQuery.isEmpty || g.name.toLowerCase().contains(_searchQuery);
                    }).toList();

                    // Filter DMs
                    final filteredDms = dms.where((d) {
                      final name = d.peerName.toLowerCase();
                      final email = d.peerEmail.toLowerCase();
                      return _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);
                    }).toList();

                    // Filter Mailboxes Directory
                    final filteredMailboxes = _allMailboxes.where((m) {
                      final name = (m['name'] ?? '').toString().toLowerCase();
                      final email = (m['username'] ?? m['email'] ?? '').toString().toLowerCase();
                      // Exclude if already in recent DMs
                      final inDms = filteredDms.any((d) => d.peerEmail.toLowerCase() == email);
                      return !inDms && (_searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery));
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: [
                        // Section 1: Grup Obrolan
                        if (filteredGroups.isNotEmpty) ...[
                          _buildSectionHeader('Grup Obrolan Saya', Icons.groups_rounded, isDark),
                          ...filteredGroups.map((g) {
                            final selected = _isSelected(g.id);
                            final recipientObj = {
                              'isGroup': true,
                              'roomId': g.id,
                              'name': g.name,
                            };

                            return _buildRecipientTile(
                              title: g.name,
                              subtitle: '${g.members.length} Anggota',
                              leadingIcon: Icons.groups_rounded,
                              leadingColor: const Color(0xFFE11D48),
                              isSelected: selected,
                              isDark: isDark,
                              onTap: () => _toggleSelection(recipientObj),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],

                        // Section 2: Percakapan Japri Terakhir
                        if (filteredDms.isNotEmpty) ...[
                          _buildSectionHeader('Kontak Obrolan Terakhir', Icons.chat_bubble_outline_rounded, isDark),
                          ...filteredDms.map((d) {
                            final peerEmail = d.peerEmail;
                            final peerName = d.peerName.isNotEmpty ? d.peerName : peerEmail.split('@').first;
                            final peerTag = d.peerTag;
                            final roomId = ChatService.getPrivateRoomId(cleanUserEmail, peerEmail);
                            final selected = _isSelected(roomId);

                            final recipientObj = {
                              'isGroup': false,
                              'roomId': roomId,
                              'peerEmail': peerEmail,
                              'peerName': peerName,
                              'peerTag': peerTag,
                              'name': peerName,
                            };

                            return _buildRecipientTile(
                              title: peerName,
                              subtitle: '$peerEmail • TAG: $peerTag',
                              avatarEmail: peerEmail,
                              avatarName: peerName,
                              isSelected: selected,
                              isDark: isDark,
                              onTap: () => _toggleSelection(recipientObj),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],

                        // Section 3: Direktori Kontak Sekolah
                        if (filteredMailboxes.isNotEmpty) ...[
                          _buildSectionHeader('Direktori Kontak Sekolah', Icons.contacts_rounded, isDark),
                          ...filteredMailboxes.map((m) {
                            final email = (m['username'] ?? m['email'] ?? '').toString();
                            final name = (m['name'] ?? email.split('@').first).toString();
                            final tag = UserTagResolver.resolve(email: email, displayName: name, mailboxData: m);
                            final roomId = ChatService.getPrivateRoomId(cleanUserEmail, email);
                            final selected = _isSelected(roomId);

                            final recipientObj = {
                              'isGroup': false,
                              'roomId': roomId,
                              'peerEmail': email,
                              'peerName': name,
                              'peerTag': tag,
                              'name': name,
                            };

                            return _buildRecipientTile(
                              title: name,
                              subtitle: '$email • TAG: $tag',
                              avatarEmail: email,
                              avatarName: name,
                              isSelected: selected,
                              isDark: isDark,
                              onTap: () => _toggleSelection(recipientObj),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Action Button
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _selectedRecipients.isEmpty
                      ? 'Pilih Minimal 1 Penerima'
                      : 'Teruskan Pesan (${_selectedRecipients.length} Target)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _selectedRecipients.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onForwardConfirmed(List.from(_selectedRecipients));
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFFE11D48)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientTile({
    required String title,
    required String subtitle,
    IconData? leadingIcon,
    Color? leadingColor,
    String? avatarEmail,
    String? avatarName,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFE11D48).withValues(alpha: 0.12)
            : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFE11D48) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: avatarEmail != null
            ? UserAvatar(email: avatarEmail, name: avatarName ?? '', radius: 18)
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (leadingColor ?? Colors.blue).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon ?? Icons.chat_rounded, color: leadingColor ?? Colors.blue, size: 18),
              ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isSelected ? const Color(0xFFE11D48) : Colors.grey,
          size: 22,
        ),
      ),
    );
  }
}
