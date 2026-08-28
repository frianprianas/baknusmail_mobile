import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../data/models/email_message.dart';
import '../data/models/folder_info.dart';
import '../data/models/attachment_item.dart';
import '../data/services/imap_service.dart';
import '../data/services/smtp_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/demo_data_service.dart';
import 'auth_provider.dart';

enum MailFilter { all, unread, starred, hasAttachments }

class MailProvider extends ChangeNotifier {
  final StorageService _storageService;
  final ImapService _imapService;
  final SmtpService _smtpService;
  final AuthProvider _authProvider;

  List<FolderInfo> _folders = FolderInfo.getDefaultFolders();
  FolderInfo _currentFolder = FolderInfo.getDefaultFolders().first;
  List<EmailMessage> _emails = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isFetchingMore = false;
  String? _errorMessage;

  String _searchQuery = '';
  MailFilter _activeFilter = MailFilter.all;

  MailProvider(
    this._storageService,
    this._imapService,
    this._smtpService,
    this._authProvider,
  ) {
    if (_authProvider.isAuthenticated) {
      loadFoldersAndEmails();
    }
  }

  List<FolderInfo> get folders => _folders;
  FolderInfo get currentFolder => _currentFolder;
  List<EmailMessage> get emails => _emails;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isFetchingMore => _isFetchingMore;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  MailFilter get activeFilter => _activeFilter;

