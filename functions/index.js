const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { CloudTasksClient } = require('@google-cloud/tasks');

admin.initializeApp();

// Cloud Tasks configuration
const tasksClient = new CloudTasksClient();
const PROJECT_ID = 'togetherremind';
const LOCATION = 'us-central1';
const QUEUE_NAME = 'reminder-queue';

/**
 * Cloud Function to send reminder push notifications
 * Callable from Flutter app
 */
exports.sendReminder = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, reminderText, reminderId, scheduledFor } = request.data;

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!reminderText) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Reminder text is required'
      );
    }

    if (!reminderId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Reminder ID is required'
      );
    }

    // For MVP: Send notification immediately
    // Production TODO: Use Cloud Tasks for scheduled delivery

    console.log(`Sending reminder to ${partnerToken}:`, {
      senderName,
      reminderText,
      reminderId,
      scheduledFor,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: `Reminder from ${senderName || 'Your Partner'}`,
        body: reminderText,
      },
      data: {
        reminderId: reminderId,
        fromName: senderName || 'Your Partner',
        type: 'reminder',
        text: reminderText,
        scheduledFor: scheduledFor || new Date().toISOString(),
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: `Reminder from ${senderName || 'Your Partner'}`,
              body: reminderText,
            },
            sound: 'default',
            category: 'REMINDER_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent message:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending reminder:', error);

    // Return appropriate error
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send reminder: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send pairing confirmation
 * Called when one device scans another's QR code
 */
