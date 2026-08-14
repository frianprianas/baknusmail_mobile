const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

exports.incomingEmailWebhook = onRequest({ cors: true }, async (req, res) => {
  // Hanya menerima metode POST
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  try {
    let body = req.body;
    // Handle jika body dikirim sebagai raw string JSON
    if (typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch (e) {
        // Abaikan parse error jika sudah object
      }
    }

    const to = body?.to;
    const from = body?.from;
    const subject = body?.subject || "Tidak ada subjek";

    if (!to || !from) {
      return res.status(400).json({
        error: "Missing 'to' or 'from' in request body",
        received: body,
      });
    }

    // Extract raw body or html and clean HTML tags for notification body/snippet
    const rawContent = body?.snippet || body?.body || body?.text || body?.html || "";
    const cleanSnippet = rawContent
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, " ")
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, " ")
      .trim();

    const displayBody = cleanSnippet.length > 120
      ? cleanSnippet.substring(0, 120) + "..."
      : (cleanSnippet || subject);

    // 1. Ambil FCM Token berdasarkan alamat email (to) dari Firestore
    const userDoc = await admin
      .firestore()
      .collection("user_tokens")
      .doc(to.toLowerCase().trim())
      .get();

    if (!userDoc.exists) {
      logger.info(`No FCM token found for user: ${to}`);
      return res.status(404).json({ message: `User token not found for ${to}` });
    }

    const fcmToken = userDoc.data().fcm_token;

    // Tentukan channel_id & sound berdasarkan pengirim / subjek email
    const lowerFrom = (from || "").toLowerCase();
    const lowerSubject = (subject || "").toLowerCase();
    let channelId = "channel_email_umum_v3";
    let soundName = "sound_umum";

    if (
      lowerFrom.includes("attend") ||
      lowerFrom.includes("presensi") ||
      lowerSubject.includes("baknusattend") ||
      lowerSubject.includes("attend") ||
      lowerSubject.includes("presensi") ||
      lowerSubject.includes("kehadiran")
    ) {
      channelId = "channel_baknus_attend_v3";
      soundName = "sound_baknus_attend";
    } else if (
      lowerFrom.includes("drive") ||
      lowerSubject.includes("baknusdrive") ||
      lowerSubject.includes("drive") ||
      lowerSubject.includes("berkas") ||
      lowerSubject.includes("penyimpanan")
    ) {
      channelId = "channel_baknus_drive_v3";
      soundName = "sound_baknus_drive";
    } else if (
      lowerFrom.includes("talim") ||
      lowerFrom.includes("ta'lim") ||
      lowerSubject.includes("baknustalim") ||
      lowerSubject.includes("talim") ||
      lowerSubject.includes("ta'lim") ||
      lowerSubject.includes("kajian")
    ) {
      channelId = "channel_baknus_talim_v3";
      soundName = "sound_baknus_talim";
    }

    // 2. Siapkan payload notifikasi (data-only agar background handler Dart dipanggil)
    // Dengan data-only, FCM tidak tampilkan notifikasi sendiri - semua ditangani Flutter
    // sehingga suara custom channel selalu digunakan
    const message = {
      android: {
        collapseKey: "baknus_email_latest",
        priority: "high",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        route: "/home",
        email_to: to,
        email_from: from,
        subject: subject,
        notif_title: "Email Baru",
        notif_body: "Anda mendapatkan pesan baru",
        channel_id: channelId,
        sound_name: soundName,
      },
      token: fcmToken,
    };

    // 3. Kirim ke Firebase Cloud Messaging
    const response = await admin.messaging().send(message);

    logger.info(`Successfully sent message to ${to}: ${response}`);
    return res.status(200).json({ success: true, messageId: response });
  } catch (error) {
    logger.error("Error sending notification:", error);
    return res.status(500).json({ error: error.message || "Internal Server Error" });
  }
});
