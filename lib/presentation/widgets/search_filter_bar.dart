import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/mail_provider.dart';

class SearchFilterBar extends StatefulWidget {
  final ValueChanged<String> onSearchChanged;
  final MailFilter activeFilter;
  final ValueChanged<MailFilter> onFilterChanged;
  final VoidCallback onOpenDrawer;

  const SearchFilterBar({
    super.key,
    required this.onSearchChanged,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.onOpenDrawer,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Search Input Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                onPressed: widget.onOpenDrawer,
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: widget.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari di dalam email...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                      fontSize: 14.5,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    widget.onSearchChanged('');
                    setState(() {});
                  },
                ),
            ],
          ),
        ),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua',
                filter: MailFilter.all,
                icon: Icons.mail_outline_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Belum Dibaca',
                filter: MailFilter.unread,
                icon: Icons.mark_email_unread_outlined,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Berbintang',
                filter: MailFilter.starred,
                icon: Icons.star_outline_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Ada Lampiran',
                filter: MailFilter.hasAttachments,
                icon: Icons.attach_file_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required MailFilter filter,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = widget.activeFilter == filter;

    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      ),
      selected: isSelected,
      onSelected: (_) => widget.onFilterChanged(filter),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurfaceElevated,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
