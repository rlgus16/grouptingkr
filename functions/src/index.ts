import * as admin from "firebase-admin";
// Import v2 triggers explicitly
import { onDocumentUpdated, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();

const db = admin.firestore();

interface GroupData {
  id: string;
  memberIds: string[];
  status: string;
  // 필터 관련 필드 정의
  preferredGender?: string;
  minAge?: number;
  maxAge?: number;
  averageAge?: number;
  groupGender?: string;
  minHeight?: number;
  maxHeight?: number;
  averageHeight?: number;
  matchedGroupId?: string;
}

// 1. [MATCHING LOGIC]
// Finds a match and updates statuses safely. No notifications are sent here.
export const handleGroupUpdate = onDocumentUpdated("groups/{groupId}", async (event) => {
    if (!event.data) return;

    const beforeData = event.data.before.data() as GroupData;
    const afterData = event.data.after.data() as GroupData;
    const groupId = event.params.groupId;

    if (!beforeData || !afterData) return;

    // 매칭 상태로 변경되었을 때만 로직 수행
    if (beforeData.status !== "matching" && afterData.status === "matching") {
      console.log(`Group ${groupId} started matching with filters.`);

      // 1. 현재 그룹의 정보 및 필터 가져오기
      const myGender = afterData.groupGender || "혼성";
      const myPrefGender = afterData.preferredGender || "상관없음";
      const myAvgAge = afterData.averageAge || 0;
      const myMinAge = afterData.minAge || 0;
      const myMaxAge = afterData.maxAge || 100;
      const myAvgHeight = afterData.averageHeight || 0;
      const myMinHeight = afterData.minHeight || 0;
      const myMaxHeight = afterData.maxHeight || 200;

      // 2. 매칭 중인 다른 그룹들 조회
      const matchingGroupsQuery = db.collection("groups")
        .where("status", "==", "matching")
        .where(admin.firestore.FieldPath.documentId(), "!=", groupId);

      const querySnapshot = await matchingGroupsQuery.get();

      if (querySnapshot.empty) {
        console.log("No other groups are currently matching.");
        return;
      }

      // 3. 조건에 맞는 그룹 찾기
      let matchedCandidate: GroupData | null = null;

      for (const doc of querySnapshot.docs) {
          const targetData = doc.data() as GroupData;

          // [기본 조건] 멤버 수가 같아야 함
          if (targetData.memberIds.length !== afterData.memberIds.length) continue;

          // ---------------------------------------------------------
          // [필터 조건 1] 성별 매칭 (양방향 확인)
          // ---------------------------------------------------------
          const targetGender = targetData.groupGender || "혼성";
          const targetPrefGender = targetData.preferredGender || "상관없음";

          // 내가 원하는 상대 성별 확인
          const isTargetGenderValid = (myPrefGender === "상관없음") || (myPrefGender === targetGender);
          // 상대가 원하는 내 성별 확인
          const isMyGenderValid = (targetPrefGender === "상관없음") || (targetPrefGender === myGender);

          if (!isTargetGenderValid || !isMyGenderValid) continue;

          // ---------------------------------------------------------
          // [필터 조건 2] 나이 매칭 (평균 나이 기준, 양방향 확인)
          // ---------------------------------------------------------
          const targetAvgAge = targetData.averageAge || 0;
          const targetMinAge = targetData.minAge || 0;
          const targetMaxAge = targetData.maxAge || 100;

          // 상대방의 평균 나이가 내 선호 범위 안에 있는지
          const isTargetAgeValid = (targetAvgAge >= myMinAge) && (targetAvgAge <= myMaxAge);
          // 내 평균 나이가 상대방의 선호 범위 안에 있는지
          const isMyAgeValid = (myAvgAge >= targetMinAge) && (myAvgAge <= targetMaxAge);

          if (!isTargetAgeValid || !isMyAgeValid) continue;

          const targetAvgHeight = targetData.averageHeight || 0;
          const targetMinHeight = targetData.minHeight || 0;
          const targetMaxHeight = targetData.maxHeight || 200;

          // 1. 상대방의 평균 키가 내 선호 범위 안에 있는지 확인
          const isTargetHeightValid = (targetAvgHeight >= myMinHeight) && (targetAvgHeight <= myMaxHeight);

          // 2. 내 평균 키가 상대방의 선호 범위 안에 있는지 확인
          const isMyHeightValid = (myAvgHeight >= targetMinHeight) && (myAvgHeight <= targetMaxHeight);

          if (!isTargetHeightValid || !isMyHeightValid) continue;

          // [수정됨] 모든 조건을 만족하면 매칭 대상으로 선정 (순서 변경)
          matchedCandidate = { ...targetData, id: doc.id } as GroupData;
          break;
      }

      // 4. 매칭 성사 처리 (기존 로직과 동일)
      if (matchedCandidate) {
        console.log(`Matched! ${groupId} (${myGender}, avg:${myAvgAge}) <-> ${matchedCandidate.id} (${matchedCandidate.groupGender}, avg:${matchedCandidate.averageAge})`);

        const group1Ref = db.collection("groups").doc(groupId);
        const group2Ref = db.collection("groups").doc(matchedCandidate.id);

        try {
          await db.runTransaction(async (transaction) => {
            const group1Doc = await transaction.get(group1Ref);
            const group2Doc = await transaction.get(group2Ref);

            if (!group1Doc.exists || !group2Doc.exists) throw "Group missing";
            if (group1Doc.data()?.status !== "matching" || group2Doc.data()?.status !== "matching") {
                throw "Status changed";
            }

            transaction.update(group1Ref, {
                status: "matched",
                matchedGroupId: matchedCandidate!.id
            });
            transaction.update(group2Ref, {
               status: "matched",
               matchedGroupId: groupId
            });
          });
        } catch (e) {
          console.log(`Transaction failed: ${e}`);
        }
      }
    }
});

// 2. [CHATROOM CREATION]
// Creates the chatroom document. No notifications are sent here.
export const handleMatchingCompletion = onDocumentUpdated("groups/{groupId}", async (event) => {
    if (!event.data) return;

    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const groupId = event.params.groupId;

    if (!beforeData || !afterData) return;

    if (beforeData.status !== "matched" && afterData.status === "matched") {
      const matchedGroupId = afterData.matchedGroupId;
      if (!matchedGroupId) return;

      // Only the group with the "lexicographically higher" ID runs this logic
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
// Triggers ONLY when the chatroom is created.
export const notifyMatchOnChatroomCreate = onDocumentCreated("chatrooms/{chatroomId}", async (event) => {
    // In v2, snapshot is event.data
    const snapshot = event.data;
    if (!snapshot) return;

    const chatroomData = snapshot.data();
    const chatRoomId = event.params.chatroomId;
    const participantIds = chatroomData?.participants || [];

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
      if (userData.matchingNotification === false) return;
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

// 4. [INVITATION NOTIFICATION]
// Triggers when a new invitation is created
export const notifyInvitation = onDocumentCreated("invitations/{invitationId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const invitationData = snapshot.data();
    const invitationId = event.params.invitationId;
    const toUserId = invitationData?.toUserId;
    const fromUserNickname = invitationData?.fromUserNickname;

    if (!toUserId) {
      console.log("No toUserId in invitation.");
      return;
    }

    console.log(`Sending invitation notification to user: ${toUserId}`);

    // Get the recipient's FCM token
    const userDoc = await db.collection("users").doc(toUserId).get();
    if (!userDoc.exists) {
      console.log(`User ${toUserId} not found.`);
      return;
    }

    const userData = userDoc.data();
    // 사용자가 초대 알림을 껐는지 확인 (invitationNotification이 false면 중단)
        const isNotificationEnabled = userData?.invitationNotification !== false;

        if (!isNotificationEnabled) {
            console.log(`User ${toUserId} has disabled invitation notifications.`);
            return;
        }
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${toUserId}.`);
      return;
    }

    // Construct the notification payload
    const message = {
      token: fcmToken,
      notification: {
        title: "그룹팅",
        body: `${fromUserNickname}님이 그룹에 초대했습니다.`,
      },
      data: {
        type: "new_invitation",
        invitationId: invitationId,
        fromUserNickname: fromUserNickname,
        fromUserProfileImage: invitationData?.fromUserProfileImage || "",
        showAsLocalNotification: "true",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Invitation notification sent to ${toUserId}`);
    } catch (error) {
      console.error("Error sending invitation notification:", error);
    }
  });

// 가입시 닉네임 중복 확인
// v2 Callables receive a 'request' object. 'data' is a property of 'request'.
export const checkNickname = onCall(async (request) => {
  // Use request.data to get the client-sent data
  const data = request.data;
  const nickname = data.nickname;

  if (!nickname || typeof nickname !== 'string') {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with one argument 'nickname'."
    );
  }

  const trimmedNickname = nickname.trim();

  try {
    // 1. Check 'users' collection (real profiles)
    const usersQuery = await db.collection("users")
      .where("nickname", "==", trimmedNickname)
      .limit(1)
      .get();

    if (!usersQuery.empty) {
      return { isDuplicate: true };
    }

    // 2. Check 'nicknames' collection (reserved/temp names)
    const normalizedNickname = trimmedNickname.toLowerCase();
    const reservedDoc = await db.collection("nicknames").doc(normalizedNickname).get();

    if (reservedDoc.exists) {
      return { isDuplicate: true };
    }

    return { isDuplicate: false };

  } catch (error) {
    console.error("Error checking nickname:", error);
    throw new HttpsError("internal", "Error checking nickname availability.");
  }
});

// 이메일 중복 확인
export const checkEmail = onCall(async (request) => {
  const data = request.data;
  const email = data.email;

  if (!email || typeof email !== 'string') {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with one argument 'email'."
    );
  }

  const normalizedEmail = email.trim().toLowerCase();

  try {
    // 1. Check Firebase Auth (Source of Truth)
    try {
      await admin.auth().getUserByEmail(normalizedEmail);
      return { isDuplicate: true };
    } catch (authError: any) {
      if (authError.code !== 'auth/user-not-found') {
        throw authError;
      }
    }

    // 2. Check 'users' collection (Just in case of data mismatch)
    const usersQuery = await db.collection("users")
      .where("email", "==", normalizedEmail)
      .limit(1)
      .get();

    if (!usersQuery.empty) {
      return { isDuplicate: true };
    }

    return { isDuplicate: false };

  } catch (error) {
    console.error("Error checking email:", error);
    throw new HttpsError("internal", "Error checking email availability.");
  }
});

// 전화번호 중복 확인
export const checkPhoneNumber = onCall(async (request) => {
  const data = request.data;
  const phoneNumber = data.phoneNumber;

  if (!phoneNumber || typeof phoneNumber !== 'string') {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with one argument 'phoneNumber'."
    );
  }

  const cleanPhoneNumber = phoneNumber.trim();

  try {
    const usersQuery = await db.collection("users")
      .where("phoneNumber", "==", cleanPhoneNumber)
      .limit(1)
      .get();

    if (!usersQuery.empty) {
      return { isDuplicate: true };
    }

    return { isDuplicate: false };

  } catch (error) {
    console.error("Error checking phone number:", error);
    throw new HttpsError("internal", "Error checking phone number availability.");
  }
});

