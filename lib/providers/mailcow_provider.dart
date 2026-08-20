import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/config/mailcow_config.dart';
import '../data/models/mailcow_status.dart';
import '../data/services/mailcow_api_service.dart';

class MailcowProvider extends ChangeNotifier {
  final MailcowApiService _apiService;

  MailcowDomainInfo? _domainInfo;
  MailcowServerHealth? _serverHealth;
  List<Map<String, dynamic>> _userAliases = [];
  bool _isLoadingDomain = false;
  bool _isLoadingHealth = false;
  bool _isLoadingAliases = false;
  String? _error;
  String? _aliasError;

  MailcowProvider(this._apiService) {
    refreshAll();
  }

  MailcowDomainInfo? get domainInfo => _domainInfo;
  MailcowServerHealth? get serverHealth => _serverHealth;
  List<Map<String, dynamic>> get userAliases => List.unmodifiable(_userAliases);
  bool get isLoadingDomain => _isLoadingDomain;
  bool get isLoadingHealth => _isLoadingHealth;
  bool get isLoadingAliases => _isLoadingAliases;
  String? get error => _error;
  String? get aliasError => _aliasError;
  bool get hasMaxAliases => _userAliases.isNotEmpty;


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

  Future<void> fetchUserAliases(String userEmail) async {
    if (userEmail.isEmpty) return;
    _isLoadingAliases = true;
    _aliasError = null;
    notifyListeners();

    try {
      final aliases = await _apiService.getUserAliases(userEmail);
      _userAliases = aliases;
    } catch (e) {
      _aliasError = 'Gagal memuat daftar alias';
    } finally {
      _isLoadingAliases = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createAlias({
    required String aliasAddress,
    required String userEmail,
  }) async {
    if (_userAliases.isNotEmpty) {
      return {
        'success': false,
        'message': 'Batas maksimal 1 alias sudah tercapai. Hapus alias saat ini terlebih dahulu.'
      };
    }

    _isLoadingAliases = true;
    _aliasError = null;
    notifyListeners();

    try {
      final result = await _apiService.addAlias(
        address: aliasAddress,
        gotoEmail: userEmail,
      );

      if (result['success'] == true) {
        await fetchUserAliases(userEmail);
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal membuat alias: $e',
      };
    } finally {
      _isLoadingAliases = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deleteUserAlias({
    required String aliasId,
    required String userEmail,
    String? address,
  }) async {
    _isLoadingAliases = true;
    _aliasError = null;
    notifyListeners();

    try {
      final result = await _apiService.deleteAlias(aliasId, address: address);
      if (result['success'] == true) {
        await fetchUserAliases(userEmail);
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal menghapus alias: $e',
      };
    } finally {
      _isLoadingAliases = false;
      notifyListeners();
    }
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
