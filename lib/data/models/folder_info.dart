import 'package:flutter/material.dart';

enum FolderType { inbox, starred, sent, drafts, archive, spam, trash, custom }

class FolderInfo {
  final String name;
  final String path;
  final FolderType type;
  final int unreadCount;
  final int totalCount;
  final IconData icon;

  FolderInfo({
    required this.name,
    required this.path,
    required this.type,
    this.unreadCount = 0,
    this.totalCount = 0,
    required this.icon,
  });

  int get priority {
    switch (type) {
      case FolderType.inbox:
        return 0;
      case FolderType.starred:
        return 1;
      case FolderType.sent:
        return 2;
      case FolderType.drafts:
        return 3;
      case FolderType.archive:
        return 4;
      case FolderType.spam:
        return 5;
      case FolderType.trash:
        return 6;
      case FolderType.custom:
        return 7;
    }
  }

  FolderInfo copyWith({
    String? name,
    String? path,
    FolderType? type,
    int? unreadCount,
    int? totalCount,
    IconData? icon,
  }) {
    return FolderInfo(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      unreadCount: unreadCount ?? this.unreadCount,
      totalCount: totalCount ?? this.totalCount,
      icon: icon ?? this.icon,
    );
  }

  static List<FolderInfo> getDefaultFolders() {
    return [
      FolderInfo(
        name: 'Kotak Masuk',
        path: 'INBOX',
        type: FolderType.inbox,
        icon: Icons.inbox_rounded,
      ),
      FolderInfo(
        name: 'Berbintang',
        path: 'STARRED',
        type: FolderType.starred,
        icon: Icons.star_outline_rounded,
      ),
      FolderInfo(
        name: 'Terkirim',
        path: 'Sent',
        type: FolderType.sent,
        icon: Icons.send_outlined,
      ),
      FolderInfo(
        name: 'Draf',
        path: 'Drafts',
        type: FolderType.drafts,
        icon: Icons.drafts_outlined,
      ),
      FolderInfo(
        name: 'Arsip',
        path: 'Archive',
        type: FolderType.archive,
        icon: Icons.archive_outlined,
      ),
      FolderInfo(
        name: 'Spam',
        path: 'Junk',
        type: FolderType.spam,
        icon: Icons.report_gmailerrorred_rounded,
      ),
      FolderInfo(
        name: 'Sampah',
        path: 'Trash',
        type: FolderType.trash,
        icon: Icons.delete_outline_rounded,
      ),
    ];
  }
}
