// Import v2 functions
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");

// Initialize the Firebase Admin SDK
initializeApp();

const db = getFirestore();

/**
 * Triggers when a new message is created in any chat room.
 * It finds the recipient and sends them a push notification.
 */
exports.sendChatNotification = onDocumentCreated("/chats/{chatId}/messages/{messageId}", async (event) => {
  
  // Get the new message data
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }
  const newMessage = snap.data();
  const senderId = newMessage.senderId;

  // Get the chat ID from the parameters
  const chatId = event.params.chatId;

  try {
    // 1. Get the chat room to find participants
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      console.log("Chat document not found.");
      return;
    }
    const participants = chatDoc.data().participants;

    // 2. Find the recipient's ID
    const recipientId = participants.find((uid) => uid !== senderId);
    if (!recipientId) {
      console.log("Recipient not found.");
      return;
    }

    // 3. Get the sender's profile
    const senderDoc = await db.collection("users").doc(senderId).get();
    if (!senderDoc.exists) {
      console.log("Sender document not found.");
      return;
    }
    const senderData = senderDoc.data();
    const senderName = senderData.displayName || "Someone";
    const senderPhoto = senderData.photoUrl || "";

    // 4. Get the recipient's profile to find their FCM tokens
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    if (!recipientDoc.exists) {
      console.log("Recipient document not found.");
      return;
    }
    const fcmTokens = recipientDoc.data().fcmTokens;

    // 5. Check if the recipient has any tokens
    if (!fcmTokens || fcmTokens.length === 0) {
      console.log("Recipient has no FCM tokens.");
      return;
    }

    // 6. Construct the notification payload
    const payload = {
      notification: {
        title: senderName,
        body: newMessage.text || "Sent you a message",
      },
      data: {
        chatId: chatId,
        recipientId: senderId,
        recipientName: senderName,
        recipientPhotoUrl: senderPhoto,
      },
    };

    // 7. Send the notification to all of the recipient's devices using sendMulticast
    console.log(`Sending notification to ${fcmTokens.length} token(s)...`);
    
    // Build multicast message - tokens must be passed as an array separately
    const message = {
      notification: payload.notification,
      data: payload.data,
      tokens: fcmTokens,
    };

    const response = await getMessaging().sendMulticast(message);
    
    console.log(`Successfully sent ${response.successCount} notifications`);
    if (response.failureCount > 0) {
      console.log(`Failed to send ${response.failureCount} notifications`);
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.log(`Failed to send to token ${fcmTokens[idx]}: ${resp.error}`);
        }
      });
    }

    return response;

  } catch (error) {
    console.error("Error sending chat notification:", error);
    return;
  }
});