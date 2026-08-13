import 'package:flutter_test/flutter_test.dart';
import 'package:baknusmail/core/config/mailcow_config.dart';
import 'package:baknusmail/core/utils/format_helper.dart';
import 'package:baknusmail/data/models/baknus_service_models.dart';
import 'package:baknusmail/data/models/folder_info.dart';

void main() {
  test('MailcowConfig constants smoke test', () {
    expect(MailcowConfig.appName, 'BaknusMail');
    expect(MailcowConfig.domain, 'smk.baktinusantara666.sch.id');
    expect(MailcowConfig.smtpPort, 465);
    expect(MailcowConfig.imapPort, 993);
    expect(MailcowConfig.apiKey, '925B68-0FF6BB-36B760-F6C051-AAF343');
    expect(
      MailcowConfig.getAvatarUrl('frian_p@smk.baktinusantara666.sch.id'),
      'https://baknusmail.smkbn666.sch.id/api/public/avatar/frian_p@smk.baktinusantara666.sch.id',
    );
  });

  test('FormatHelper unit tests', () {
    expect(FormatHelper.formatFileSize(1024), '1.0 KB');
    expect(FormatHelper.formatFileSize(1048576), '1.0 MB');
    expect(FormatHelper.getInitials('Ahmad Fauzi'), 'AF');
    expect(FormatHelper.getInitials('Budi'), 'B');
  });

  test('FolderInfo default list & Gmail priority test', () {
    final folders = FolderInfo.getDefaultFolders();
    expect(folders.isNotEmpty, true);
    expect(folders.first.type, FolderType.inbox);
    expect(folders.first.name, 'Kotak Masuk');
    expect(folders.any((f) => f.type == FolderType.starred), true);
    expect(folders.any((f) => f.type == FolderType.sent), true);
  });

  test('BaknusTalimData exact API integration parsing test', () {
    final apiJson = {
      "email": "frian_p@smk.baktinusantara666.sch.id",
      "name": "Frian Prianas",
      "role": "guru",
      "last_activity": {
        "tipe": "Bookmark",
        "waktu": "2026-08-12T22:09:55.020Z",
        "detail": {
          "surah_number": 74,
          "surah_nama": "Al-Muddaththir",
          "ayat_number": 51,
          "catatan": "13 08 2026"
        }
      }
    };

    final talim = BaknusTalimData.fromJson(apiJson);
    expect(talim.email, 'frian_p@smk.baktinusantara666.sch.id');
    expect(talim.name, 'Frian Prianas');
    expect(talim.role, 'guru');
    expect(talim.lastActivity, isNotNull);
    expect(talim.lastActivity!.tipe, 'Bookmark');
    expect(talim.lastActivity!.surahNama, 'Al-Muddaththir');
    expect(talim.lastActivity!.surahNumber, 74);
    expect(talim.lastActivity!.ayatNumber, 51);
    expect(talim.lastActivity!.catatan, '13 08 2026');
    expect(talim.lastActivity!.formattedWaktu.isNotEmpty, true);
  });
}