exports.sendPairingConfirmation = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, myName, myPushToken } = request.data;

    console.log('📱 Received pairing confirmation request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   myName:', myName || 'NOT_PROVIDED');
    console.log('   myPushToken:', myPushToken ? 'EXISTS' : 'MISSING');

    // Validate required fields
    if (!partnerToken) {
      console.error('❌ partnerToken is missing or empty');
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!myPushToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'My push token is required'
      );
    }

    console.log(`Sending pairing confirmation to ${partnerToken}:`, {
      myName,
      myPushToken,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: `${myName || 'Your Partner'} wants to pair!`,
        body: 'Tap to complete pairing',
      },
      data: {
        type: 'pairing',
        partnerName: myName || 'Partner',
        partnerToken: myPushToken,
      },
      // Android-specific configuration
      android: {
        priority: 'high',
        notification: {
          channelId: 'reminder_channel',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: `${myName || 'Your Partner'} wants to pair!`,
              body: 'Tap to complete pairing',
            },
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent pairing confirmation:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending pairing confirmation:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send pairing confirmation: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send poke notifications
 * Instant "thinking of you" signal
 */
exports.sendPoke = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, pokeId, emoji } = request.data;

    console.log('💫 Received poke request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   pokeId:', pokeId || 'NOT_PROVIDED');
    console.log('   emoji:', emoji || 'NOT_PROVIDED');

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!pokeId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Poke ID is required'
      );
    }

    const pokeEmoji = emoji || '💫';
    const title = `${pokeEmoji} ${senderName || 'Your Partner'} poked you!`;
    const body = 'Tap to respond';

    console.log(`Sending poke to ${partnerToken}:`, {
      senderName,
      pokeId,
      emoji: pokeEmoji,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        pokeId: pokeId,
        fromName: senderName || 'Your Partner',
        type: 'poke',
        emoji: pokeEmoji,
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'poke_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'POKE_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent poke:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending poke:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send poke: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send quiz invite notifications
 * Called when one partner starts a quiz
 */
exports.sendQuizInvite = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, sessionId } = request.data;

    console.log('🧩 Received quiz invite request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   sessionId:', sessionId || 'NOT_PROVIDED');

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!sessionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Session ID is required'
      );
    }

    const title = `🧩 ${senderName || 'Your Partner'} started a quiz!`;
    const body = 'Take the quiz and see how well you match';

    console.log(`Sending quiz invite to ${partnerToken}:`, {
      senderName,
      sessionId,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        sessionId: sessionId,
        fromName: senderName || 'Your Partner',
        type: 'quiz_invite',
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'QUIZ_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent quiz invite:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending quiz invite:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send quiz invite: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send quiz reminder notifications
 * Called when one partner has answered but the other hasn't
 */
exports.sendQuizReminder = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, sessionId } = request.data;

    console.log('⏰ Received quiz reminder request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   sessionId:', sessionId || 'NOT_PROVIDED');

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!sessionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Session ID is required'
      );
    }

    const title = `⏰ Quiz reminder`;
    const body = `${senderName || 'Your partner'} is waiting for you to complete the quiz!`;

    console.log(`Sending quiz reminder to ${partnerToken}:`, {
      senderName,
      sessionId,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        sessionId: sessionId,
        fromName: senderName || 'Your Partner',
        type: 'quiz_reminder',
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'QUIZ_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent quiz reminder:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending quiz reminder:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send quiz reminder: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send quiz completion notifications
 * Called when both partners have answered
 */
exports.sendQuizCompleted = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, sessionId, matchPercentage, lpEarned } = request.data;

    console.log('🎉 Received quiz completion request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   sessionId:', sessionId || 'NOT_PROVIDED');
    console.log('   matchPercentage:', matchPercentage);
    console.log('   lpEarned:', lpEarned);

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!sessionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Session ID is required'
      );
    }

    const emoji = matchPercentage >= 80 ? '🎯' : matchPercentage >= 60 ? '👏' : '😊';
    const title = `${emoji} Quiz results are in!`;
    const body = `You matched ${matchPercentage}% with ${senderName || 'your partner'} • +${lpEarned} LP earned`;

    console.log(`Sending quiz completion to ${partnerToken}:`, {
      senderName,
      sessionId,
      matchPercentage,
      lpEarned,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        sessionId: sessionId,
        fromName: senderName || 'Your Partner',
        type: 'quiz_completed',
        matchPercentage: String(matchPercentage),
        lpEarned: String(lpEarned),
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'QUIZ_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent quiz completion:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending quiz completion:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send quiz completion: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send Word Ladder notifications
 * Supports: ladder_created, ladder_move, ladder_yielded, ladder_completed
 */
exports.sendWordLadderNotification = functions.https.onCall(async (request) => {
  try {
    const {
      partnerToken,
      senderName,
      sessionId,
      notificationType,
      currentWord,
      startWord,
      endWord,
      lpEarned
    } = request.data;

    console.log('🪜 Received Word Ladder notification request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   sessionId:', sessionId || 'NOT_PROVIDED');
    console.log('   notificationType:', notificationType);

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!sessionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Session ID is required'
      );
    }

    if (!notificationType) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Notification type is required'
      );
    }

    // Build notification based on type
    let title, body;

    switch (notificationType) {
      case 'ladder_created':
        title = '🪜 New Word Ladder!';
        body = `Transform ${startWord} → ${endWord}`;
        break;

      case 'ladder_move':
        title = '🪜 Your turn!';
        body = `Current word: ${currentWord}`;
        break;

      case 'ladder_yielded':
        title = '🆘 Partner needs help!';
        body = `They're stuck on: ${currentWord}`;
        break;

      case 'ladder_completed':
        title = '🎉 Ladder completed!';
        body = `You both earned ${lpEarned} LP!`;
        break;

      default:
        throw new functions.https.HttpsError(
          'invalid-argument',
          `Unknown notification type: ${notificationType}`
        );
    }

    console.log(`Sending Word Ladder notification to ${partnerToken}:`, {
      type: notificationType,
      title,
      body,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        sessionId: sessionId,
        fromName: senderName || 'Your Partner',
        type: 'word_ladder',
        ladderType: notificationType,
        currentWord: currentWord || '',
        startWord: startWord || '',
        endWord: endWord || '',
        lpEarned: lpEarned ? String(lpEarned) : '0',
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'WORD_LADDER_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent Word Ladder notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending Word Ladder notification:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send Word Ladder notification: ${error.message}`
    );
  }
});

/**
 * Cloud Function to sync Memory Flip game state
 * Validates flip allowance, updates puzzle state, and notifies partner
 */
