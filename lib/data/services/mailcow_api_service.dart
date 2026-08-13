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
        baseUrl: MailcowConfig.apiUrl,
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
