import '../models/email_message.dart';
import '../models/attachment_item.dart';

class DemoDataService {
  static List<EmailMessage> getDemoEmails() {
    final now = DateTime.now();

    return [
      EmailMessage(
        sequenceId: 1,
        messageId: 'demo-msg-001@smk.baktinusantara666.sch.id',
        from: EmailAddressItem(
          name: 'Kurikulum SMK Bakti Nusantara 666',
          email: 'kurikulum@smk.baktinusantara666.sch.id',
        ),
        to: [
          EmailAddressItem(
            name: 'Civitas Akademika SMK BN 666',
            email: 'all@smk.baktinusantara666.sch.id',
          )
        ],
        subject: '📢 Jadwal Asesmen Akhir Semester & Pembagian Rapor Genap',
        snippet:
            'Diberitahukan kepada seluruh bapak/ibu guru dan siswa bahwa Asesmen Akhir Semester akan dimulai pekan depan...',
        bodyText: '''Yth. Bapak/Ibu Guru dan Siswa/i SMK Bakti Nusantara 666,

Berikut kami sampaikan jadwal pelaksanaan Asesmen Akhir Semester (AAS) Tahun Ajaran 2025/2026:

1. Pelaksanaan Ujian Teori: 18 - 22 Mei 2026
2. Pelaksanaan Ujian Praktik Kejuruan (UKK): 25 - 29 Mei 2026
3. Pengolahan Nilai & Rapat Pleno: 2 Juni 2026
4. Pembagian Rapor Semester Genap: 6 Juni 2026

Harap seluruh siswa mempersiapkan kartu peserta ujian dan menyelesaikan seluruh tugas portofolio tepat waktu.

Salam,
Tim Kurikulum SMK Bakti Nusantara 666''',
        bodyHtml: '''
<div style="font-family: Arial, sans-serif; line-height: 1.6; color: #1e293b;">
  <div style="background: linear-gradient(135deg, #1e40af, #3b82f6); color: white; padding: 20px; border-radius: 12px; margin-bottom: 20px;">
    <h2 style="margin: 0; font-size: 20px;">SMK BAKTI NUSANTARA 666</h2>
    <p style="margin: 5px 0 0 0; opacity: 0.9; font-size: 14px;">Pemberitahuan Resmi Kurikulum & Akademik</p>
  </div>
  <p>Yth. Bapak/Ibu Guru dan Siswa/i <strong>SMK Bakti Nusantara 666</strong>,</p>
  <p>Berikut kami sampaikan jadwal pelaksanaan <strong>Asesmen Akhir Semester (AAS)</strong> Tahun Ajaran 2025/2026:</p>
  <table style="width: 100%; border-collapse: collapse; margin: 15px 0;">
    <tr style="background: #f1f5f9;">
      <th style="padding: 10px; border: 1px solid #cbd5e1; text-align: left;">Kegiatan</th>
      <th style="padding: 10px; border: 1px solid #cbd5e1; text-align: left;">Tanggal Pelaksanaan</th>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #cbd5e1;">Ujian Teori Kejuruan & Umum</td>
      <td style="padding: 10px; border: 1px solid #cbd5e1;">18 - 22 Mei 2026</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #cbd5e1;">Uji Kompetensi Keahlian (UKK Praktik)</td>
      <td style="padding: 10px; border: 1px solid #cbd5e1;">25 - 29 Mei 2026</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #cbd5e1;">Pembagian Rapor Semester</td>
      <td style="padding: 10px; border: 1px solid #cbd5e1;"><strong>6 Juni 2026</strong></td>
    </tr>
  </table>
  <p>Silakan unduh lampiran berkas panduan ujian di bawah ini.</p>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;" />
  <p style="font-size: 12px; color: #64748b;"><em>Email ini dikirim secara otomatis melalui sistem BaknusMail Server Mailcow.</em></p>
</div>
''',
        dateTime: now.subtract(const Duration(minutes: 25)),
        isRead: false,
        isStarred: true,
        hasAttachments: true,
        attachments: [
          AttachmentItem(
            fileName: 'Panduan_Jadwal_AAS_2026.pdf',
            mimeType: 'application/pdf',
            sizeInBytes: 1548200,
          ),
          AttachmentItem(
            fileName: 'Tata_Tertib_Ujian.docx',
            mimeType: 'application/msword',
            sizeInBytes: 420100,
          ),
        ],
        folder: 'INBOX',
      ),
      EmailMessage(
        sequenceId: 2,
        messageId: 'demo-msg-002@smk.baktinusantara666.sch.id',
        from: EmailAddressItem(
          name: 'Hubungan Industri & BKK',
          email: 'hubin@smk.baktinusantara666.sch.id',
        ),
        to: [
          EmailAddressItem(
            name: 'Siswa Kelas XI & XII',
            email: 'siswa@smk.baktinusantara666.sch.id',
          )
        ],
        subject: '🚀 Peluang Praktik Kerja Lapangan (PKL) & Rekrutmen Industri Animasi & IT',
        snippet:
            'Kabar gembira! Beberapa industri mitra teknologi dan studio animasi ternama telah membuka kuota PKL untuk siswa SMK BN 666...',
        bodyText: '''Halo Siswa/i SMK Bakti Nusantara 666,

Bursa Kerja Khusus (BKK) dan Hubin membuka pendaftaran Praktik Kerja Lapangan (PKL) & Magang Industri periode Semester Depan untuk kompetensi keahlian:

1. Rekayasa Perangkat Lunak (RPL): Mobile & Web App Developer
2. Animasi (ANM): 3D Modeler, 2D Rigging, Compositor
3. Desain Komunikasi Visual (DKV): UI/UX Designer, Motion Graphic
4. Bisnis Digital (BDP): Social Media Specialist, E-Commerce
5. Akuntansi (AKL): Junior Tax & Accounting Assistant

Kumpulkan portofolio dan CV Anda sebelum tanggal 28 Mei 2026.

Hubin & BKK SMK Bakti Nusantara 666''',
        bodyHtml: '''
<div style="font-family: Arial, sans-serif; line-height: 1.6; color: #1e293b;">
  <div style="background: linear-gradient(135deg, #0d9488, #14b8a6); color: white; padding: 18px; border-radius: 12px; margin-bottom: 18px;">
    <h3 style="margin: 0;">💼 Program Kemitraan Industri & Magang BKK</h3>
  </div>
  <p>Halo Siswa/i <strong>SMK Bakti Nusantara 666</strong>,</p>
  <p>Mitra industri teknologi, studio animasi, dan perbankan telah membuka slot magang & PKL eksklusif untuk siswa berprestasi.</p>
  <ul>
    <li><strong>Studio Animasi 3D</strong> - 10 Kuota (Jurusan Animasi)</li>
    <li><strong>Software House Bandung</strong> - 8 Kuota (Jurusan RPL)</li>
    <li><strong>Agensi Kreatif & Advertising</strong> - 6 Kuota (Jurusan DKV)</li>
  </ul>
  <p>Lampirkan portofolio terbaik kalian di portal BKK.</p>
</div>
''',
        dateTime: now.subtract(const Duration(hours: 2, minutes: 15)),
        isRead: false,
        isStarred: false,
        hasAttachments: false,
        folder: 'INBOX',
      ),
      EmailMessage(
        sequenceId: 3,
        messageId: 'demo-msg-003@smk.baktinusantara666.sch.id',
        from: EmailAddressItem(
          name: 'Kepala Sekolah SMK BN 666',
          email: 'kepsek@smk.baktinusantara666.sch.id',
        ),
        to: [
          EmailAddressItem(
            name: 'Dewan Guru & Staf Tata Usaha',
            email: 'guru@smk.baktinusantara666.sch.id',
          )
        ],
        subject: 'Undangan Rapat Koordinasi Program Unggulan Teaching Factory',
        snippet:
            'Mengundang Bapak/Ibu dewan guru dalam rapat koordinasi pengembangan Teaching Factory berbasis industri...',
        bodyText: '''Bapak/Ibu Dewan Guru yang terhormat,

Sehubungan dengan percepatan program Teaching Factory (TeFa) berbasis industri, kami mengundang Bapak/Ibu pada:

Hari/Tanggal: Kamis, 14 Mei 2026
Waktu: 13.00 WIB - selesai
Tempat: Ruang Multimedia & TeFa SMK Bakti Nusantara 666
Agenda: Koordinasi sinkronisasi kurikulum industri dan evaluasi sarana laboratorium.

Kehadiran tepat waktu sangat kami harapkan.

Kepala SMK Bakti Nusantara 666''',
        bodyHtml: '''
<p>Bapak/Ibu Dewan Guru yang terhormat,</p>
<p>Sehubungan dengan percepatan program <strong>Teaching Factory (TeFa)</strong> berbasis industri, kami mengundang kehadiran Bapak/Ibu pada:</p>
<div style="background: #f8fafc; border-left: 4px solid #1e40af; padding: 12px; margin: 15px 0;">
  <p style="margin: 4px 0;"><strong>Hari/Tanggal:</strong> Kamis, 14 Mei 2026</p>
  <p style="margin: 4px 0;"><strong>Waktu:</strong> 13.00 WIB - selesai</p>
  <p style="margin: 4px 0;"><strong>Tempat:</strong> Ruang Multimedia SMK BN 666</p>
</div>
''',
        dateTime: now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
        isStarred: true,
        hasAttachments: false,
        folder: 'INBOX',
      ),
      EmailMessage(
        sequenceId: 4,
        messageId: 'demo-msg-004@smk.baktinusantara666.sch.id',
        from: EmailAddressItem(
          name: 'Administrator Mailcow Server',
          email: 'admin@smk.baktinusantara666.sch.id',
        ),
        to: [
          EmailAddressItem(
            name: 'Pengguna Email Baknus',
            email: 'user@smk.baktinusantara666.sch.id',
          )
        ],
        subject: '🛡️ Pembaruan Keamanan Mailbox & Sertifikat SSL Server',
        snippet:
            'Server email mail.smk.baktinusantara666.sch.id telah sukses diperbarui ke versi Mailcow terbaru dengan enkripsi TLS 1.3...',
        bodyText: '''Pemberitahuan Sistem:

Server email resmi SMK Bakti Nusantara 666 telah berhasil dikonfigurasi:
- Host: mail.smk.baktinusantara666.sch.id
- IMAP Port: 993 (SSL/TLS Active)
- SMTP Port: 465 (SSL/TLS Active)
- Antivirus & Antispam ClamAV & Rspamd: Berjalan Optimal

Kapasitas kuota mailbox default Anda adalah 3.0 GB.

Admin IT SMK Bakti Nusantara 666''',
        bodyHtml: '''
<div style="font-family: Arial, sans-serif; padding: 15px; border: 1px solid #e2e8f0; border-radius: 8px;">
  <h4 style="color: #10b981; margin-top: 0;">✓ Server Mailcow Siap Digunakan</h4>
  <p>Domain: <code>smk.baktinusantara666.sch.id</code></p>
  <p>Protokol IMAP (993) dan SMTP (465) terproteksi dengan enkripsi SSL/TLS.</p>
</div>
''',
        dateTime: now.subtract(const Duration(days: 2, hours: 5)),
        isRead: true,
        isStarred: false,
        hasAttachments: false,
        folder: 'INBOX',
      ),
      EmailMessage(
        sequenceId: 5,
        messageId: 'demo-msg-sent-001@smk.baktinusantara666.sch.id',
        from: EmailAddressItem(
          name: 'Saya',
          email: 'user@smk.baktinusantara666.sch.id',
        ),
        to: [
          EmailAddressItem(
            name: 'Kurikulum SMK BN 666',
            email: 'kurikulum@smk.baktinusantara666.sch.id',
          )
        ],
        subject: 'Re: Pengumpulan Perangkat Ajar & Modul Praktik Kejuruan',
        snippet:
            'Terima kasih bapak/ibu, berikut saya lampirkan modul ajar dan kisi-kisi soal praktikum...',
        bodyText: '''Yth. Tim Kurikulum SMK Bakti Nusantara 666,

Terlampir dokumen Rencana Pelaksanaan Pembelajaran (RPP) / Modul Ajar dan Kisi-kisi asesmen praktik kejuruan yang telah disesuaikan dengan kurikulum industri.

Mohon konfirmasi jika ada bagian yang perlu direvisi.

Hormat saya,
Pengajar SMK Bakti Nusantara 666''',
        bodyHtml: '''
<p>Yth. Tim Kurikulum SMK Bakti Nusantara 666,</p>
<p>Terlampir dokumen Modul Ajar dan Kisi-kisi asesmen praktik kejuruan yang telah disesuaikan dengan kurikulum industri.</p>
''',
        dateTime: now.subtract(const Duration(days: 3)),
        isRead: true,
        isStarred: false,
        hasAttachments: true,
        attachments: [
          AttachmentItem(
            fileName: 'Modul_Ajar_RPL_Semester_Genap.pdf',
            mimeType: 'application/pdf',
            sizeInBytes: 3120000,
          )
        ],
        folder: 'Sent',
      ),
    ];
  }
}
