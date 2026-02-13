import * as admin from "firebase-admin";
// Import v2 triggers explicitly
import { onDocumentUpdated, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();

// 거리 계산 헬퍼 함수 (Haversine Formula)
function getDistanceFromLatLonInKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Radius of the earth in km
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const d = R * c; // Distance in km
  return d;
}

function deg2rad(deg: number): number {
  return deg * (Math.PI / 180);
}

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
  maxDistance?: number;
  latitude?: number;
  longitude?: number;
}

// [WAITING CHATROOM CREATION]
// Creates a chatroom for the group when the group is first created
// This ensures the chatroom exists before anyone opens chat_view
export const onGroupCreated = onDocumentCreated("groups/{groupId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const groupId = event.params.groupId;
  const groupData = snapshot.data();
  const memberIds = groupData?.memberIds || [];

  console.log(`Creating waiting chatroom for new group: ${groupId}`);

  try {
    const chatroomRef = db.collection("chatrooms").doc(groupId);
    const chatroomDoc = await chatroomRef.get();

    // Only create if chatroom doesn't already exist
    if (!chatroomDoc.exists) {
      await chatroomRef.set({
        groupId: groupId,
        participants: memberIds,
        messages: [],
        messageCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Waiting chatroom created for group: ${groupId}`);
    }
  } catch (error) {
    console.error(`Error creating waiting chatroom for group ${groupId}:`, error);
  }
});

// 매칭 로직
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

    // 현재 그룹의 정보 및 필터 가져오기
    const myGender = afterData.groupGender || "혼성";
    const myPrefGender = afterData.preferredGender || "상관없음";
    const myAvgAge = afterData.averageAge || 0;
    const myMinAge = afterData.minAge || 0;
    const myMaxAge = afterData.maxAge || 100;
    const myAvgHeight = afterData.averageHeight || 0;
    const myMinHeight = afterData.minHeight || 0;
    const myMaxHeight = afterData.maxHeight || 200;
    const myLat = afterData.latitude || 0;
    const myLon = afterData.longitude || 0;
    const myMaxDist = afterData.maxDistance || 100; // 기본 100km

    // 매칭 중인 다른 그룹들 조회
    const matchingGroupsQuery = db.collection("groups")
      .where("status", "==", "matching")
      .where(admin.firestore.FieldPath.documentId(), "!=", groupId);

    const querySnapshot = await matchingGroupsQuery.get();

    if (querySnapshot.empty) {
      console.log("No other groups are currently matching.");
      return;
    }

    // ===== EXEMPTION FILTER =====
    // Query exemptions involving my group members
    const myMemberIds = afterData.memberIds;

    // 1. Users that my group members have exempted
    const exemptionsFromMeQuery = await db.collection("matchExemptions")
      .where("exempterId", "in", myMemberIds)
      .get();

    // 2. Users who have exempted my group members
    const exemptionsAgainstMeQuery = await db.collection("matchExemptions")
      .where("exemptedId", "in", myMemberIds)
      .get();

    // Build set of user IDs to avoid
    const exemptedUserIds = new Set<string>();
    exemptionsFromMeQuery.forEach(doc => exemptedUserIds.add(doc.data().exemptedId));
    exemptionsAgainstMeQuery.forEach(doc => exemptedUserIds.add(doc.data().exempterId));

    console.log(`Exempted user IDs for group ${groupId}: [${Array.from(exemptedUserIds).join(", ")}]`);
    // ===== END EXEMPTION FILTER =====

    // 조건에 맞는 그룹 찾기
    let matchedCandidate: GroupData | null = null;

    for (const doc of querySnapshot.docs) {
      const targetData = doc.data() as GroupData;

      // [기본 조건] 멤버 수가 같아야 함
      if (targetData.memberIds.length !== afterData.memberIds.length) continue;

      // [EXEMPTION CHECK] Skip groups containing exempted users
      const hasExemptedMember = targetData.memberIds.some(
        (memberId: string) => exemptedUserIds.has(memberId)
      );
      if (hasExemptedMember) {
        console.log(`Skipping group ${doc.id} - contains exempted member`);
        continue;
      }

      // [필터 조건 1] 성별 매칭 (양방향 확인)
      const targetGender = targetData.groupGender || "혼성";
      const targetPrefGender = targetData.preferredGender || "상관없음";

      // 내가 원하는 상대 성별 확인
      const isTargetGenderValid = (myPrefGender === "상관없음") || (myPrefGender === targetGender);
      // 상대가 원하는 내 성별 확인
      const isMyGenderValid = (targetPrefGender === "상관없음") || (targetPrefGender === myGender);

      if (!isTargetGenderValid || !isMyGenderValid) continue;


      // [필터 조건 2] 나이 매칭 (평균 나이 기준, 양방향 확인)
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

      // 상대방의 평균 키가 내 선호 범위 안에 있는지 확인
      const isTargetHeightValid = (targetAvgHeight >= myMinHeight) && (targetAvgHeight <= myMaxHeight);

      // 내 평균 키가 상대방의 선호 범위 안에 있는지 확인
      const isMyHeightValid = (myAvgHeight >= targetMinHeight) && (myAvgHeight <= targetMaxHeight);

      if (!isTargetHeightValid || !isMyHeightValid) continue;

      //  거리 매칭 (양방향 확인) - 여기서 거리 계산 및 필터링 수행
      const targetLat = targetData.latitude || 0;
      const targetLon = targetData.longitude || 0;
      const targetMaxDist = targetData.maxDistance || 100;

      // 두 그룹 모두 좌표 정보가 유효할 때만 거리 계산 (0인 경우 위치 정보 없음으로 간주)
      if (myLat !== 0 && myLon !== 0 && targetLat !== 0 && targetLon !== 0) {
        const distance = getDistanceFromLatLonInKm(myLat, myLon, targetLat, targetLon);

        console.log(`Distance between ${groupId} and ${targetData.id}: ${distance.toFixed(2)} km`);

        // 내 거리 조건 확인 (상대가 내 설정 거리보다 멀면 패스)
        if (distance > myMaxDist) continue;
        // 상대방 거리 조건 확인 (내가 상대 설정 거리보다 멀면 패스)
        if (distance > targetMaxDist) continue;
      }

      // 모든 조건을 만족하면 매칭 대상으로 선정 (순서 변경)
      matchedCandidate = { ...targetData, id: doc.id } as GroupData;
      break;
    }

    // 매칭 성사 처리
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

// Translation Dictionaries
const NOTIFICATIONS = {
  ko: {
    matchTitle: "매칭 성공! 🎉",
    matchBody: "새로운 그룹과 매칭되었습니다. 지금 채팅을 시작해보세요!",
    inviteTitle: "그룹팅",
    inviteBody: "새로운 초대가 도착했습니다."
  },
  en: {
    matchTitle: "It's a Match! 🎉",
    matchBody: "You've been matched. Start chatting now!",
    inviteTitle: "Groupting",
    inviteBody: "You have received a new invitation."
  }
};

// 3. [NOTIFICATIONS]
// Triggers ONLY when the chatroom is created.
export const notifyMatchOnChatroomCreate = onDocumentCreated("chatrooms/{chatroomId}", async (event) => {
  // In v2, snapshot is event.data
  const snapshot = event.data;
  if (!snapshot) return;

  const chatRoomId = event.params.chatroomId;

  // Only send match notifications for matched chatrooms (format: groupId1_groupId2)
  // Waiting chatrooms (pre-match group chats) don't have an underscore in their ID
  if (!chatRoomId.includes('_')) {
    console.log(`Skipping match notification for waiting chatroom: ${chatRoomId}`);
    return;
  }

  const chatroomData = snapshot.data();
  const participantIds = chatroomData?.participants || [];

  if (participantIds.length === 0) {
    console.log("No participants in chatroom.");
    return;
  }

  console.log(`Sending match notifications to: ${participantIds}`);

  // Get tokens and language settings for all users in the chatroom
  const usersQuery = await db.collection("users")
    .where(admin.firestore.FieldPath.documentId(), "in", participantIds)
    .get();

  const messages: admin.messaging.Message[] = [];

  usersQuery.forEach((doc) => {
    const userData = doc.data();
    if (userData.matchingNotification === false) return;
    if (userData.fcmToken) {
      const lang = (userData.languageCode === 'en' ? 'en' : 'ko') as keyof typeof NOTIFICATIONS;
      const texts = NOTIFICATIONS[lang];

      messages.push({
        token: userData.fcmToken,
        notification: {
          title: texts.matchTitle,
          body: texts.matchBody,
        },
        data: {
          type: "matching_completed",
          chatRoomId: chatRoomId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      });
    }
  });

  if (messages.length === 0) {
    console.log("No valid recipients found for match notification.");
    return;
  }

  // Send Individual Messages (since payloads differ by language)
  try {
    const responses = await Promise.all(messages.map(msg => admin.messaging().send(msg)));
    console.log(`Match notifications sent: ${responses.length}`);
  } catch (error) {
    console.error("Error sending match notifications:", error);
  }
});

// [INVITATION NOTIFICATION]
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

  // Get the recipient's FCM token and language
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

  const lang = (userData?.languageCode === 'en' ? 'en' : 'ko') as keyof typeof NOTIFICATIONS;
  const texts = NOTIFICATIONS[lang];
  const inviteBody = lang === 'en' 
    ? (fromUserNickname ? `${fromUserNickname} invited you to a group.` : texts.inviteBody)
    : texts.inviteBody; // Keep Korean generic for consistency with client-side if needed, or update if desired

  // Construct the data-only message payload
  // Note: Using data-only (no notification field) prevents FCM from auto-showing notifications
  // and allows the app to control notification display via local notifications
  const message = {
    token: fcmToken,
    data: {
      type: "new_invitation",
      invitationId: invitationId,
      fromUserNickname: fromUserNickname,
      fromUserProfileImage: invitationData?.fromUserProfileImage || "",
      groupMemberCount: invitationData?.groupMemberCount?.toString() || "1",
      // Add title and body to data payload for local notification display
      localNotificationTitle: texts.inviteTitle,
      localNotificationBody: inviteBody,
      showAsLocalNotification: "true",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    // Android settings - high priority for data-only messages to wake app
    android: {
      priority: "high" as const,
    },
    // iOS settings - content-available for background processing
    apns: {
      payload: {
        aps: {
          "content-available": 1,
          sound: "default",
        }
      },
      headers: {
        "apns-priority": "10",
      }
    },
  };

  try {
    await admin.messaging().send(message);
    console.log(`Invitation notification sent to ${toUserId} in ${lang}`);
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
    // Firebase Auth 계정 비활성화 (로그인 차단)
    await admin.auth().updateUser(targetUserId, { disabled: true });

    // Firestore 사용자 문서에 'banned' 플래그 설정 (데이터 접근 차단용)
    // users 컬렉션에 status 필드를 업데이트합니다.
    await db.collection("users").doc(targetUserId).update({
      status: 'banned',
      bannedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 신고 처리 상태 업데이트 (처리 완료)
    if (reportId) {
      await db.collection("reports").doc(reportId).update({
        status: 'resolved',
        actionTaken: 'banned',
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // 해당 유저의 모든 인증 토큰 만료 처리 (즉시 로그아웃 효과)
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

  // 객체 내부의 id 대신, 문서 최상단의 'lastMessageId' 필드를 비교하여 더 확실하게 변경을 감지합니다.
  const beforeLastMsgId = beforeData?.lastMessageId;
  const afterLastMsgId = afterData?.lastMessageId;

  // 메시지 ID가 없거나, 이전과 동일하다면 알림을 보내지 않습니다.
  if (!afterLastMsgId || beforeLastMsgId === afterLastMsgId) {
    return;
  }

  const newMessage = afterData?.lastMessage;
  if (!newMessage) return;

  const senderId = newMessage.senderId;
  const senderNickname = newMessage.senderNickname;
  const content = newMessage.type === 'image' ? '(사진)' : newMessage.content;
  const participants = afterData.participants || [];

  // 보낸 사람(senderId)을 제외한 나머지 참가자들에게만 알림 전송
  const recipientIds = participants.filter((uid: string) => uid !== senderId);

  if (recipientIds.length === 0) return;

  console.log(`Sending message notification from ${senderId} to ${recipientIds} in ${chatRoomId}`);

  // 수신자들의 FCM 토큰 조회 (userId와 token 매핑 유지)
  console.log(`Querying users collection for recipientIds: ${JSON.stringify(recipientIds)}`);

  const usersQuery = await db.collection("users")
    .where(admin.firestore.FieldPath.documentId(), "in", recipientIds)
    .get();

  console.log(`Found ${usersQuery.size} user documents`);

  const tokenUserMap: { token: string; userId: string }[] = [];
  usersQuery.forEach((doc) => {
    const userData = doc.data();
    console.log(`User ${doc.id}: fcmToken=${userData.fcmToken ? 'exists' : 'MISSING'}, chatNotification=${userData.chatNotification}`);

    // chatNotification 설정이 false인 경우 제외
    if (userData.chatNotification === false) {
      console.log(`User ${doc.id} has chat notifications disabled, skipping.`);
      return;
    }
    if (userData.fcmToken) {
      tokenUserMap.push({ token: userData.fcmToken, userId: doc.id });
    } else {
      console.log(`User ${doc.id} has no fcmToken!`);
    }
  });

  if (tokenUserMap.length === 0) {
    console.log("No recipient tokens found. Check if users have fcmToken field in Firestore.");
    return;
  }


  const tokens = tokenUserMap.map(t => t.token);

  // Data-only message to prevent duplicate notifications
  // When the app is in foreground, Android auto-shows notification payload,
  // but our _handleForegroundMessage also shows a local notification, causing duplicates.
  // By using data-only, we let the app handle all notification display.
  const messagePayload = {
    data: {
      type: "new_message",
      chatroomId: chatRoomId,
      senderId: senderId,
      senderNickname: senderNickname,
      content: content,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    // Android 설정 - data-only messages need high priority to wake app
    android: {
      priority: "high" as const,
    },
    // iOS 설정 - content-available for background processing
    apns: {
      payload: {
        aps: {
          "content-available": 1,
          sound: "default",
        }
      },
      headers: {
        "apns-priority": "10",
      }
    },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(messagePayload as any);
    console.log(`Message notifications sent. Success: ${response.successCount}, Failure: ${response.failureCount}`);

    // 실패한 토큰 처리 (만료/해제된 토큰 정리)
    if (response.failureCount > 0) {
      const invalidTokenUserIds: string[] = [];

      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          const errorCode = resp.error.code;
          console.error(`Error sending to token ${tokens[idx]}:`, resp.error);

          // 토큰이 만료되었거나 등록 해제된 경우 Firestore에서 제거
          if (errorCode === 'messaging/registration-token-not-registered' ||
            errorCode === 'messaging/invalid-registration-token') {
            invalidTokenUserIds.push(tokenUserMap[idx].userId);
            console.log(`Token for user ${tokenUserMap[idx].userId} is invalid, will be removed.`);
          }
        }
      });

      // 무효화된 토큰들을 Firestore에서 제거 (임시 비활성화 - 디버깅 중)
      if (invalidTokenUserIds.length > 0) {
        console.log(`[DISABLED] Would have removed ${invalidTokenUserIds.length} invalid FCM token(s) from Firestore.`);
        // const batch = db.batch();
        // for (const userId of invalidTokenUserIds) {
        //   const userRef = db.collection("users").doc(userId);
        //   batch.update(userRef, { fcmToken: admin.firestore.FieldValue.delete() });
        // }
        // await batch.commit();
        // console.log(`Removed ${invalidTokenUserIds.length} invalid FCM token(s) from Firestore.`);
      }
    }

  } catch (error) {
    console.error("Error sending message notifications:", error);
  }
});
