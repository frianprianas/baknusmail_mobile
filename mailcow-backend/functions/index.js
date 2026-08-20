const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * 1. Webhook Email Masuk (Mailcow -> Firebase FCM)
 */
exports.incomingEmailWebhook = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  try {
    let body = req.body;
    if (typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch (e) {}
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

    // Ambil FCM Token berdasarkan alamat email (to) dari Firestore
    const userDoc = await admin
      .firestore()
      .collection("user_tokens")
      .doc(to.toLowerCase().trim())
      .get();

    if (!userDoc.exists) {
      logger.info(`No FCM token found for user: ${to}`);
      return res.status(404).json({ message: `User token not found for ${to}` });
    }

    const userData = userDoc.data();
    let tokens = userData.fcm_tokens || [];
    if (tokens.length === 0 && userData.fcm_token) {
      tokens = [userData.fcm_token];
    }

    if (tokens.length === 0) {
      logger.info(`No valid FCM tokens found for user: ${to}`);
      return res.status(404).json({ message: `No FCM tokens found for ${to}` });
    }

    // Tentukan channel_id, sound, route, dan notif_title berdasarkan pengirim / subjek email
    const lowerFrom = (from || "").toLowerCase();
    const lowerSubject = (subject || "").toLowerCase();
    let channelId = "channel_email_umum_v3";
    let soundName = "sound_umum";
    let route = "/home";
    let notifTitle = "Pesan Masuk";

    const senderDisplayName = from.includes("<")
      ? from.split("<")[0].trim()
      : from.split("@")[0].trim();

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
      route = "/attend";
      notifTitle = "BaknusAttend - Presensi";
    } else if (
      lowerFrom.includes("drive") ||
      lowerSubject.includes("baknusdrive") ||
      lowerSubject.includes("drive") ||
      lowerSubject.includes("berkas") ||
      lowerSubject.includes("penyimpanan")
    ) {
      channelId = "channel_baknus_drive_v3";
      soundName = "sound_baknus_drive";
      route = "/drive";
      notifTitle = "BaknusDrive - Berkas";
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
      route = "/talim";
      notifTitle = "BaknusTalim - Kegiatan";
    } else {
      notifTitle = senderDisplayName ? `Email dari ${senderDisplayName}` : "Email Baru Masuk";
    }

    const message = {
      android: {
        collapseKey: `baknus_${channelId}`,
        priority: "high",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        route: route,
        email_to: to,
        email_from: from,
        subject: subject,
        notif_title: notifTitle,
        notif_body: displayBody,
        channel_id: channelId,
        sound_name: soundName,
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    logger.info(
      `Multicast result for ${to}: Total=${tokens.length}, Success=${response.successCount}, Failure=${response.failureCount}`
    );

    return res.status(200).json({
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      totalDevices: tokens.length,
    });
  } catch (error) {
    logger.error("Error sending notification:", error);
    return res.status(500).json({ error: error.message || "Internal Server Error" });
  }
});

/**
 * 2. Firestore Trigger Otomatis saat Pesan Japri Baru Masuk (BaknusChat)
 */
exports.onChatMessageCreated = onDocumentCreated(
  "baknus_chat_rooms/{roomId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const roomId = event.params.roomId;

    // Hanya kirim notifikasi jika ini adalah room Japri (dm_email1___email2)
    if (!roomId.startsWith("dm_")) return;

    const senderEmail = (data.senderEmail || "").toLowerCase().trim();
    const senderName = data.senderName || "Pengguna";
    const senderRole = data.senderRole || "Siswa";
    const messageText = data.text || "Mengirim pesan baru";

    // Ekstrak kedua email dari roomId 'dm_email1___email2'
    const rawEmails = roomId.replace("dm_", "").split("___");
    if (rawEmails.length < 2) return;

    // Tentukan penerima (email yang bukan senderEmail)
    let recipientEmail = rawEmails.find(
      (e) => !senderEmail.replace(/[^a-zA-Z0-9_]/g, "_").includes(e)
    );

    if (!recipientEmail) {
      recipientEmail = rawEmails[0] === senderEmail ? rawEmails[1] : rawEmails[0];
    }

    // Ambil FCM Token penerima dari Firestore
    const userDoc = await admin
      .firestore()
      .collection("user_tokens")
      .doc(recipientEmail.toLowerCase().trim())
      .get();

    if (!userDoc.exists) {
      logger.info(`[BaknusChat] No tokens found for recipient: ${recipientEmail}`);
      return;
    }

    const userData = userDoc.data();
    let tokens = userData.fcm_tokens || [];
    if (tokens.length === 0 && userData.fcm_token) {
      tokens = [userData.fcm_token];
    }

    if (tokens.length === 0) return;

    const notifTitle = `💬 ${senderName} [${senderRole}]`;
    const notifBody = messageText.length > 100
      ? messageText.substring(0, 100) + "..."
      : messageText;

    const payload = {
      android: {
        priority: "high",
        notification: {
          channelId: "channel_email_umum_v3",
          priority: "max",
          defaultSound: true,
        },
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        route: "/chat",
        notif_title: notifTitle,
        notif_body: notifBody,
        channel_id: "channel_email_umum_v3",
        sound_name: "sound_umum",
        sender_email: senderEmail,
        sender_name: senderName,
        sender_tag: senderRole,
        peer_email: senderEmail,
        peer_name: senderName,
        peer_tag: senderRole,
      },
      notification: {
        title: notifTitle,
        body: notifBody,
      },
      tokens: tokens,
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(payload);
      logger.info(
        `[BaknusChat] Sent direct message notification to ${recipientEmail}: Success=${response.successCount}`
      );
    } catch (e) {
      logger.error(`[BaknusChat] Error sending notification to ${recipientEmail}:`, e);
    }
  }
);
