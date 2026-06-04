const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const admin = require("firebase-admin");

admin.initializeApp();

const db = getFirestore();

// ─────────────────────────────────────────────────────
// LOCALIZED NOTIFICATION STRINGS
// Add more languages here as the app grows
// ─────────────────────────────────────────────────────
const strings = {
  es: {
    matchRequestTitle: "🎾 Nueva solicitud de partido",
    matchRequestBody: (name) =>
      `${name} quiere jugar un partido contigo!`,
    matchAcceptedTitle: "🎾 ¡Solicitud de partido aceptada!",
    matchAcceptedBody: (name) =>
      `${name} aceptó tu solicitud de partido. ¡Ya puedes chatear!`,
    matchReminderTitle: "🎾 Recordatorio de partido",
    matchReminder24hBody: (name) =>
      `¡Tu partido con ${name} es mañana!`,
    matchReminder1hBody: (name) =>
      `¡Tu partido con ${name} comienza en 1 hora!`,
  },
  en: {
    matchRequestTitle: "🎾 New Match Request",
    matchRequestBody: (name) =>
      `${name} wants to play a match with you!`,
    matchAcceptedTitle: "🎾 Match Request Accepted!",
    matchAcceptedBody: (name) =>
      `${name} accepted your match request. You can now chat!`,
    matchReminderTitle: "🎾 Match Reminder",
    matchReminder24hBody: (name) =>
      `Your match with ${name} is tomorrow!`,
    matchReminder1hBody: (name) =>
      `Your match with ${name} starts in 1 hour!`,
  },
};

/**
 * Returns the localized strings for the given locale,
 * falling back to English if the locale is not supported.
 *
 * @param {string} locale - The user's locale (e.g. "es", "en").
 * @return {object} The strings object for the given locale.
 */
function getStrings(locale) {
  return strings[locale] || strings["en"];
}

/**
 * Sends an FCM push notification to all tokens of a given user.
 * Automatically cleans up any invalid tokens found during sending.
 *
 * @param {string} recipientUid - The UID of the user to notify.
 * @param {object} payload - The FCM message payload to send.
 * @return {Promise<void>}
 */
async function sendPushToUser(recipientUid, payload) {
  const userSnap = await db
      .collection("users")
      .doc(recipientUid)
      .get();

  if (!userSnap.exists) return;

  const tokensMap = userSnap.data().fcmTokens || {};
  const tokens = Object.keys(tokensMap);

  if (tokens.length === 0) {
    console.log("❌ No FCM tokens for user", recipientUid);
    return;
  }

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    ...payload,
  });

  console.log(
      `✅ Push sent to ${recipientUid}:`,
      `${response.successCount} success,`,
      `${response.failureCount} failed`,
  );

  // Clean up invalid tokens
  for (let i = 0; i < response.responses.length; i++) {
    const resp = response.responses[i];
    if (!resp.success) {
      const errorCode = resp.error && resp.error.code;
      const errorMsg = resp.error && resp.error.message;
      console.log("❌ Failed token:", tokens[i],
          "Code:", errorCode, "Message:", errorMsg);

      if (
        errorCode === "messaging/registration-token-not-registered" ||
        errorCode === "messaging/invalid-registration-token"
      ) {
        await db
            .collection("users")
            .doc(recipientUid)
            .update({
              [`fcmTokens.${tokens[i]}`]:
                admin.firestore.FieldValue.delete(),
            });
        console.log("🧹 Removed invalid token:", tokens[i]);
      }
    }
  }
}