exports.syncMemoryFlip = functions.https.onCall(async (request) => {
  try {
    const { puzzleId, cardIds, userId, action, partnerToken, senderName } = request.data;

    console.log('🃏 Received Memory Flip sync request');
    console.log('   puzzleId:', puzzleId || 'MISSING');
    console.log('   cardIds:', cardIds || 'MISSING');
    console.log('   userId:', userId || 'MISSING');
    console.log('   action:', action || 'MISSING');

    // Validate required fields
    if (!puzzleId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Puzzle ID is required'
      );
    }

    if (!cardIds || !Array.isArray(cardIds) || cardIds.length !== 2) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Exactly 2 card IDs are required'
      );
    }

    if (!userId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'User ID is required'
      );
    }

    if (!action || !['flip', 'match'].includes(action)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Action must be "flip" or "match"'
      );
    }

    // Get or create puzzle document in Firestore
    const db = admin.firestore();
    const puzzleRef = db.collection('memory_puzzles').doc(puzzleId);
    const puzzleDoc = await puzzleRef.get();

    let puzzleData;
    if (!puzzleDoc.exists) {
      // First time syncing this puzzle - create document
      puzzleData = {
        puzzleId: puzzleId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdatedBy: userId,
        flips: [],
        matches: [],
      };
      await puzzleRef.set(puzzleData);
    } else {
      puzzleData = puzzleDoc.data();
    }

    // Record this flip/match
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    if (action === 'flip') {
      // Record the flip
      await puzzleRef.update({
        flips: admin.firestore.FieldValue.arrayUnion({
          userId: userId,
          cardIds: cardIds,
          timestamp: new Date().toISOString(),
        }),
        lastUpdatedAt: timestamp,
        lastUpdatedBy: userId,
      });
    } else if (action === 'match') {
      // Record the match
      await puzzleRef.update({
        matches: admin.firestore.FieldValue.arrayUnion({
          userId: userId,
          cardIds: cardIds,
          timestamp: new Date().toISOString(),
        }),
        lastUpdatedAt: timestamp,
        lastUpdatedBy: userId,
      });
    }

    console.log(`✅ Synced ${action} for puzzle ${puzzleId}`);

    return {
      success: true,
      puzzleId: puzzleId,
      action: action,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error syncing Memory Flip:', error);

    throw new functions.https.HttpsError(
      'internal',
      `Failed to sync Memory Flip: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send Memory Flip match notification
 * Notifies partner when a match is found
 */
exports.sendMemoryFlipMatchNotification = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, emoji, quote, lovePoints } = request.data;

    console.log('🃏 Received Memory Flip match notification request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   emoji:', emoji || 'NOT_PROVIDED');

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!emoji) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Emoji is required'
      );
    }

    const title = `Match Found! ${emoji}`;
    const body = `${senderName || 'Your partner'} found a matching pair`;

    console.log(`Sending Memory Flip match notification to ${partnerToken}:`, {
      senderName,
      emoji,
      quote,
      lovePoints,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        fromName: senderName || 'Your Partner',
        type: 'memory_flip_match',
        emoji: emoji,
        quote: quote || '',
        lovePoints: lovePoints ? String(lovePoints) : '0',
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'MEMORY_FLIP_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent Memory Flip match notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending Memory Flip match notification:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send Memory Flip match notification: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send Memory Flip completion notification
 * Notifies partner when puzzle is completed
 */
exports.sendMemoryFlipCompletionNotification = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, completionQuote, lovePoints, daysTaken } = request.data;

    console.log('🎉 Received Memory Flip completion notification request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   lovePoints:', lovePoints || 'NOT_PROVIDED');

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    const title = '🎉 Puzzle Complete!';
    const body = `You and ${senderName || 'your partner'} matched all pairs!`;

    console.log(`Sending Memory Flip completion notification to ${partnerToken}:`, {
      senderName,
      completionQuote,
      lovePoints,
      daysTaken,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        fromName: senderName || 'Your Partner',
        type: 'memory_flip_completion',
        completionQuote: completionQuote || '',
        lovePoints: lovePoints ? String(lovePoints) : '0',
        daysTaken: daysTaken ? String(daysTaken) : '0',
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'MEMORY_FLIP_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent Memory Flip completion notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending Memory Flip completion notification:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send Memory Flip completion notification: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send Memory Flip new puzzle notification
 * Notifies partner when a new puzzle is started/available
 */
exports.sendMemoryFlipNewPuzzleNotification = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, totalPairs, expiresInDays } = request.data;

    console.log('🎮 Received Memory Flip new puzzle notification request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   totalPairs:', totalPairs || 'NOT_PROVIDED');

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner token is required'
      );
    }

    const title = '🎴 New Memory Puzzle!';
    const body = `${senderName || 'Your partner'} started a new puzzle. ${totalPairs || 8} pairs to find!`;

    console.log(`Sending Memory Flip new puzzle notification to ${partnerToken}:`, {
      senderName,
      totalPairs,
      expiresInDays,
    });

    const message = {
      token: partnerToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        fromName: senderName || 'Your Partner',
        type: 'memory_flip_new_puzzle',
        totalPairs: totalPairs ? String(totalPairs) : '8',
        expiresInDays: expiresInDays ? String(expiresInDays) : '7',
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            category: 'MEMORY_FLIP_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(message);

    console.log('Successfully sent Memory Flip new puzzle notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending Memory Flip new puzzle notification:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send Memory Flip new puzzle notification: ${error.message}`
    );
  }
});

