import 'package:flutter/material.dart';
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
  bool get isLoading => _isLoading;
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

  void clearMailbox() {
    _emails = [];
    _folders = FolderInfo.getDefaultFolders();
    _currentFolder = FolderInfo.getDefaultFolders().first;
    _searchQuery = '';
    _activeFilter = MailFilter.all;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadFoldersAndEmails() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_authProvider.currentUser?.isDemo == true) {
        // Load demo data
        _emails = DemoDataService.getDemoEmails();
        _updateFolderCounts();
      } else {
        final currentUserEmail = _authProvider.currentUser?.email;
        // Load cached first for this specific user
        final cached = _storageService.getCachedEmails(_currentFolder.path, userEmail: currentUserEmail);
        _emails = cached;
        _updateFolderCounts();

        // Auto-reconnect IMAP if disconnected (e.g. after app restart or session timeout)
        if (!_imapService.isConnected) {
          final email = _authProvider.currentUser?.email;
          final password = _authProvider.currentUser?.password;
          if (email != null && password != null && password.isNotEmpty) {
            await _imapService.connectAndLogin(email, password);
          }
        }

        // Fetch from IMAP
        if (_imapService.isConnected) {
          final folders = await _imapService.listFolders();
          if (folders.isNotEmpty) {
            _folders = folders;
          }
          final fetched = await _imapService.fetchMessages(
            folderPath: _currentFolder.path,
            count: 30,
          );
          _emails = fetched;
          await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: currentUserEmail);
        } else {
          // If not connected and no cache, clear emails
          if (cached.isEmpty) {
            _emails = [];
          }
        }
        _updateFolderCounts();
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat email: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEmailsForCurrentFolder() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_authProvider.currentUser?.isDemo == true) {
        // Demo emails already in memory
      } else {
        // Auto-reconnect IMAP if disconnected
        if (!_imapService.isConnected) {
          final email = _authProvider.currentUser?.email;
          final password = _authProvider.currentUser?.password;
          if (email != null && password != null && password.isNotEmpty) {
            await _imapService.connectAndLogin(email, password);
          }
        }

        if (_imapService.isConnected) {
          final fetched = await _imapService.fetchMessages(
            folderPath: _currentFolder.path,
            count: 30,
          );
          if (fetched.isNotEmpty) {
            _emails = fetched;
            final currentUserEmail = _authProvider.currentUser?.email;
            await _storageService.cacheEmails(_currentFolder.path, _emails, userEmail: currentUserEmail);
          }
        }
      }
      _updateFolderCounts();
    } catch (e) {
      _errorMessage = 'Gagal memuat folder: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleStar(EmailMessage email) async {
    final index = _emails.indexWhere((e) => e.messageId == email.messageId);
    if (index != -1) {
      final updated = _emails[index].copyWith(isStarred: !email.isStarred);
      _emails[index] = updated;
      notifyListeners();

      if (!_authProvider.currentUser!.isDemo && email.sequenceId != null) {
        await _imapService.toggleStarred(
          email.sequenceId!,
          isStarred: updated.isStarred,
        );
      }
    }
  }

  Future<void> markAsRead(EmailMessage email, {bool isRead = true}) async {
    final index = _emails.indexWhere((e) => e.messageId == email.messageId);
    if (index != -1) {
      final updated = _emails[index].copyWith(isRead: isRead);
      _emails[index] = updated;
      _updateFolderCounts();
      notifyListeners();

      if (!_authProvider.currentUser!.isDemo && email.sequenceId != null) {
        await _imapService.markAsRead(email.sequenceId!, isRead: isRead);
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
      notifyListeners();

      if (!_authProvider.currentUser!.isDemo && email.sequenceId != null) {
        await _imapService.deleteMessage(email.sequenceId!);
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
        unread = _emails.where((e) => e.isStarred && !e.isRead).length;
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