  // Filtered emails based on search query and category filters
  List<EmailMessage> get filteredEmails {
    return _emails.where((email) {
      // Filter by folder
      if (_currentFolder.type == FolderType.starred) {
        if (!email.isStarred) return false;
      } else if (_currentFolder.type == FolderType.sent) {
        if (email.folder != 'Sent' && email.folder != 'Sent Items') return false;
      } else if (_currentFolder.type == FolderType.trash) {
        if (email.folder != 'Trash') return false;
      } else if (_currentFolder.type == FolderType.drafts) {
        if (email.folder != 'Drafts') return false;
      } else if (_currentFolder.type == FolderType.spam) {
        if (email.folder != 'Junk' && email.folder != 'Spam') return false;
      } else if (_currentFolder.type == FolderType.inbox) {
        if (email.folder != 'INBOX') return false;
      }

      // Filter by chip
      if (_activeFilter == MailFilter.unread && email.isRead) return false;
      if (_activeFilter == MailFilter.starred && !email.isStarred) return false;
      if (_activeFilter == MailFilter.hasAttachments && !email.hasAttachments) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchSubject = email.subject.toLowerCase().contains(query);
        final matchSender = email.from.name.toLowerCase().contains(query) ||
            email.from.email.toLowerCase().contains(query);
        final matchSnippet = email.snippet.toLowerCase().contains(query);
        if (!matchSubject && !matchSender && !matchSnippet) return false;
      }

      return true;
    }).toList();
  }

  int get unreadCountTotal {
    return _emails.where((e) => !e.isRead && e.folder == 'INBOX').length;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(MailFilter filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void selectFolder(FolderInfo folder) {
    _currentFolder = folder;
    notifyListeners();
    loadEmailsForCurrentFolder();
  }

  Future<void> selectInboxAndRefresh() async {
    _currentFolder = FolderInfo.getDefaultFolders().first;
    _searchQuery = '';
    _activeFilter = MailFilter.all;
    await loadFoldersAndEmails();
  }

  void clearMailbox() {
    _emails = [];
    _folders = FolderInfo.getDefaultFolders();
    _currentFolder = FolderInfo.getDefaultFolders().first;
    _searchQuery = '';
    _activeFilter = MailFilter.all;
    _errorMessage = null;
    notifyListeners();
  }

  void _sortEmailsByDate() {
    _emails.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> loadFoldersAndEmails() async {
    _errorMessage = null;

    final currentUserEmail = _authProvider.currentUser?.email;
    final currentUserPassword = _authProvider.currentUser?.password;

    // Load cached data immediately if memory is empty
    if (_emails.isEmpty) {
      final cached = _storageService.getCachedEmails(_currentFolder.path, userEmail: currentUserEmail);
      if (cached.isNotEmpty) {
        _emails = cached;
        _sortEmailsByDate();
        _updateFolderCounts();
      }
    }

    // Show full screen spinner ONLY if we have literally zero emails to display
    if (_emails.isEmpty) {
      _isLoading = true;
    } else {
      _isLoading = false;
    }
    notifyListeners();

    // Prevent duplicate concurrent sync operations
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      if (_authProvider.currentUser?.isDemo == true || kIsWeb) {
        if (_emails.isEmpty) {
          _emails = DemoDataService.getDemoEmails();
          _sortEmailsByDate();
          _updateFolderCounts();
        }
      } else {
        final isConnected = await _imapService.ensureConnected(currentUserEmail, currentUserPassword);

        if (isConnected || _imapService.isConnected) {
          final folders = await _imapService.listFolders();
          if (folders.isNotEmpty) {
            _folders = folders;
          }
          final targetPath = _currentFolder.type == FolderType.starred ? 'INBOX' : _currentFolder.path;
          final fetched = await _imapService.fetchMessages(
            folderPath: targetPath,
            count: 30,
          );
          if (fetched.isNotEmpty || _emails.isEmpty) {
            _emails = fetched;
          }
          _sortEmailsByDate();
          await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: currentUserEmail);
          _updateFolderCounts();
        }
        _sortEmailsByDate();
        _updateFolderCounts();
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat email: $e';
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> loadEmailsForCurrentFolder() async {
    final email = _authProvider.currentUser?.email;
    final password = _authProvider.currentUser?.password;

    // Load folder cache immediately
    final cached = _storageService.getCachedEmails(_currentFolder.path, userEmail: email);
    if (cached.isNotEmpty) {
      _emails = cached;
      _sortEmailsByDate();
      _updateFolderCounts();
      _isLoading = false;
    } else if (_emails.isEmpty) {
      _isLoading = true;
    }
    notifyListeners();

    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      if (_authProvider.currentUser?.isDemo == true || kIsWeb) {
        if (_emails.isEmpty) {
          _emails = DemoDataService.getDemoEmails();
          _sortEmailsByDate();
          _updateFolderCounts();
        }
      } else {
        if (await _imapService.ensureConnected(email, password)) {
          final targetPath = _currentFolder.type == FolderType.starred ? 'INBOX' : _currentFolder.path;
          final fetched = await _imapService.fetchMessages(
            folderPath: targetPath,
            count: 30,
            offset: 0,
          );
          if (fetched.isNotEmpty || _emails.isEmpty) {
            _emails = fetched;
          }
          _sortEmailsByDate();
          await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: email);
        }
      }
      _updateFolderCounts();
    } catch (e) {
      _errorMessage = 'Gagal memuat folder: $e';
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreEmails() async {
    if (_isFetchingMore || _isLoading || _authProvider.currentUser?.isDemo == true) return;
    
    // Check if we already loaded all messages based on folder count
    if (_emails.length >= _currentFolder.totalCount) return;

    _isFetchingMore = true;
    notifyListeners();

    try {
      final email = _authProvider.currentUser?.email;
      final password = _authProvider.currentUser?.password;
      if (await _imapService.ensureConnected(email, password)) {
        final targetPath = _currentFolder.type == FolderType.starred ? 'INBOX' : _currentFolder.path;
        final fetched = await _imapService.fetchMessages(
          folderPath: targetPath,
          count: 30,
          offset: _emails.length,
        );
        if (fetched.isNotEmpty) {
          // Avoid duplicates by merging based on messageId
          for (var newEmail in fetched) {
            if (!_emails.any((e) => e.messageId == newEmail.messageId)) {
              _emails.add(newEmail);
            }
          }
          _sortEmailsByDate();
          await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: email);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch more emails: $e');
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  void addOrUpdateEmail(EmailMessage email) {
    final index = _emails.indexWhere((e) => e.messageId == email.messageId);
    if (index != -1) {
      _emails[index] = email;
    } else {
      _emails.insert(0, email);
    }
    _sortEmailsByDate();
    _updateFolderCounts();
    final currentUserEmail = _authProvider.currentUser?.email;
    _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: currentUserEmail);
    notifyListeners();
  }

  Future<void> toggleStar(EmailMessage email) async {
    final index = _emails.indexWhere((e) => e.messageId == email.messageId);
    if (index != -1) {
      final updated = _emails[index].copyWith(isStarred: !email.isStarred);
      _emails[index] = updated;
      
      // Update cache and folder counts immediately to sync star status
      final currentUserEmail = _authProvider.currentUser?.email;
      await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: currentUserEmail);
      _updateFolderCounts();
      notifyListeners();

      if (!_authProvider.currentUser!.isDemo) {
        final uid = int.tryParse(email.messageId);
        final targetFolder = email.folder.isNotEmpty ? email.folder : 'INBOX';
        if (uid != null) {
          await _imapService.toggleStarredByUid(uid, isStarred: updated.isStarred, folderPath: targetFolder);
        } else if (email.sequenceId != null) {
          await _imapService.toggleStarred(email.sequenceId!, isStarred: updated.isStarred, folderPath: targetFolder);
        }
      }
    }
  }

  Future<void> markAsRead(EmailMessage email, {bool isRead = true}) async {
    final index = _emails.indexWhere((e) => e.messageId == email.messageId);
    if (index != -1) {
      final updated = _emails[index].copyWith(isRead: isRead);
      _emails[index] = updated;
      _updateFolderCounts();
      
      // Update cache immediately
      final currentUserEmail = _authProvider.currentUser?.email;
      await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: currentUserEmail);

      notifyListeners();

      if (!_authProvider.currentUser!.isDemo) {
        final uid = int.tryParse(email.messageId);
        final targetFolder = email.folder.isNotEmpty ? email.folder : 'INBOX';
        if (uid != null) {
          await _imapService.markAsReadByUid(uid, isRead: isRead, folderPath: targetFolder);
        } else if (email.sequenceId != null) {
          await _imapService.markAsRead(email.sequenceId!, isRead: isRead, folderPath: targetFolder);
        }
      }
    }
  }

  Future<void> deleteEmail(EmailMessage email) async {
    final index = _emails.indexWhere((e) => e.messageId == email.messageId);
    if (index != -1) {
      if (email.folder == 'Trash') {
        _emails.removeAt(index);
      } else {
        _emails[index] = _emails[index].copyWith(folder: 'Trash');
      }
      _updateFolderCounts();
      
      // Update cache immediately
      final currentUserEmail = _authProvider.currentUser?.email;
      await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: currentUserEmail);

      notifyListeners();

      if (!_authProvider.currentUser!.isDemo) {
        final uid = int.tryParse(email.messageId);
        if (uid != null) {
          await _imapService.deleteMessageByUid(uid);
        } else if (email.sequenceId != null) {
          await _imapService.deleteMessage(email.sequenceId!);
        }
      }
    }
  }

  // Send Email via SMTP
  Future<bool> sendEmail({
    required List<String> recipients,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String bodyText,
    String? bodyHtml,
    List<AttachmentItem> attachments = const [],
  }) async {
    final user = _authProvider.currentUser;
    if (user == null) return false;

    if (user.isDemo) {
      // Simulate send
      await Future.delayed(const Duration(milliseconds: 900));
      final newSentEmail = EmailMessage(
        messageId: 'sent-${DateTime.now().millisecondsSinceEpoch}@${user.domain}',
        from: EmailAddressItem(name: user.displayName, email: user.email),
        to: recipients.map((r) => EmailAddressItem(name: '', email: r)).toList(),
        cc: cc.map((r) => EmailAddressItem(name: '', email: r)).toList(),
        subject: subject,
        snippet: bodyText.length > 80 ? '${bodyText.substring(0, 80)}...' : bodyText,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        dateTime: DateTime.now(),
        isRead: true,
        hasAttachments: attachments.isNotEmpty,
        attachments: attachments,
        folder: 'Sent',
      );
      _emails.insert(0, newSentEmail);
      _updateFolderCounts();
      notifyListeners();
      return true;
    }

    try {
      final result = await _smtpService.sendEmailWithMime(
        senderEmail: user.email,
        senderPassword: user.password ?? '',
        senderName: user.displayName,
        recipients: recipients,
        cc: cc,
        bcc: bcc,
        subject: subject,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        attachments: attachments,
      );

      if (result.success) {
        // Sync & append directly to IMAP 'Sent' mailbox on Mailcow Dovecot server!
        if (result.mimeMessage != null && _imapService.isConnected) {
          try {
            await _imapService.appendSentMessage(
              result.mimeMessage!,
              folderPath: 'Sent',
            );
          } catch (_) {}
        }

        final newSentEmail = EmailMessage(
          messageId:
              'sent-${DateTime.now().millisecondsSinceEpoch}@${user.domain}',
          from: EmailAddressItem(name: user.displayName, email: user.email),
          to: recipients
              .map((r) => EmailAddressItem(name: '', email: r))
              .toList(),
          cc: cc.map((r) => EmailAddressItem(name: '', email: r)).toList(),
          subject: subject,
          snippet:
              bodyText.length > 80 ? '${bodyText.substring(0, 80)}...' : bodyText,
          bodyText: bodyText,
          bodyHtml: bodyHtml,
          dateTime: DateTime.now(),
          isRead: true,
          hasAttachments: attachments.isNotEmpty,
          attachments: attachments,
          folder: 'Sent',
        );

        // Update local sent list & cache
        final currentUserEmail = user.email;
        final cachedSent = _storageService.getCachedEmails('Sent', userEmail: currentUserEmail);
        cachedSent.insert(0, newSentEmail);
        await _storageService.cacheEmails('Sent', cachedSent, userEmail: currentUserEmail);

        if (_currentFolder.path == 'Sent') {
          _emails.insert(0, newSentEmail);
        }
        _updateFolderCounts();
        notifyListeners();
      }
      return result.success;
    } catch (_) {
      return false;
    }
  }

  void _updateFolderCounts() {
    final updated = _folders.map((f) {
      int count = 0;
      int unread = 0;
      if (f.type == FolderType.inbox) {
        count = _emails.where((e) => e.folder == 'INBOX').length;
        unread = _emails.where((e) => e.folder == 'INBOX' && !e.isRead).length;
      } else if (f.type == FolderType.starred) {
        count = _emails.where((e) => e.isStarred).length;
        unread = count; // Badge should reflect total starred items
      } else if (f.type == FolderType.sent) {
        count = _emails.where((e) => e.folder == 'Sent').length;
      } else if (f.type == FolderType.drafts) {
        count = _emails.where((e) => e.folder == 'Drafts').length;
      } else if (f.type == FolderType.trash) {
        count = _emails.where((e) => e.folder == 'Trash').length;
      } else if (f.type == FolderType.spam) {
        count = _emails.where((e) => e.folder == 'Junk' || e.folder == 'Spam').length;
      }
      return f.copyWith(unreadCount: unread, totalCount: count);
    }).toList();

    updated.sort((a, b) => a.priority.compareTo(b.priority));
    _folders = updated;
  }
}
