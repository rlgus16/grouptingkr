import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

interface GroupData {
  id: string;
  memberIds: string[];
  [key: string]: any;
}

export const handleGroupUpdate = functions.firestore
  .document("groups/{groupId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const groupId = context.params.groupId;

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

      let matchedGroup: GroupData | null = null;
      for (const doc of querySnapshot.docs) {
          const groupData = doc.data();
          if (groupData.memberIds.length === afterData.memberIds.length) {
            matchedGroup = { id: doc.id, ...groupData } as GroupData;
            break;
          }
      }

      if (matchedGroup) {
        console.log(`Found a match: ${groupId} and ${matchedGroup.id}`);
        const group1Ref = db.collection("groups").doc(groupId);
        const group2Ref = db.collection("groups").doc(matchedGroup.id);

        await db.runTransaction(async (transaction) => {
          transaction.update(group1Ref, { 
              status: "matched", 
              matchedGroupId: matchedGroup!.id 
          });
          transaction.update(group2Ref, {
             status: "matched", 
             matchedGroupId: groupId 
          });
        });
      } else {
        console.log("Found other matching groups, but none were compatible.");
      }
    }
  });

export const handleMatchingCompletion = functions.firestore
  .document("groups/{groupId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const groupId = context.params.groupId;

    if (beforeData.status !== "matched" && afterData.status === "matched") {
      const matchedGroupId = afterData.matchedGroupId;
      if (!matchedGroupId) {
        console.log("Matched group ID is missing.");
        return;
      }
      
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
          console.log(`Chatroom ${newChatRoomId} already exists. Skipping creation.`);
          return;
        }

        const group1Ref = db.collection("groups").doc(groupId);
        const group2Ref = db.collection("groups").doc(matchedGroupId);
        const group1Doc = await transaction.get(group1Ref);
        const group2Doc = await transaction.get(group2Ref);

        if (!group1Doc.exists || !group2Doc.exists) {
          throw new Error("One or both groups in the match do not exist.");
        }
        
        const group1Data = group1Doc.data();
        const group2Data = group2Doc.data();
        
        if (!group1Data || !group2Data) {
            throw new Error("Group data is undefined.");
        }

        const allMemberIds = [...new Set([...group1Data.memberIds, ...group2Data.memberIds])];

        transaction.set(newChatRoomRef, {
          groupId: newChatRoomId,
          participants: allMemberIds,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        for (const memberId of allMemberIds) {
          const userRef = db.collection("users").doc(memberId);
          transaction.update(userRef, { currentGroupId: newChatRoomId });
        }
        
        transaction.delete(group1Ref);
        transaction.delete(group2Ref);
      });
    }
  });
// Other functions from your original file can be pasted below
