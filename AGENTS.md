# Aturan Proyek (Workspace Rules)

## Lingkungan Pengembangan (Workstation Only)
1. **Hanya Workstation untuk Koding**:
   - Mesin/komputer lokal ini HANYA digunakan sebagai workstation untuk menulis, mengedit, dan me-review kode.
   - **DILARANG KERAS** menjalankan Docker (`docker`, `docker compose`, dsb.) atau service container di komputer lokal ini.
   - Jangan pernah menyarankan, mencoba mengeksekusi, atau menjalankan Docker di mesin ini.

## Deployment & Server Workflow
2. **Sinkronisasi via Git**:
   - Semua perubahan kode dan update aplikasi disinkronkan ke server melalui Git (`git commit`, `git push` ke remote repository).
   - Server yang bertanggung jawab untuk menjalankan container/service dan production runtime.

## Identitas Git Pengembang
3. **Akun & Identitas Git**:
   - Username: `frianprianas`
   - Email: `freeyhan87@hotmail.com`
   - Remote: `https://github.com/frianprianas/baknusmail_mobile.git`
   - Agent AI harus selalu menggunakan dan mengingat identitas ini untuk setiap operasi Git di workstation ini tanpa perlu ditanyakan kembali.

---
# AGENTS.md - Aturan Ketat untuk AI / Coding Assistant

Dokumen ini adalah pedoman dan batasan mutlak bagi seluruh AI Coding Assistant (Antigravity, Gemini, Claude, Cursor, Copilot, dll.) yang bekerja di repositori ini.

---

## ⛔ PERINGATAN KERAS: PROTEKSI SISTEM NOTIFIKASI FCM & EMAIL

Arsitektur push notification di aplikasi **BaknusMail** telah terintegrasi secara presisi dengan server produksi backend (commit `0f471ee`) dan diverifikasi untuk kepatuhan Android 12, 13, dan 14+.

### 1. Berkas yang Dilindungi (Protected Files):
- `lib/data/services/fcm_service.dart`
- `lib/providers/mail_provider.dart` (khusus logika `_knownEmailIds`, `syncNewEmailsInBackground`, `_startPeriodicSyncTimer`, dan `showIncomingEmailNotification`)
- `mailcow-backend/functions/index.js`
- `android/app/src/main/AndroidManifest.xml` (khusus tag `com.google.firebase.messaging.default_notification_channel_id`)
- `android/app/src/main/res/raw/sound_umum.mp3`

### 2. Aturan Baku yang TIDAK BOLEH Diubah / Dihapus:
1. **Channel ID & Sound Name Wajib Tetap**:
   - Channel ID untuk email umum **HARUS TETAP**: `'channel_email_umum_v4'` (jangan pernah diubah ke v3, v5, atau nama lain).
   - Suara notifikasi **HARUS TETAP**: `'sound_umum'` (mengacu ke `android/app/src/main/res/raw/sound_umum.mp3`).
   - Channel Attend: `'channel_baknus_attend_v4'` (`sound_baknus_attend`).
   - Channel Drive: `'channel_baknus_drive_v4'` (`sound_baknus_drive`).
   - Channel Talim: `'channel_baknus_talim_v4'` (`sound_baknus_talim`).
2. **Payload FCM Wajib Memiliki Root `notification` & `android.notification`**:
   - DILARANG MENGUBAH payload FCM menjadi `data-only`. Blok root `notification: { title, body }` dan `android: { notification: { channelId, sound } }` adalah syarat mutlak agar status bar Android menampilkan notifikasi saat aplikasi tertutup.
3. **Pelacak Email Baru & Background Sync di Client**:
   - Logika `_knownEmailIds` dan `syncNewEmailsInBackground()` di `MailProvider` adalah sistem pengaman ganda yang wajib dipertahankan.
4. **Sinkronisasi Token**:
   - Logika `onTokenRefresh` dengan pemulihan session di `FCMService` tidak boleh dihapus.

### 3. Protokol Jika Ada Permintaan Perubahan:
- AI **DILARANG** melakukan modifikasi pada komponen-komponen di atas secara diam-diam.
- Jika pengguna meminta perubahan yang berdampak pada notifikasi, AI **WAJIB MEMBERIKAN PERINGATAN KERAS** terlebih dahulu yang menjelaskan dampak perubahan terhadap sinkronisasi server produksi sebelum melakukan perubahan apapun.
