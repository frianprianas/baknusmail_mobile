import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mail_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/email_tile.dart';
import '../widgets/folder_drawer.dart';
import '../widgets/quota_progress_card.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchTabController = TextEditingController();
  final TextEditingController _signatureController = TextEditingController();
  bool _isSignatureLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchTabController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<MailProvider>().loadFoldersAndEmails();
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mail = context.watch<MailProvider>();
    final auth = context.watch<AuthProvider>();

    // Load signature once
    if (!_isSignatureLoaded && auth.currentUser != null) {
      final storage = context.read<StorageService>();
      _signatureController.text =
          storage.getSignature(auth.currentUser?.email ?? '');
      _isSignatureLoaded = true;
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const FolderDrawer(),
      appBar: _buildAppBar(context, mail, auth, isDark),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildInboxView(context, mail, isDark),
          _buildAlertsView(context, mail, isDark),
          _buildSearchView(context, mail, isDark),
          _buildProfileView(context, auth, isDark),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, '/compose');
              },
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text(
                'Tulis Pesan',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            )
          : null,
      bottomNavigationBar: _buildBottomNavigationBar(context, mail, isDark),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MailProvider mail,
    AuthProvider auth,
    bool isDark,
  ) {
    String title = 'Kotak Masuk';
    Widget? leading = IconButton(
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
    );
    List<Widget> actions = [];

    if (_currentIndex == 0) {
      title = mail.currentFolder.name;
      actions = [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Segarkan email',
          onPressed: () => mail.loadEmailsForCurrentFolder(),
        ),
        IconButton(
          icon: const Icon(Icons.edit_note_rounded),
          tooltip: 'Tulis Email',
          onPressed: () => Navigator.pushNamed(context, '/compose'),
        ),
      ];
    } else if (_currentIndex == 1) {
      title = 'Alerts & Notifikasi';
      leading = null;
      actions = [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Segarkan',
          onPressed: () => mail.loadFoldersAndEmails(),
        ),
      ];
    } else if (_currentIndex == 2) {
      title = 'Pencarian Email';
      leading = null;
      actions = [];
    } else if (_currentIndex == 3) {
      title = 'Profil & Akun';
      leading = null;
      actions = [
        IconButton(
          icon: const Icon(Icons.dns_outlined),
          tooltip: 'Status Server',
          onPressed: () => Navigator.pushNamed(context, '/server_status'),
        ),
      ];
    }

    return AppBar(
      leading: leading,
      title: Row(
        children: [
          Text(title),
          if (_currentIndex == 0 && mail.currentFolder.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${mail.currentFolder.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }

  // ==================== TAB 0: INBOX VIEW ====================
  Widget _buildInboxView(
    BuildContext context,
    MailProvider mail,
    bool isDark,
  ) {
    final emails = mail.filteredEmails;

    return Column(
      children: [
        // Search & Filter Header
        SearchFilterBar(
          onSearchChanged: mail.setSearchQuery,
          activeFilter: mail.activeFilter,
          onFilterChanged: mail.setFilter,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        ),

        // Email List / States
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => mail.loadFoldersAndEmails(),
            child: mail.isLoading
                ? const Center(
                    child: SpinKitFadingCircle(
                      color: AppColors.primary,
                      size: 38,
                    ),
                  )
                : emails.isEmpty
                    ? _buildEmptyState(context, mail, isDark)
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: emails.length,
                        itemBuilder: (context, index) {
                          final email = emails[index];
                          return EmailTile(
                            email: email,
                            onTap: () {
                              mail.markAsRead(email, isRead: true);
                              Navigator.pushNamed(
                                context,
                                '/email_detail',
                                arguments: email,
                              );
                            },
                            onToggleStar: () => mail.toggleStar(email),
                            onDelete: () => mail.deleteEmail(email),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  // ==================== TAB 1: ALERTS VIEW ====================
  Widget _buildAlertsView(
    BuildContext context,
    MailProvider mail,
    bool isDark,
  ) {
    final unreadEmails =
        mail.folders.expand((f) => mail.filteredEmails).where((e) => !e.isRead).toSet().toList();

    return RefreshIndicator(
      onRefresh: () => mail.loadFoldersAndEmails(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Server Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEFF6FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Server Mailcow Terhubung',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Push Notification FCM Aktif (${MailcowConfig.mailHost})',
                        style: TextStyle(
                          fontSize: 11.5,
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

          // Header Unread
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Email Belum Dibaca (${unreadEmails.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (unreadEmails.isNotEmpty)
                TextButton(
                  onPressed: () {
                    for (var email in unreadEmails) {
                      mail.markAsRead(email, isRead: true);
                    }
                  },
                  child: const Text('Tandai Semua Dibaca', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (unreadEmails.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada alert atau email baru',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semua pesan masuk telah Anda baca.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            ...unreadEmails.map((email) {
              return EmailTile(
                email: email,
                onTap: () {
                  mail.markAsRead(email, isRead: true);
                  Navigator.pushNamed(
                    context,
                    '/email_detail',
                    arguments: email,
                  );
                },
                onToggleStar: () => mail.toggleStar(email),
                onDelete: () => mail.deleteEmail(email),
              );
            }),
        ],
      ),
    );
  }

  // ==================== TAB 2: SEARCH VIEW ====================
  Widget _buildSearchView(
    BuildContext context,
    MailProvider mail,
    bool isDark,
  ) {
    final query = _searchTabController.text.trim().toLowerCase();
    final searchResults = query.isEmpty
        ? mail.filteredEmails
        : mail.filteredEmails.where((email) {
            final matchSubject = email.subject.toLowerCase().contains(query);
            final matchSender = email.from.name.toLowerCase().contains(query) ||
                email.from.email.toLowerCase().contains(query);
            final matchSnippet = email.snippet.toLowerCase().contains(query);
            final matchBody = email.bodyText.toLowerCase().contains(query);
            return matchSubject || matchSender || matchSnippet || matchBody;
          }).toList();

    return Column(
      children: [
        // Dedicated Search Input Box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchTabController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Cari subjek, nama pengirim, atau isi pesan...',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: _searchTabController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchTabController.clear();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Quick Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('Semua', mail.activeFilter == MailFilter.all, () {
                mail.setFilter(MailFilter.all);
              }, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Belum Dibaca', mail.activeFilter == MailFilter.unread, () {
                mail.setFilter(MailFilter.unread);
              }, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Berbintang', mail.activeFilter == MailFilter.starred, () {
                mail.setFilter(MailFilter.starred);
              }, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Ada Lampiran', mail.activeFilter == MailFilter.hasAttachments, () {
                mail.setFilter(MailFilter.hasAttachments);
              }, isDark),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Search Results List
        Expanded(
          child: searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        query.isEmpty
                            ? 'Ketik kata kunci untuk mencari email'
                            : 'Tidak ditemukan email untuk "$query"',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final email = searchResults[index];
                    return EmailTile(
                      email: email,
                      onTap: () {
                        mail.markAsRead(email, isRead: true);
                        Navigator.pushNamed(
                          context,
                          '/email_detail',
                          arguments: email,
                        );
                      },
                      onToggleStar: () => mail.toggleStar(email),
                      onDelete: () => mail.deleteEmail(email),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : AppColors.lightSurfaceElevated),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  // ==================== TAB 3: PROFILE VIEW ====================
  Widget _buildProfileView(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  ) {
    final user = auth.currentUser;
    final themeProvider = context.watch<ThemeProvider>();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // User Profile Card
        if (user != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                UserAvatar(
                  name: user.displayName,
                  email: user.email,
                  radius: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.isDemo ? 'Akun Demo' : 'Siswa / Civitas',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quota Card
          QuotaProgressCard(user: user),
          const SizedBox(height: 20),
        ],

        // App Settings Section
        _buildSectionHeader('Tampilan & Tema', isDark),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  label: Text('Sistem', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                  label: Text('Terang', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                  label: Text('Gelap', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                themeProvider.setThemeMode(newSelection.first);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Signature Section
        _buildSectionHeader('Tanda Tangan Email', isDark),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _signatureController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tuliskan tanda tangan otomatis...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final storage = context.read<StorageService>();
                  await storage.setSignature(_signatureController.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tanda tangan email tersimpan!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Simpan Tanda Tangan'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Server Status Shortcut
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.dns_rounded, color: AppColors.primary),
            title: const Text('Status Server Mailcow', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Periksa koneksi SMTP, IMAP & HTTPS', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/server_status'),
          ),
        ),
        const SizedBox(height: 24),

        // Logout Button
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text(
              'Keluar dari Akun',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar dari Akun?'),
                  content: const Text(
                    'Anda harus memasukkan kembali kata sandi untuk masuk ke email.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                }
              }
            },
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  // ==================== CUSTOM BOTTOM NAVIGATION BAR ====================
  Widget _buildBottomNavigationBar(
    BuildContext context,
    MailProvider mail,
    bool isDark,
  ) {
    final unreadCount = mail.unreadCountTotal;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.inbox_outlined,
                activeIcon: Icons.inbox_rounded,
                label: 'Inbox',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'Alerts',
                badgeCount: unreadCount,
                isDark: isDark,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.search_rounded,
                activeIcon: Icons.search_rounded,
                label: 'Search',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = const Color(0xFF2563EB); // Royal Blue as in image
    final inactiveColor = isDark
        ? AppColors.darkTextMuted
        : const Color(0xFF64748B); // Slate

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),

            // Label Text
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),

            // Indicator Dot (matching user's design)
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? activeColor : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState(
      BuildContext context, MailProvider mail, bool isDark) {
    String message = 'Tidak ada pesan di folder ini';
    IconData icon = Icons.inbox_outlined;

    if (mail.searchQuery.isNotEmpty) {
      message = 'Tidak ditemukan email dengan kata kunci "${mail.searchQuery}"';
      icon = Icons.search_off_rounded;
    } else if (mail.activeFilter == MailFilter.unread) {
      message = 'Semua email telah dibaca!';
      icon = Icons.mark_email_read_outlined;
    } else if (mail.activeFilter == MailFilter.starred) {
      message = 'Belum ada email berbintang';
      icon = Icons.star_outline_rounded;
    } else if (mail.activeFilter == MailFilter.hasAttachments) {
      message = 'Tidak ada email dengan lampiran berkas';
      icon = Icons.attach_file_rounded;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.lightSurfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tarik ke bawah untuk memuat ulang',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
