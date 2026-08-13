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

    // 2. Siapkan payload notifikasi
    const message = {
      notification: {
        title: `Email Baru dari ${from}`,
        body: subject,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        email_to: to,
        email_from: from,
        subject: subject,
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
