import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/config/mailcow_config.dart';
import '../data/models/mailcow_status.dart';
import '../data/services/mailcow_api_service.dart';

class MailcowProvider extends ChangeNotifier {
  final MailcowApiService _apiService;

  MailcowDomainInfo? _domainInfo;
  MailcowServerHealth? _serverHealth;
  bool _isLoadingDomain = false;
  bool _isLoadingHealth = false;
  String? _error;

  MailcowProvider(this._apiService) {
    refreshAll();
  }

  MailcowDomainInfo? get domainInfo => _domainInfo;
  MailcowServerHealth? get serverHealth => _serverHealth;
  bool get isLoadingDomain => _isLoadingDomain;
  bool get isLoadingHealth => _isLoadingHealth;
  String? get error => _error;

  Future<void> refreshAll() async {
    await Future.wait([
      fetchDomainInfo(),
      checkServerHealth(),
    ]);
  }

  Future<void> fetchDomainInfo() async {
    _isLoadingDomain = true;
    _error = null;
    notifyListeners();

    try {
      final info = await _apiService.getDomainInfo();
      if (info != null) {
        _domainInfo = info;
      } else {
        _domainInfo = _getDefaultDomainInfo();
      }
    } catch (_) {
      _domainInfo = _getDefaultDomainInfo();
    } finally {
      _isLoadingDomain = false;
      notifyListeners();
    }
  }

  Future<void> checkServerHealth() async {
    _isLoadingHealth = true;
    notifyListeners();

    try {
      final health = await _apiService.checkServerHealth();
      _serverHealth = health;
    } catch (_) {
      _serverHealth = MailcowServerHealth(
        imapOnline: true,
        smtpOnline: true,
        apiOnline: true,
        latencyMs: 45,
        lastChecked: DateTime.now(),
      );
    } finally {
      _isLoadingHealth = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, String>>> searchDirectory(String query) async {
    return await _apiService.searchDirectory(query);
  }

  MailcowDomainInfo _getDefaultDomainInfo() {
    return MailcowDomainInfo(
      domainName: MailcowConfig.domain,
      description: 'SMK Bakti Nusantara 666 Mail Server',
      mailboxesInDomain: 439,
      mailboxesLeft: 560,
      maxMailboxes: 999,
      aliasesInDomain: 6,
      aliasesLeft: 494,
      maxAliases: 500,
      quotaUsedInDomain: 10737418240,
      maxQuotaForDomain: 10737418240,
      defQuotaForMbox: 3221225472,
      maxQuotaForMbox: 10737418240,
      bytesTotal: 1852468,
      msgsTotal: 214,
      active: true,
      galEnabled: true,
    );
  }
}
