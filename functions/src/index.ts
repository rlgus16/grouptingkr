import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

interface GroupData {
  id: string;
  memberIds: string[];
  [key: string]: any;
}

// 1. [MATCHING LOGIC]
// Finds a match and updates statuses safely. No notifications are sent here.
export const handleGroupUpdate = functions.firestore
  .document("groups/{groupId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const groupId = context.params.groupId;

    // Trigger only when status changes to "matching"
    if (beforeData.status !== "matching" && afterData.status === "matching") {
      console.log(`Group ${groupId} started matching. Looking for a pair.`);

      const matchingGroupsQuery = db.collection("groups")
        .where("status", "==", "matching")
        .where(admin.firestore.FieldPath.documentId(), "!=", groupId);

      const querySnapshot = await matchingGroupsQuery.get();

      if (querySnapshot.empty) {
        console.log("No other groups are currently matching.");
        return;
      }

      // Logic to find a candidate with the same member count
      let matchedCandidate: GroupData | null = null;
      for (const doc of querySnapshot.docs) {
          const groupData = doc.data();
          if (groupData.memberIds.length === afterData.memberIds.length) {
            matchedCandidate = { id: doc.id, ...groupData } as GroupData;
            break;
          }
      }

      if (matchedCandidate) {
        console.log(`Attempting to match: ${groupId} and ${matchedCandidate.id}`);
        const group1Ref = db.collection("groups").doc(groupId);
        const group2Ref = db.collection("groups").doc(matchedCandidate.id);

        try {
          await db.runTransaction(async (transaction) => {
            // Read both documents INSIDE the transaction to prevent race conditions
            const group1Doc = await transaction.get(group1Ref);
            const group2Doc = await transaction.get(group2Ref);

            if (!group1Doc.exists || !group2Doc.exists) {
              throw new Error("One of the groups does not exist.");
            }

            const g1Data = group1Doc.data();
            const g2Data = group2Doc.data();

            // Validate that BOTH groups are still 'matching'
            if (g1Data?.status !== "matching") {
              throw new Error(`Self group ${groupId} is no longer matching.`);
            }
            if (g2Data?.status !== "matching") {
              throw new Error(`Target group ${matchedCandidate!.id} is no longer available.`);
            }

            // Update statuses to 'matched'
            transaction.update(group1Ref, {
                status: "matched",
                matchedGroupId: matchedCandidate!.id
            });
            transaction.update(group2Ref, {
               status: "matched",
               matchedGroupId: groupId
            });
          });
          console.log(`Successfully matched ${groupId} with ${matchedCandidate.id}`);
        } catch (e) {
          console.log(`Transaction failed (race condition handled): ${e}`);
        }
      } else {
        console.log("Found other matching groups, but none were compatible.");
      }
    }
  });

// 2. [CHATROOM CREATION]
// Creates the chatroom document. No notifications are sent here.
export const handleMatchingCompletion = functions.firestore
  .document("groups/{groupId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const groupId = context.params.groupId;

    if (beforeData.status !== "matched" && afterData.status === "matched") {
      const matchedGroupId = afterData.matchedGroupId;
      if (!matchedGroupId) return;

      // Only the group with the "lexicographically higher" ID runs this logic
      // This prevents the code from running twice (once for each group)
      if (groupId > matchedGroupId) {
          console.log(`Group ${groupId} deferring to ${matchedGroupId} to handle completion.`);
          return;
      }

      console.log(`Handling matching completion for ${groupId} and ${matchedGroupId}`);
      const newChatRoomId = `${groupId}_${matchedGroupId}`;

      await db.runTransaction(async (transaction) => {
        const newChatRoomRef = db.collection("chatrooms").doc(newChatRoomId);
        const chatRoomDoc = await transaction.get(newChatRoomRef);

        if (chatRoomDoc.exists) {
          return; // Chatroom already exists
        }

        const group1Ref = db.collection("groups").doc(groupId);
        const group2Ref = db.collection("groups").doc(matchedGroupId);
        const group1Doc = await transaction.get(group1Ref);
        const group2Doc = await transaction.get(group2Ref);

        if (!group1Doc.exists || !group2Doc.exists) {
          throw new Error("One or both groups in the match do not exist.");
        }

        const group1Data = group1Doc.data()!;
        const group2Data = group2Doc.data()!;

        const allMemberIds = [...new Set([...group1Data.memberIds, ...group2Data.memberIds])];

        // Create the Chatroom
        transaction.set(newChatRoomRef, {
          groupId: newChatRoomId,
          participants: allMemberIds,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update all users to point to the new chatroom
        for (const memberId of allMemberIds) {
          const userRef = db.collection("users").doc(memberId);
          transaction.update(userRef, { currentGroupId: newChatRoomId });
        }

        // Delete the old group documents
        transaction.delete(group1Ref);
        transaction.delete(group2Ref);
      });
    }
  });

// 3. [NOTIFICATIONS]
// Triggers ONLY when the chatroom is created. This ensures exactly ONE notification.
export const notifyMatchOnChatroomCreate = functions.firestore
  .document("chatrooms/{chatroomId}")
  .onCreate(async (snapshot, context) => {
    const chatroomData = snapshot.data();
    const chatRoomId = context.params.chatroomId;
    const participantIds = chatroomData.participants || [];

    if (participantIds.length === 0) {
      console.log("No participants in chatroom.");
      return;
    }

    console.log(`Sending match notifications to: ${participantIds}`);

    // Get tokens for all users in the chatroom
    const usersQuery = await db.collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", participantIds)
      .get();

    const tokens: string[] = [];
    usersQuery.forEach((doc) => {
      const userData = doc.data();
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    });

    if (tokens.length === 0) {
      console.log("No FCM tokens found for users.");
      return;
    }

    // Construct the notification payload
    const message = {
      notification: {
        title: "매칭 성공! 🎉",
        body: "새로운 그룹과 매칭되었습니다. 지금 채팅을 시작해보세요!",
      },
      data: {
        type: "matching_completed",
        chatRoomId: chatRoomId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      tokens: tokens,
    };

    // Send Multicast Message
    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Notifications sent. Success: ${response.successCount}, Failure: ${response.failureCount}`);
    } catch (error) {
      console.error("Error sending match notifications:", error);
    }
  });