// ─────────────────────────────────────────────────────
// 1. NEW CHAT MESSAGE
//    Notifies the opponent when a new message is sent
// ─────────────────────────────────────────────────────
exports.onNewChatMessage = onDocumentCreated(
    "matches/{matchId}/messages/{messageId}",
    async (event) => {
      const messageSnap = event.data;
      if (!messageSnap) return;

      const message = messageSnap.data();
      const senderUid = message.senderUid;
      const matchId = event.params.matchId;

      // Get sender info
      const senderSnap = await db
          .collection("users")
          .doc(senderUid)
          .get();

      let senderName = "Player";
      let senderPhotoUrl = "";

      if (senderSnap.exists) {
        const senderData = senderSnap.data();
        senderName = senderData.name || "Player";
        senderPhotoUrl = senderData.photoUrl || "";
      }

      // Get match to find recipient
      const matchSnap = await db
          .collection("matches")
          .doc(matchId)
          .get();

      if (!matchSnap.exists) return;

      const match = matchSnap.data();
      const recipientUid =
        match.player1Uid === senderUid ?
          match.player2Uid :
          match.player1Uid;

      if (!recipientUid) {
        console.log("❌ recipientUid is undefined");
        return;
      }

      // Skip if recipient is actively in the chat
      const activeChatUsers = match.activeChatUsers || {};
      if (activeChatUsers[recipientUid] === true) {
        console.log("🔕 User is inside chat. Skipping push.");
        return;
      }

      // Chat notifications use sender name + message text —
      // no localization needed as the content is always user-written
      const androidNotification = {
        channelId: "default",
      };

      // Only include imageUrl if it's a non-empty string
      if (senderPhotoUrl && senderPhotoUrl.length > 0) {
        androidNotification.imageUrl = senderPhotoUrl;
      }

      await sendPushToUser(recipientUid, {
        notification: {
          title: senderName,
          body: message.text,
        },
        android: {
          notification: {
            ...androidNotification,
            // Use matchId as tag so messages in the same chat
            // replace each other instead of stacking
            tag: `chat_${matchId}`,
          },
        },
        data: {
          type: "chat_message",
          matchId: matchId,
          senderUid: senderUid,
        },
      });
    },
);

// ─────────────────────────────────────────────────────
// 2. NEW MATCH REQUEST RECEIVED
//    Notifies User B when User A sends a match request
// ─────────────────────────────────────────────────────
exports.onMatchRequestReceived = onDocumentCreated(
    "match_requests/{requestId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const request = snap.data();
      const fromUid = request.fromUid;
      const toUid = request.toUid;

      if (!fromUid || !toUid) return;

      // Get sender's name
      const fromSnap = await db
          .collection("users")
          .doc(fromUid)
          .get();

      const fromName = fromSnap.exists ?
        (fromSnap.data().name || "A player") :
        "A player";

      // Get recipient's locale for localized notification
      const toSnap = await db
          .collection("users")
          .doc(toUid)
          .get();

      const locale = toSnap.exists ?
        (toSnap.data().locale || "en") :
        "en";

      const t = getStrings(locale);

      await sendPushToUser(toUid, {
        notification: {
          title: t.matchRequestTitle,
          body: t.matchRequestBody(fromName),
        },
        android: {
          notification: {
            channelId: "default",
          },
        },
        data: {
          type: "match_request",
          requestId: event.params.requestId,
          fromUid: fromUid,
        },
      });
    },
);

// ─────────────────────────────────────────────────────
// 3. MATCH REQUEST ACCEPTED
//    Notifies User A when User B accepts their request
// ─────────────────────────────────────────────────────
exports.onMatchRequestAccepted = onDocumentUpdated(
    "match_requests/{requestId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (!before || !after) return;

      // Only fire when status transitions to 'accepted'
      if (before.status === after.status) return;
      if (after.status !== "accepted") return;

      const fromUid = after.fromUid; // original sender
      const toUid = after.toUid; // the one who accepted

      if (!fromUid || !toUid) return;

      // Get acceptor's name
      const toSnap = await db
          .collection("users")
          .doc(toUid)
          .get();

      const toName = toSnap.exists ?
        (toSnap.data().name || "Your opponent") :
        "Your opponent";

      // Get original sender's locale for localized notification
      const fromSnap = await db
          .collection("users")
          .doc(fromUid)
          .get();

      const locale = fromSnap.exists ?
        (fromSnap.data().locale || "en") :
        "en";

      const t = getStrings(locale);

      await sendPushToUser(fromUid, {
        notification: {
          title: t.matchAcceptedTitle,
          body: t.matchAcceptedBody(toName),
        },
        android: {
          notification: {
            channelId: "default",
          },
        },
        data: {
          type: "match_accepted",
          requestId: event.params.requestId,
          toUid: toUid,
        },
      });
    },
);