/**
 * Cloud Function to create a pairing code for remote pairing
 * Generates a 6-character code (A-Z, 2-9, no ambiguous chars) with 10-minute TTL
 */
exports.createPairingCode = functions.https.onCall(async (request) => {
  try {
    const { userId, pushToken, name, avatarEmoji } = request.data;

    console.log('🔑 Received pairing code creation request');
    console.log('   userId:', userId || 'MISSING');
    console.log('   pushToken:', pushToken ? 'EXISTS' : 'MISSING');
    console.log('   name:', name || 'NOT_PROVIDED');

    // Validate required fields
    if (!userId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'User ID is required'
      );
    }

    if (!pushToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Push token is required'
      );
    }

    // Generate random 6-char code (no ambiguous characters: 0/O, 1/I)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    const createdAt = Date.now();
    const expiresAt = createdAt + (10 * 60 * 1000); // 10 minutes

    // Store in RTDB
    const db = admin.database();
    await db.ref(`pairing_codes/${code}`).set({
      userId,
      pushToken,
      name: name || 'Your Partner',
      avatarEmoji: avatarEmoji || '💕',
      createdAt,
      expiresAt,
    });

    console.log(`✅ Created pairing code: ${code} for user: ${userId}`);

    return {
      code,
      expiresAt,
    };

  } catch (error) {
    console.error('Error creating pairing code:', error);

    throw new functions.https.HttpsError(
      'internal',
      `Failed to create pairing code: ${error.message}`
    );
  }
});

/**
 * Cloud Function to retrieve pairing code data for remote pairing
 * Validates code exists, not expired, and deletes after retrieval (one-time use)
 */
exports.getPairingCode = functions.https.onCall(async (request) => {
  try {
    const { code } = request.data;

    console.log('🔓 Received pairing code retrieval request');
    console.log('   code:', code || 'MISSING');

    // Validate code format
    if (!code || code.length !== 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Code must be 6 characters'
      );
    }

    const db = admin.database();
    const codeRef = db.ref(`pairing_codes/${code.toUpperCase()}`);
    const snapshot = await codeRef.once('value');

    if (!snapshot.exists()) {
      throw new functions.https.HttpsError(
        'not-found',
        'Code not found or expired'
      );
    }

    const data = snapshot.val();

    // Check expiration
    if (Date.now() > data.expiresAt) {
      await codeRef.remove();
      console.log(`⏱️ Pairing code ${code} expired and deleted`);
      throw new functions.https.HttpsError(
        'deadline-exceeded',
        'Code expired'
      );
    }

    // Delete code after successful retrieval (one-time use)
    await codeRef.remove();

    console.log(`✅ Retrieved pairing code: ${code} for user: ${data.userId}`);

    return {
      userId: data.userId,
      pushToken: data.pushToken,
      name: data.name,
      avatarEmoji: data.avatarEmoji,
      createdAt: data.createdAt,
    };

  } catch (error) {
    console.error('Error retrieving pairing code:', error);

    // Re-throw HttpsErrors as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to retrieve pairing code: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send Daily Pulse answer notification
 * Notifies partner when user answers Daily Pulse
 */
exports.sendDailyPulseAnswer = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, isSubject, pulseId } = request.data;

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!pulseId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Pulse ID is required'
      );
    }

    // Determine notification message based on role
    const message = isSubject
      ? `${senderName || 'Your partner'} answered today's Daily Pulse! Can you guess their answer?`
      : `${senderName || 'Your partner'} made a prediction! See if they know you well.`;

    console.log(`Sending Daily Pulse answer notification to ${partnerToken}:`, {
      senderName,
      isSubject,
      pulseId,
    });

    const notificationMessage = {
      token: partnerToken,
      notification: {
        title: '💭 Daily Pulse',
        body: message,
      },
      data: {
        type: 'daily_pulse_answer',
        pulseId: pulseId,
        fromName: senderName || 'Your Partner',
        isSubject: isSubject.toString(),
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'daily_pulse_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: '💭 Daily Pulse',
              body: message,
            },
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(notificationMessage);

    console.log('Successfully sent Daily Pulse answer notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending Daily Pulse answer notification:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send notification: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send Daily Pulse completion notification
 * Notifies both users when Daily Pulse is completed with results
 */
exports.sendDailyPulseCompletion = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, isMatch, lpEarned, currentStreak } = request.data;

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    // Create result message
    const matchEmoji = isMatch ? '✅' : '❌';
    const matchText = isMatch ? 'matched' : 'didn\'t match';
    const streakText = currentStreak > 0 ? ` 🔥 ${currentStreak} day streak!` : '';
    const message = `${matchEmoji} You ${matchText}! +${lpEarned} LP earned.${streakText}`;

    console.log(`Sending Daily Pulse completion notification to ${partnerToken}:`, {
      senderName,
      isMatch,
      lpEarned,
      currentStreak,
    });

    const notificationMessage = {
      token: partnerToken,
      notification: {
        title: '💭 Daily Pulse Complete!',
        body: message,
      },
      data: {
        type: 'daily_pulse_completion',
        isMatch: isMatch.toString(),
        lpEarned: lpEarned.toString(),
        currentStreak: currentStreak.toString(),
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'daily_pulse_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: '💭 Daily Pulse Complete!',
              body: message,
            },
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(notificationMessage);

    console.log('Successfully sent Daily Pulse completion notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending Daily Pulse completion notification:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send notification: ${error.message}`
    );
  }
});

