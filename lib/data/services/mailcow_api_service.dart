import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/config/mailcow_config.dart';
import '../models/mailcow_status.dart';

class MailcowApiService {
  late final Dio _dio;

  MailcowApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: kIsWeb ? '' : MailcowConfig.apiUrl,
        headers: {
          'X-API-Key': MailcowConfig.apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  // Fetch domain information and statistics
  Future<MailcowDomainInfo?> getDomainInfo({String? domain}) async {
    final targetDomain = domain ?? MailcowConfig.domain;
    try {
      final response = await _dio.get('/api/v1/get/domain/$targetDomain');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return MailcowDomainInfo.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Fetch all mailboxes in the domain
  Future<List<Map<String, dynamic>>> getAllMailboxes() async {
    try {
      final response = await _dio.get('/api/v1/get/mailbox/all');
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Internal storage for offline/fallback mock aliases
  final List<Map<String, dynamic>> _mockAliases = [];

  // Fetch specific mailbox details (quota, active status, etc)
  Future<Map<String, dynamic>?> getMailboxDetails(String email) async {
    try {
      final response = await _dio.get('/api/v1/get/mailbox/$email');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get aliases pointing to user's email
  Future<List<Map<String, dynamic>>> getUserAliases(String userEmail) async {
    final cleanEmail = userEmail.toLowerCase().trim();
    try {
      final response = await _dio.get('/api/v1/get/alias/all');
      final results = <Map<String, dynamic>>[];

      if (response.statusCode == 200) {
        if (response.data is List) {
          for (final item in response.data) {
            if (item is Map<String, dynamic>) {
              final goto = (item['goto'] ?? '').toString().toLowerCase();
              if (goto == cleanEmail || goto.split(',').contains(cleanEmail)) {
                results.add(Map<String, dynamic>.from(item));
              }
            }
          }
        } else if (response.data is Map<String, dynamic>) {
          (response.data as Map<String, dynamic>).forEach((key, value) {
            if (value is Map<String, dynamic>) {
              final goto = (value['goto'] ?? '').toString().toLowerCase();
              if (goto == cleanEmail || goto.split(',').contains(cleanEmail)) {
                final aliasMap = Map<String, dynamic>.from(value);
                aliasMap['id'] ??= key;
                results.add(aliasMap);
              }
            }
          });
        }
      }

      // Include mock aliases if any match
      for (final mock in _mockAliases) {
        final goto = (mock['goto'] ?? '').toString().toLowerCase();
        if (goto == cleanEmail && !results.any((r) => r['address'] == mock['address'])) {
          results.add(mock);
        }
      }

      return results;
    } catch (e) {
      // Fallback to mock list when offline/error
      return _mockAliases
          .where((m) => (m['goto'] ?? '').toString().toLowerCase() == cleanEmail)
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
  }

  // Create new alias via Mailcow API
  Future<Map<String, dynamic>> addAlias({
    required String address,
    required String gotoEmail,
  }) async {
    final cleanAddress = address.toLowerCase().trim();
    final cleanGoto = gotoEmail.toLowerCase().trim();

    try {
      final response = await _dio.post(
        '/api/v1/add/alias',
        data: {
          'address': cleanAddress,
          'goto': cleanGoto,
          'active': '1',
        },
      );

      if (response.statusCode == 200) {
        if (response.data is List && response.data.isNotEmpty) {
          final resItem = response.data.first;
          if (resItem is Map && resItem['type'] == 'success') {
            return {'success': true, 'message': 'Alias berhasil dibuat'};
          } else if (resItem is Map && resItem['type'] == 'danger') {
            final rawMsg = resItem['msg']?.toString() ?? '';
            String friendlyMsg = 'Gagal membuat alias.';
            if (rawMsg.contains('alias_already_exists') ||
                rawMsg.contains('object_exists') ||
                rawMsg.contains('already_exists')) {
              friendlyMsg = 'Nama alias "$cleanAddress" sudah digunakan oleh akun lain. Silakan pilih nama alias berbeda.';
            } else if (rawMsg.isNotEmpty) {
              friendlyMsg = 'Gagal membuat alias: $rawMsg';
            }
            return {'success': false, 'message': friendlyMsg};
          }
        }
        return {'success': true, 'message': 'Alias berhasil dibuat'};
      }
      return {'success': false, 'message': 'Gagal membuat alias (HTTP ${response.statusCode})'};
    } catch (e) {
      // Check duplicate in mock storage
      final exists = _mockAliases.any(
        (m) => (m['address'] ?? '').toString().toLowerCase() == cleanAddress &&
            (m['goto'] ?? '').toString().toLowerCase() != cleanGoto,
      );
      if (exists) {
        return {
          'success': false,
          'message': 'Nama alias "$cleanAddress" sudah digunakan oleh pengguna lain.',
        };
      }

      // Fallback mock creation for local testing/offline
      final mockId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
      final newAlias = {
        'id': mockId,
        'address': cleanAddress,
        'goto': cleanGoto,
        'active': 1,
        'created': DateTime.now().toIso8601String(),
      };
      _mockAliases.removeWhere((m) => m['goto'] == cleanGoto);
      _mockAliases.add(newAlias);

      return {
        'success': true,
        'message': 'Alias berhasil dibuat (Offline/Mock Mode)',
        'data': newAlias,
      };

    }
  }

  // Delete alias via Mailcow API
  Future<Map<String, dynamic>> deleteAlias(String aliasId, {String? address}) async {
    try {
      final response = await _dio.post(
        '/api/v1/delete/alias',
        data: [aliasId],
      );

      if (response.statusCode == 200) {
        _mockAliases.removeWhere((m) => m['id']?.toString() == aliasId || m['address'] == address);
        return {'success': true, 'message': 'Alias berhasil dihapus'};
      }
      return {'success': false, 'message': 'Gagal menghapus alias (${response.statusCode})'};
    } catch (e) {
      _mockAliases.removeWhere((m) => m['id']?.toString() == aliasId || m['address'] == address);
      return {
        'success': true,
        'message': 'Alias berhasil dihapus (Offline/Mock Mode)',
      };
    }
  }


  // Search school directory / GAL for auto-complete
  Future<List<Map<String, String>>> searchDirectory(String query) async {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final mailboxes = await getAllMailboxes();
      final results = <Map<String, String>>[];

      for (final m in mailboxes) {
        final username = (m['username'] ?? '').toString();
        final name = (m['name'] ?? '').toString();
        if (username.toLowerCase().contains(cleanQuery) ||
            name.toLowerCase().contains(cleanQuery)) {
          results.add({
            'name': name.isNotEmpty ? name : username.split('@').first,
            'email': username,
          });
        }
      }

      return results;
    } catch (_) {
      // Fallback default school contacts
      return _getDefaultSchoolContacts()
          .where((c) =>
              c['name']!.toLowerCase().contains(cleanQuery) ||
              c['email']!.toLowerCase().contains(cleanQuery))
          .toList();
    }
  }

  // Check health and latency of IMAP, SMTP, and REST API
  Future<MailcowServerHealth> checkServerHealth() async {
    final stopwatch = Stopwatch()..start();
    bool apiOk = false;
    bool imapOk = false;
    bool smtpOk = false;
    String? errorMsg;

    // Test API
    try {
      final res = await _dio.get('/api/v1/get/domain/${MailcowConfig.domain}');
      apiOk = (res.statusCode == 200);
    } catch (e) {
      apiOk = false;
      errorMsg = 'API error: $e';
    }

    if (!kIsWeb) {
      // Test IMAP Socket (Port 993)
      try {
        final socket = await Socket.connect(
          MailcowConfig.mailHost,
          MailcowConfig.imapPort,
          timeout: const Duration(seconds: 5),
        );
        imapOk = true;
        socket.destroy();
      } catch (e) {
        imapOk = false;
      }

      // Test SMTP Socket (Port 465)
      try {
        final socket = await Socket.connect(
          MailcowConfig.mailHost,
          MailcowConfig.smtpPort,
          timeout: const Duration(seconds: 5),
        );
        smtpOk = true;
        socket.destroy();
      } catch (e) {
        smtpOk = false;
      }
    } else {
      // On Web, HTTP API is the primary transport
      imapOk = apiOk;
      smtpOk = apiOk;
    }

    stopwatch.stop();

    return MailcowServerHealth(
      imapOnline: imapOk,
      smtpOnline: smtpOk,
      apiOnline: apiOk,
      latencyMs: stopwatch.elapsedMilliseconds,
      lastChecked: DateTime.now(),
      errorMessage: errorMsg,
    );
  }

  List<Map<String, String>> _getDefaultSchoolContacts() {
    return [
      {
        'name': 'Administrator Sekolah',
        'email': 'admin@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Kepala Sekolah SMK BN 666',
        'email': 'kepsek@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Kurikulum & Pengajaran',
        'email': 'kurikulum@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Kesiswaan & Tata Tertib',
        'email': 'kesiswaan@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Hubungan Industri & BKK',
        'email': 'hubin@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Keuangan & Tata Usaha',
        'email': 'keuangan@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Jurusan Animasi (ANM)',
        'email': 'animasi@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Jurusan Rekayasa Perangkat Lunak (RPL)',
        'email': 'rpl@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Jurusan Desain Komunikasi Visual (DKV)',
        'email': 'dkv@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Jurusan Pemasaran & Bisnis Digital (BDP)',
        'email': 'bdp@smk.baktinusantara666.sch.id'
      },
      {
        'name': 'Jurusan Akuntansi (AKL)',
        'email': 'akuntansi@smk.baktinusantara666.sch.id'
      },
    ];
  }
}
