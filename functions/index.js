const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.sendChatNotification = functions
  .region('us-central1')
  .firestore
  .document('/chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const newMessage = snap.data();
      const chatId = context.params.chatId;
      const senderId = newMessage.senderId;

      console.log(`📨 New message in chat ${chatId} from ${senderId}`);

      // Validate required fields
      if (!senderId || !chatId) {
        console.error('❌ Missing senderId or chatId');
        return;
      }

      // Step 1: Fetch the chat document to get participants
      const chatDoc = await db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        console.error(`❌ Chat document not found: ${chatId}`);
        return;
      }

      const chatData = chatDoc.data();
      const participants = chatData.participants || [];

      console.log(`✅ Chat participants: ${participants.join(', ')}`);

      // Step 2: Find the recipient (participant who is not the sender)
      const recipientId = participants.find(id => id !== senderId);
      if (!recipientId) {
        console.error('❌ Could not identify recipient');
        return;
      }

      console.log(`👤 Recipient identified: ${recipientId}`);

      // Step 3: Fetch sender's information
      const senderDoc = await db.collection('users').doc(senderId).get();
      if (!senderDoc.exists) {
        console.error(`❌ Sender document not found: ${senderId}`);
        return;
      }

      const senderData = senderDoc.data();
      const senderDisplayName = senderData.displayName || 'Unknown User';
      const senderPhotoUrl = senderData.photoUrl || '';

      console.log(`✅ Sender info retrieved: ${senderDisplayName}`);

      // Step 4: Fetch recipient's FCM tokens
      const recipientDoc = await db.collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) {
        console.error(`❌ Recipient document not found: ${recipientId}`);
        return;
      }

      const recipientData = recipientDoc.data();
      const fcmTokens = recipientData.fcmTokens || [];

      if (!fcmTokens || fcmTokens.length === 0) {
        console.warn(`⚠️ No FCM tokens found for recipient: ${recipientId}`);
        return;
      }

      console.log(`✅ Found ${fcmTokens.length} FCM token(s) for recipient`);

      // Step 5: Construct the notification payload
      const payload = {
        notification: {
          title: senderDisplayName,
          body: newMessage.text || 'New message',
          sound: 'default',
        },
        data: {
          chatId: chatId,
          recipientName: senderDisplayName,
          recipientPhotoUrl: senderPhotoUrl,
          senderId: senderId,
          messageId: context.params.messageId,
          timestamp: new Date().toISOString(),
        },
        android: {
          ttl: 86400, // 24 hours
          priority: 'high',
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
        },
      };

      console.log('📤 Sending notification to tokens:', fcmTokens);

      // Step 6: Send notification
      const response = await messaging.sendToDevice(fcmTokens, payload);

      console.log(`✅ Notification sent successfully`);
      console.log(`   - Success: ${response.successCount}`);
      console.log(`   - Failure: ${response.failureCount}`);

      // Step 7: Handle failed tokens (cleanup invalid tokens)
      if (response.failureCount > 0) {
        const failedTokens = [];
        
        response.results.forEach((result, index) => {
          const error = result.error;
          if (error) {
            console.error(`❌ Failed to send to token ${index}:`, error.code);
            
            // Check if token is invalid
            if (
              error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered' ||
              error.code === 'messaging/mismatched-credential'
            ) {
              failedTokens.push(fcmTokens[index]);
            }
          }
        });

        // Remove invalid tokens from Firestore
        if (failedTokens.length > 0) {
          console.log(`🧹 Removing ${failedTokens.length} invalid token(s)`);
          await db.collection('users').doc(recipientId).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens),
          });
        }
      }

      return {
        success: true,
        sentTo: response.successCount,
        failed: response.failureCount,
      };
    } catch (error) {
      console.error('❌ Error in sendChatNotification:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });
