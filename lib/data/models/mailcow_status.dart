class MailcowDomainInfo {
  final String domainName;
  final String description;
  final int mailboxesInDomain;
  final int mailboxesLeft;
  final int maxMailboxes;
  final int aliasesInDomain;
  final int aliasesLeft;
  final int maxAliases;
  final int quotaUsedInDomain;
  final int maxQuotaForDomain;
  final int defQuotaForMbox;
  final int maxQuotaForMbox;
  final int bytesTotal;
  final int msgsTotal;
  final bool active;
  final bool galEnabled;

  MailcowDomainInfo({
    required this.domainName,
    required this.description,
    required this.mailboxesInDomain,
    required this.mailboxesLeft,
    required this.maxMailboxes,
    required this.aliasesInDomain,
    required this.aliasesLeft,
    required this.maxAliases,
    required this.quotaUsedInDomain,
    required this.maxQuotaForDomain,
    required this.defQuotaForMbox,
    required this.maxQuotaForMbox,
    required this.bytesTotal,
    required this.msgsTotal,
    required this.active,
    required this.galEnabled,
  });

  factory MailcowDomainInfo.fromJson(Map<String, dynamic> json) {
    return MailcowDomainInfo(
      domainName: json['domain_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mailboxesInDomain: int.tryParse(json['mboxes_in_domain']?.toString() ?? '0') ?? 0,
      mailboxesLeft: int.tryParse(json['mboxes_left']?.toString() ?? '0') ?? 0,
      maxMailboxes: int.tryParse(json['max_num_mboxes_for_domain']?.toString() ?? '0') ?? 0,
      aliasesInDomain: int.tryParse(json['aliases_in_domain']?.toString() ?? '0') ?? 0,
      aliasesLeft: int.tryParse(json['aliases_left']?.toString() ?? '0') ?? 0,
      maxAliases: int.tryParse(json['max_num_aliases_for_domain']?.toString() ?? '0') ?? 0,
      quotaUsedInDomain: int.tryParse(json['quota_used_in_domain']?.toString() ?? '0') ?? 0,
      maxQuotaForDomain: int.tryParse(json['max_quota_for_domain']?.toString() ?? '0') ?? 0,
      defQuotaForMbox: int.tryParse(json['def_quota_for_mbox']?.toString() ?? '0') ?? 0,
      maxQuotaForMbox: int.tryParse(json['max_quota_for_mbox']?.toString() ?? '0') ?? 0,
      bytesTotal: int.tryParse(json['bytes_total']?.toString() ?? '0') ?? 0,
      msgsTotal: int.tryParse(json['msgs_total']?.toString() ?? '0') ?? 0,
      active: (json['active'] == 1 || json['active'] == '1'),
      galEnabled: (json['gal'] == 1 || json['gal'] == '1'),
    );
  }
}

class MailcowServerHealth {
  final bool imapOnline;
  final bool smtpOnline;
  final bool apiOnline;
  final int latencyMs;
  final DateTime lastChecked;
  final String? errorMessage;

  MailcowServerHealth({
    required this.imapOnline,
    required this.smtpOnline,
    required this.apiOnline,
    required this.latencyMs,
    required this.lastChecked,
    this.errorMessage,
  });

  bool get isAllHealthy => imapOnline && smtpOnline && apiOnline;
}
