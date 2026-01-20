// ✅ Firebase Functions v2 imports
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// 💬 Real-time Chat Notifications — Minimal "on Taggin" Style
exports.sendChatNotification = onDocumentCreated(
  "messages/{chatId}/chats/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const toUserId = message.to;
    const fromUserId = message.senderId;

    if (!toUserId || !fromUserId) {
      console.log("⚠️ Missing 'to' or 'senderId' in message:", message);
      return;
    }

    // Fetch receiver info
    const toUserDoc = await db.collection("users").doc(toUserId).get();
    if (!toUserDoc.exists) {
      console.log(`⚠️ Receiver not found: ${toUserId}`);
      return;
    }

    const userData = toUserDoc.data();
    const tokens = [];
    if (userData.fcmToken) tokens.push(userData.fcmToken);
    if (userData.fcmTokenWeb) tokens.push(userData.fcmTokenWeb);

    if (tokens.length === 0) {
      console.log(`⚠️ No FCM tokens found for user ${toUserId}`);
      return;
    }

    // Fetch sender info
    const fromDoc = await db.collection("users").doc(fromUserId).get();
    const fromName = fromDoc.exists
      ? fromDoc.data().username || "Someone"
      : "Someone";

    // 📨 Minimal Notification Format
    const payload = {
      notification: {
        title: "You’ve got a new message",
        body: "on Taggin",
        icon: "/icons/Icon-192.png",
      },
      data: {
        type: "chat",
        chatId: event.params.chatId,
        senderId: fromUserId,
        senderName: fromName,
      },
      android: {
        notification: {
          channelId: "taggin_chat",
          color: "#000000",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // 🔔 Send notifications to all valid tokens
    const results = await Promise.allSettled(
      tokens.map((token) => admin.messaging().send({ ...payload, token }))
    );

    // 🧹 Cleanup invalid tokens
    const invalidTokens = results
      .map((r, i) => ({ result: r, token: tokens[i] }))
      .filter(
        ({ result }) =>
          result.status === "rejected" &&
          result.reason?.code === "messaging/registration-token-not-registered"
      )
      .map(({ token }) => token);

    if (invalidTokens.length > 0) {
      console.log(`🧹 Cleaning up invalid tokens for ${toUserId}:`, invalidTokens);
      const updates = {};
      if (invalidTokens.includes(userData.fcmToken))
        updates.fcmToken = admin.firestore.FieldValue.delete();
      if (invalidTokens.includes(userData.fcmTokenWeb))
        updates.fcmTokenWeb = admin.firestore.FieldValue.delete();
      await db.collection("users").doc(toUserId).update(updates);
    }

    const successCount = results.filter((r) => r.status === "fulfilled").length;
    console.log(`✅ Sent ${successCount} chat notification(s) to ${toUserId}`);
  }
);