// ─────────────────────────────────────────────────────
// 4. MATCH SCHEDULE REMINDERS
//    Runs every 30 minutes. Sends push notifications to
//    both players when a match is scheduled within the
//    next 24 hours (24h reminder) or next hour (1h reminder).
// ─────────────────────────────────────────────────────
exports.onMatchScheduleReminder = onSchedule("every 30 minutes", async () => {
  const now = new Date();

  // Window boundaries
  const in23h = new Date(now.getTime() + 23 * 60 * 60 * 1000);
  const in25h = new Date(now.getTime() + 25 * 60 * 60 * 1000);
  const in30min = new Date(now.getTime() + 30 * 60 * 1000);
  const in90min = new Date(now.getTime() + 90 * 60 * 1000);

  // Fetch all confirmed matches with a scheduledDate
  const snapshot = await db.collection("matches")
      .where("status", "==", "confirmed")
      .where("scheduledDate", ">=", in30min)
      .where("scheduledDate", "<=", in25h)
      .get();

  if (snapshot.empty) {
    console.log("No scheduled matches found in reminder window.");
    return;
  }

  console.log(`Found ${snapshot.docs.length} matches in reminder window.`);

  for (const doc of snapshot.docs) {
    const match = doc.data();
    const scheduledDate = match.scheduledDate.toDate();
    const matchId = doc.id;
    const players = match.players || [];

    if (players.length < 2) continue;

    const player1Uid = match.player1Uid || players[0];
    const player2Uid = match.player2Uid || players[1];

    // Determine which reminder type based on scheduled time
    const is24hWindow = scheduledDate >= in23h && scheduledDate <= in25h;
    const is1hWindow = scheduledDate >= in30min && scheduledDate <= in90min;

    if (!is24hWindow && !is1hWindow) continue;

    // Get both players' names
    const [p1Snap, p2Snap] = await Promise.all([
      db.collection("users").doc(player1Uid).get(),
      db.collection("users").doc(player2Uid).get(),
    ]);

    const p1Name = p1Snap.exists ?
        (p1Snap.data().name || "Your opponent") : "Your opponent";
    const p2Name = p2Snap.exists ?
        (p2Snap.data().name || "Your opponent") : "Your opponent";

    // Send to player 1 — opponent is player 2
    const p1Locale = p1Snap.exists ?
        (p1Snap.data().locale || "en") : "en";
    const t1 = getStrings(p1Locale);
    const body1 = is24hWindow ?
        t1.matchReminder24hBody(p2Name) :
        t1.matchReminder1hBody(p2Name);

    await sendPushToUser(player1Uid, {
      notification: {title: t1.matchReminderTitle, body: body1},
      android: {notification: {channelId: "default",
        tag: `reminder_${matchId}`}},
      data: {type: "match_reminder", matchId: matchId},
    });

    // Send to player 2 — opponent is player 1
    const p2Locale = p2Snap.exists ?
        (p2Snap.data().locale || "en") : "en";
    const t2 = getStrings(p2Locale);
    const body2 = is24hWindow ?
        t2.matchReminder24hBody(p1Name) :
        t2.matchReminder1hBody(p1Name);

    await sendPushToUser(player2Uid, {
      notification: {title: t2.matchReminderTitle, body: body2},
      android: {notification: {channelId: "default",
        tag: `reminder_${matchId}`}},
      data: {type: "match_reminder", matchId: matchId},
    });

    console.log(
        `✅ Reminder sent for match ${matchId}`,
        `(${is24hWindow ? "24h" : "1h"} window)`,
    );
  }
});