// [관리자 기능] 사용자 제재 (계정 정지 및 강제 차단)
export const banUserByAdmin = onCall(async (request) => {
  // 1. 관리자 권한 확인 (보안을 위해 특정 이메일만 허용하는 로직 권장)
  // const requesterEmail = request.auth?.token.email;
  // if (requesterEmail !== 'admin@groupting.com') {
  //   throw new HttpsError("permission-denied", "관리자만 수행할 수 있습니다.");
  // }

  const data = request.data;
  const targetUserId = data.targetUserId; // 제재할 사용자 UID
  const reportId = data.reportId;         // 처리할 신고 ID (선택사항)

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }

  try {
    // 2. Firebase Auth 계정 비활성화 (로그인 차단)
    await admin.auth().updateUser(targetUserId, { disabled: true });

    // 3. Firestore 사용자 문서에 'banned' 플래그 설정 (데이터 접근 차단용)
    // users 컬렉션에 status 필드를 업데이트합니다.
    await db.collection("users").doc(targetUserId).update({
      status: 'banned',
      bannedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 4. 신고 처리 상태 업데이트 (처리 완료)
    if (reportId) {
      await db.collection("reports").doc(reportId).update({
        status: 'resolved',
        actionTaken: 'banned',
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // 5. (선택사항) 해당 유저의 모든 인증 토큰 만료 처리 (즉시 로그아웃 효과)
    await admin.auth().revokeRefreshTokens(targetUserId);

    console.log(`User ${targetUserId} has been banned by admin.`);
    return { success: true, message: `User ${targetUserId} banned successfully.` };

  } catch (error) {
    console.error("Error banning user:", error);
    throw new HttpsError("internal", "Failed to ban user.");
  }
});

// 채팅방에 새로운 메시지가 추가되었을 때 알림 전송
export const notifyNewMessage = onDocumentUpdated("chatrooms/{chatroomId}", async (event) => {
    if (!event.data) return;

    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const chatRoomId = event.params.chatroomId;

    // lastMessage 필드가 변경되었는지 확인
    const beforeLastMsg = beforeData?.lastMessage;
    const afterLastMsg = afterData?.lastMessage;

    // 메시지가 없거나, 이전 메시지와 ID가 같다면(메시지 변경이 아님) 무시
    if (!afterLastMsg || (beforeLastMsg && beforeLastMsg.id === afterLastMsg.id)) {
        return;
    }

    const newMessage = afterLastMsg;
    const senderId = newMessage.senderId;
    const senderNickname = newMessage.senderNickname;
    const content = newMessage.type === 'image' ? '(사진)' : newMessage.content; // 이미지인 경우 텍스트 처리
    const participants = afterData.participants || [];

    // 보낸 사람(senderId)을 제외한 나머지 참가자들에게만 알림 전송
    const recipientIds = participants.filter((uid: string) => uid !== senderId);

    if (recipientIds.length === 0) return;

    console.log(`Sending message notification from ${senderId} to ${recipientIds} in ${chatRoomId}`);

    // 수신자들의 FCM 토큰 조회
    // (참가자가 많을 경우 chunk로 나누는 로직이 필요할 수 있으나, 현재 최대 5vs5 소규모 그룹이므로 in 쿼리 사용 가능)
    // Firestore 'in' 쿼리는 최대 10개까지만 가능하므로 주의 (현재 로직상 문제는 없어 보임)
    const usersQuery = await db.collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", recipientIds)
      .get();

    const tokens: string[] = [];
    usersQuery.forEach((doc) => {
      const userData = doc.data();
      if (userData.chatNotification === false) return;
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    });

    if (tokens.length === 0) {
      console.log("No recipient tokens found.");
      return;
    }

    // 알림 메시지 구성
    const messagePayload = {
      notification: {
        title: senderNickname, // 알림 제목에 보낸 사람 닉네임 표시
        body: content,         // 알림 내용에 메시지 내용 표시
      },
      data: {
        type: "new_message",   // 클라이언트에서 처리할 알림 타입
        chatroomId: chatRoomId,
        senderId: senderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      tokens: tokens, // 다중 전송
    };

    try {
          const response = await admin.messaging().sendEachForMulticast(messagePayload as any);
          console.log(`Message notifications sent. Success: ${response.successCount}, Failure: ${response.failureCount}`);

          // 실패한 경우 구체적인 에러 이유를 로그로 출력
          if (response.failureCount > 0) {
            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                console.error(`Error sending to token ${tokens[idx]}:`, resp.error);
              }
            });
          }

        } catch (error) {
          console.error("Error sending message notifications:", error);
        }
    });