/**
 * Cloud Function to send Daily Pulse streak milestone notification
 * Celebrates reaching 7, 14, or 30 day streaks
 */
exports.sendDailyPulseStreakMilestone = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, streak, bonusLP, milestoneText } = request.data;

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!streak || !bonusLP || !milestoneText) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Streak milestone details are required'
      );
    }

    console.log(`Sending Daily Pulse streak milestone notification to ${partnerToken}:`, {
      senderName,
      streak,
      bonusLP,
    });

    const notificationMessage = {
      token: partnerToken,
      notification: {
        title: `🔥 ${streak} Day Streak Milestone!`,
        body: milestoneText,
      },
      data: {
        type: 'daily_pulse_milestone',
        streak: streak.toString(),
        bonusLP: bonusLP.toString(),
      },
      // Android-specific configuration
      android: {
        notification: {
          channelId: 'daily_pulse_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: `🔥 ${streak} Day Streak Milestone!`,
              body: milestoneText,
            },
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
    };

    // Send the notification via FCM
    const response = await admin.messaging().send(notificationMessage);

    console.log('Successfully sent Daily Pulse streak milestone notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error sending Daily Pulse streak milestone notification:', error);

    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid or expired push token'
      );
    }

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send notification: ${error.message}`
    );
  }
});

/**
 * Cloud Function to schedule a reminder for future delivery
 * Uses Cloud Tasks to delay the notification until the scheduled time
 */
exports.scheduleReminder = functions.https.onCall(async (request) => {
  try {
    const { partnerToken, senderName, reminderText, reminderId, scheduledFor } = request.data;

    console.log('⏰ Received schedule reminder request');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   reminderId:', reminderId || 'NOT_PROVIDED');
    console.log('   scheduledFor:', scheduledFor || 'NOT_PROVIDED');

    // Validate required fields
    if (!partnerToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Partner push token is required'
      );
    }

    if (!reminderText) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Reminder text is required'
      );
    }

    if (!reminderId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Reminder ID is required'
      );
    }

    // Parse scheduled time (expecting UTC ISO8601 string)
    const scheduledDate = new Date(scheduledFor);
    const now = new Date();
    const delayMs = scheduledDate.getTime() - now.getTime();

    console.log('   Scheduled for:', scheduledDate.toISOString());
    console.log('   Current time:', now.toISOString());
    console.log('   Delay (ms):', delayMs);

    // If scheduled for now or within 1 minute, send immediately
    if (delayMs <= 60000) {
      console.log('📤 Sending reminder immediately (delay <= 1 minute)');
      return await sendReminderImmediately(partnerToken, senderName, reminderText, reminderId);
    }

    // Create Cloud Task for future delivery
    console.log('📅 Creating Cloud Task for scheduled delivery');

    const parent = tasksClient.queuePath(PROJECT_ID, LOCATION, QUEUE_NAME);

    // Get the Cloud Function URL for the HTTP trigger
    const url = `https://${LOCATION}-${PROJECT_ID}.cloudfunctions.net/sendScheduledReminderNotification`;

    const task = {
      httpRequest: {
        httpMethod: 'POST',
        url: url,
        body: Buffer.from(JSON.stringify({
          partnerToken,
          senderName,
          reminderText,
          reminderId,
        })).toString('base64'),
        headers: {
          'Content-Type': 'application/json',
        },
      },
      scheduleTime: {
        seconds: Math.floor(scheduledDate.getTime() / 1000),
      },
    };

    const [response] = await tasksClient.createTask({ parent, task });

    console.log('✅ Cloud Task created:', response.name);

    return {
      success: true,
      scheduled: true,
      taskName: response.name,
      scheduledFor: scheduledFor,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error scheduling reminder:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to schedule reminder: ${error.message}`
    );
  }
});

/**
 * Helper function to send a reminder notification immediately
 */
async function sendReminderImmediately(partnerToken, senderName, reminderText, reminderId) {
  const message = {
    token: partnerToken,
    notification: {
      title: `Reminder from ${senderName || 'Your Partner'}`,
      body: reminderText,
    },
    data: {
      reminderId: reminderId,
      fromName: senderName || 'Your Partner',
      type: 'reminder',
      text: reminderText,
    },
    android: {
      notification: {
        channelId: 'reminder_channel',
        priority: 'high',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: `Reminder from ${senderName || 'Your Partner'}`,
            body: reminderText,
          },
          sound: 'default',
          category: 'REMINDER_CATEGORY',
          contentAvailable: true,
        },
      },
    },
  };

  const response = await admin.messaging().send(message);
  console.log('✅ Reminder sent immediately:', response);

  return {
    success: true,
    scheduled: false,
    messageId: response,
    timestamp: new Date().toISOString(),
  };
}

/**
 * HTTP endpoint called by Cloud Tasks to send the scheduled notification
 * This is triggered at the scheduled time by Cloud Tasks
 */
exports.sendScheduledReminderNotification = functions.https.onRequest(async (req, res) => {
  try {
    // Parse the request body (base64 encoded from Cloud Tasks)
    let body = req.body;
    if (typeof body === 'string') {
      body = JSON.parse(Buffer.from(body, 'base64').toString());
    }

    const { partnerToken, senderName, reminderText, reminderId } = body;

    console.log('⏰ Executing scheduled reminder');
    console.log('   partnerToken:', partnerToken ? 'EXISTS' : 'MISSING');
    console.log('   senderName:', senderName || 'NOT_PROVIDED');
    console.log('   reminderId:', reminderId || 'NOT_PROVIDED');

    if (!partnerToken || !reminderText || !reminderId) {
      console.error('Missing required fields');
      res.status(400).send({ error: 'Missing required fields' });
      return;
    }

    const message = {
      token: partnerToken,
      notification: {
        title: `Reminder from ${senderName || 'Your Partner'}`,
        body: reminderText,
      },
      data: {
        reminderId: reminderId,
        fromName: senderName || 'Your Partner',
        type: 'reminder',
        text: reminderText,
      },
      android: {
        notification: {
          channelId: 'reminder_channel',
          priority: 'high',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: `Reminder from ${senderName || 'Your Partner'}`,
              body: reminderText,
            },
            sound: 'default',
            category: 'REMINDER_CATEGORY',
            contentAvailable: true,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Scheduled reminder sent:', response);

    res.status(200).send({
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Error sending scheduled reminder:', error);

    // Return 200 even on FCM errors to prevent Cloud Tasks retry loops
    // for invalid tokens (the user may have uninstalled the app)
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      console.log('⚠️ Invalid token - not retrying');
      res.status(200).send({ error: 'Invalid token', skipped: true });
      return;
    }

    res.status(500).send({ error: error.message });
  }
});
