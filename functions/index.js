const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const admin = require("firebase-admin");

admin.initializeApp();

const db = getFirestore();

exports.onNewChatMessage = onDocumentCreated(
    "matches/{matchId}/messages/{messageId}",
    async (event) => {
      const messageSnap = event.data;
      if (!messageSnap) return;

      const message = messageSnap.data();
      const senderUid = message.senderUid;
      const matchId = event.params.matchId;

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

      const matchSnap = await db
          .collection("matches")
          .doc(matchId)
          .get();

      if (!matchSnap.exists) return;

      const match = matchSnap.data();

      // FIRST determine recipient
      const recipientUid =
        match.player1Uid === senderUid ?
          match.player2Uid :
          match.player1Uid;

      if (!recipientUid) {
        console.log("❌ recipientUid is undefined");
        return;
      }

      // THEN check if recipient is active in this chat
      const activeChatUsers = match.activeChatUsers || {};
      const isRecipientActive =
        activeChatUsers[recipientUid] === true;

      if (isRecipientActive) {
        console.log("🔕 User is inside chat. Skipping push.");
        return;
      }

      const userSnap = await db
          .collection("users")
          .doc(recipientUid)
          .get();

      if (!userSnap.exists) return;

      const user = userSnap.data();

      const tokensMap = user.fcmTokens || {};
      const tokens = Object.keys(tokensMap);


      if (tokens.length === 0) {
        console.log("❌ No FCM tokens for user", recipientUid);
        return;
      }


      const response = await getMessaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: senderName,
          body: message.text,
        },
        android: {
          notification: {
            imageUrl: senderPhotoUrl,
            channelId: "default",
          },
        },
        data: {
          matchId: matchId,
          senderUid: senderUid,
        },
      });

      console.log("✅ Push notification sent");

      for (let i = 0; i < response.responses.length; i++) {
        const resp = response.responses[i];

        if (!resp.success) {
          const failedToken = tokens[i];

          console.log("❌ Failed token:", failedToken);
          console.log("Error:", resp.error && resp.error.code);

          const errorCode = resp.error && resp.error.code;

          if (
            errorCode === "messaging/registration-token-not-registered" ||
            errorCode === "messaging/invalid-registration-token"
          ) {
            const fieldPath =
              `fcmTokens.${failedToken}`;

            await db.collection("users")
                .doc(recipientUid)
                .update({
                  [fieldPath]:
                  admin.firestore.FieldValue.delete(),
                });

            console.log("🧹 Removed invalid token:", failedToken);
          }
        }
      }
    },
);
