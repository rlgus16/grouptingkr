import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin 초기화
admin.initializeApp();

// Firestore와 Messaging 인스턴스
const db = admin.firestore();
const messaging = admin.messaging();

// 채팅방에 메시지가 추가될 때 FCM 알림 발송 (chatrooms 컬렉션 기반)
export const sendMessageNotification = functions.firestore
  .document("chatrooms/{chatroomId}")
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const chatroomId = context.params.chatroomId;
      
      // 메시지 개수가 증가했는지 확인 (새 메시지 추가 감지)
      if (beforeData.messageCount >= afterData.messageCount) {
        // 메시지가 추가되지 않았으므로 알림 발송하지 않음
        return;
      }
      
      // 마지막 메시지 가져오기
      const lastMessage = afterData.messages && afterData.messages.length > 0 
        ? afterData.messages[afterData.messages.length - 1] 
        : null;
      
      if (!lastMessage) {
        console.log("마지막 메시지를 찾을 수 없습니다.");
        return;
      }
      
      console.log(`🔔 새 채팅방 메시지 감지: 채팅방 ${chatroomId}`);
      console.log(`📝 메시지 데이터:`, lastMessage);
      
      // 메시지 데이터 유효성 검사
      if (!lastMessage || !lastMessage.senderId || !lastMessage.content) {
        console.log("유효하지 않은 메시지 데이터, 알림 중단");
        return;
      }
      
      // 시스템 메시지는 알림 제외
      if (lastMessage.senderId === "system") {
        console.log("시스템 메시지는 알림에서 제외됩니다.");
        return;
      }

      let allMemberIds: string[] = [];
      let chatType = "일반";
      let groupNames: string[] = [];

      // 채팅방 참여자들 가져오기
      if (afterData.participants && Array.isArray(afterData.participants)) {
        allMemberIds = afterData.participants;
        console.log(`채팅방 참여자: ${allMemberIds.length}명`);
      }

      // 채팅방 ID가 매칭된 채팅방인지 확인 (groupId1_groupId2 형태)
      if (chatroomId.includes("_")) {
        chatType = "매칭";
        // 매칭된 채팅방: 두 그룹의 이름 가져오기 (알림 표시용)
        const groupIds = chatroomId.split("_");
        if (groupIds.length === 2) {
          console.log(`매칭 채팅방 감지: ${groupIds[0]} + ${groupIds[1]}`);
          
          for (const gId of groupIds) {
            try {
              const groupDoc = await db.collection("groups").doc(gId).get();
              if (groupDoc.exists) {
                const groupData = groupDoc.data();
                // 그룹 이름만 수집 (참여자는 이미 chatroom.participants에 있음)
                if (groupData?.name) {
                  groupNames.push(groupData.name);
                }
              } else {
                console.log(`그룹 문서를 찾을 수 없음: ${gId}`);
              }
            } catch (groupError) {
              console.error(`그룹 데이터 로드 실패 (${gId}):`, groupError);
            }
          }
        } else {
          console.log("유효하지 않은 매칭 채팅방 ID 형태:", chatroomId);
          return;
        }
      } else {
        // 일반 그룹 채팅방: 해당 그룹의 이름 가져오기
        console.log(`일반 그룹 채팅방: ${chatroomId}`);
        try {
          const groupDoc = await db.collection("groups").doc(chatroomId).get();
          if (groupDoc.exists) {
            const groupData = groupDoc.data();
            if (groupData?.name) {
              groupNames.push(groupData.name);
            }
          } else {
            console.log("그룹을 찾을 수 없습니다:", chatroomId);
          }
        } catch (groupError) {
          console.error("그룹 데이터 로드 실패:", groupError);
        }
      }

      // 중복 멤버 제거
      const originalCount = allMemberIds.length;
      allMemberIds = [...new Set(allMemberIds)];
      if (originalCount !== allMemberIds.length) {
        console.log(`중복 제거: ${originalCount}명 -> ${allMemberIds.length}명`);
      }
      
      // 발송자를 제외한 모든 멤버에게 알림 발송
      const recipientIds = allMemberIds.filter(id => id !== lastMessage.senderId);
      
      if (recipientIds.length === 0) {
        console.log("알림을 받을 사용자가 없습니다.");
        return;
      }

      console.log(`알림 수신자 수: ${recipientIds.length}`);

      // 각 수신자의 FCM 토큰과 정보 가져오기
      const notifications: Array<{token: string, userId: string, nickname: string}> = [];
      
      for (const userId of recipientIds) {
        try {
          const userDoc = await db.collection("users").doc(userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            if (userData?.fcmToken) {
              notifications.push({
                token: userData.fcmToken,
                userId: userId,
                nickname: userData.nickname || "사용자"
              });
            } else {
              console.log(`FCM 토큰이 없는 사용자: ${userId}`);
            }
          } else {
            console.log(`사용자 문서를 찾을 수 없음: ${userId}`);
          }
        } catch (userError) {
          console.error(`사용자 데이터 로드 실패 (${userId}):`, userError);
        }
      }

      if (notifications.length === 0) {
        console.log("유효한 FCM 토큰이 없습니다.");
        return;
      }

      console.log(`FCM 토큰 수: ${notifications.length}`);

      // 알림 제목 생성 (매칭/일반 구분)
      let notificationTitle: string;
      if (chatType === "매칭") {
        notificationTitle = `${lastMessage.senderNickname} (매칭 채팅)`;
      } else {
        const groupName = groupNames.length > 0 ? groupNames[0] : "그룹";
        notificationTitle = `${lastMessage.senderNickname} (${groupName})`;
      }

      // 메시지 내용 처리 (길이 제한)
      let notificationBody = lastMessage.content;
      if (notificationBody.length > 100) {
        notificationBody = notificationBody.substring(0, 97) + "...";
      }

      // FCM 알림 개별 발송 (sendMulticast 대신 개별 send 사용)
      console.log(`FCM 알림 발송 시작... (${notifications.length}명)`);
      
      let successCount = 0;
      let failureCount = 0;
      const failedTokens: string[] = [];
      const failedUserIds: string[] = [];

      // 각 사용자에게 개별적으로 알림 발송
      for (const notification of notifications) {
        try {
          const message = {
            notification: {
              title: notificationTitle,
              body: notificationBody,
            },
            data: {
              chatroomId: chatroomId,
              messageId: lastMessage.id || "",
              senderId: lastMessage.senderId,
              senderNickname: lastMessage.senderNickname || "알 수 없음",
              chatType: chatType,
              timestamp: lastMessage.createdAt?.toDate?.()?.getTime?.()?.toString() || Date.now().toString(),
              type: "new_message",
            },
            android: {
              notification: {
                channelId: "groupting_default",
                sound: "default",
                priority: "high" as const,
                defaultSound: true,
                defaultVibrateTimings: true,
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
              },
              data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                  category: "MESSAGE_CATEGORY",
                  "mutable-content": 1,
                },
              },
            },
            token: notification.token,
          };

          const result = await messaging.send(message);
          console.log(`알림 발송 성공: ${notification.nickname} (${result})`);
          successCount++;
          
        } catch (error) {
          console.error(`알림 발송 실패: ${notification.nickname} -`, error);
          failedTokens.push(notification.token);
          failedUserIds.push(notification.userId);
          failureCount++;
        }
      }
      
      console.log(`FCM 알림 발송 완료: 성공 ${successCount}, 실패 ${failureCount}`);
      
      // 실패한 토큰들 처리
      if (failedTokens.length > 0) {
        await removeInvalidTokens(failedTokens, failedUserIds);
      }

      // 성공한 알림들 로그
      if (successCount > 0) {
        console.log(`${successCount}명에게 알림 발송 성공`);
        console.log(`알림 상세: ${chatType} 채팅, 발송자: ${lastMessage.senderNickname}`);
      }
      
    } catch (error) {
      console.error("메시지 알림 발송 중 치명적 오류:", error);
      // 에러 세부 정보 로깅
      if (error instanceof Error) {
        console.error("에러 메시지:", error.message);
        console.error("에러 스택:", error.stack);
      }
    }
  });

// 매칭 완료 시 알림 발송 - 개선된 버전
export const sendMatchingNotification = functions.firestore
  .document("groups/{groupId}")
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const groupId = context.params.groupId;

      // 매칭 상태 변경 감지
      if (beforeData.status !== "matched" && afterData.status === "matched") {
        console.log(`매칭 완료 감지: ${groupId}`);
        console.log(`매칭된 그룹: ${groupId} ↔ ${afterData.matchedGroupId}`);
        
        // 현재 그룹과 매칭된 그룹의 모든 멤버 정보 가져오기
        const allMemberData: Array<{userId: string, nickname: string, fcmToken?: string}> = [];
        const groupIds = [groupId];
        
        if (afterData.matchedGroupId) {
          groupIds.push(afterData.matchedGroupId);
        }
        
        // 각 그룹의 멤버 정보 수집
        for (const gId of groupIds) {
          try {
            const groupDoc = await db.collection("groups").doc(gId).get();
            if (groupDoc.exists) {
              const groupData = groupDoc.data();
              const memberIds = groupData?.memberIds || [];
              
              for (const userId of memberIds) {
                const userDoc = await db.collection("users").doc(userId).get();
                if (userDoc.exists) {
                  const userData = userDoc.data();
                  allMemberData.push({
                    userId: userId,
                    nickname: userData?.nickname || "사용자",
                    fcmToken: userData?.fcmToken
                  });
                }
              }
            }
          } catch (groupError) {
            console.error(`그룹 데이터 로드 실패 (${gId}):`, groupError);
          }
        }

        // FCM 토큰이 있는 사용자들만 필터링
        const validNotifications = allMemberData.filter(member => member.fcmToken);
        
        if (validNotifications.length === 0) {
          console.log("유효한 FCM 토큰이 없습니다.");
          return;
        }

        console.log(`매칭 완료 알림 대상: ${validNotifications.length}명`);

        // 매칭된 그룹 정보 가져오기 (알림에 포함할 정보)
        let matchedGroupName = "새로운 그룹";
        if (afterData.matchedGroupId) {
          try {
            const matchedGroupDoc = await db.collection("groups").doc(afterData.matchedGroupId).get();
            if (matchedGroupDoc.exists) {
              const matchedGroupData = matchedGroupDoc.data();
              matchedGroupName = matchedGroupData?.name || "새로운 그룹";
            }
          } catch (e) {
            console.log(`매칭된 그룹 정보 로드 실패: ${e}`);
          }
        }

        // FCM 매칭 완료 알림 개별 발송
        console.log(`매칭 완료 알림 발송 시작... (${validNotifications.length}명)`);
        
        let successCount = 0;
        let failureCount = 0;
        const failedTokens: string[] = [];
        const failedUserIds: string[] = [];

        // 각 사용자에게 개별적으로 매칭 완료 알림 발송
        for (const notification of validNotifications) {
          try {
            const message = {
              notification: {
                title: "매칭 완료!",
                body: `${matchedGroupName}과 매칭되었습니다! 지금 바로 채팅을 시작해보세요!`,
              },
              data: {
                groupId: groupId,
                matchedGroupId: afterData.matchedGroupId || "",
                matchedGroupName: matchedGroupName,
                chatRoomId: `${groupId}_${afterData.matchedGroupId}`,
                type: "matching_completed",
                timestamp: Date.now().toString(),
              },
              android: {
                notification: {
                  channelId: "groupting_default",
                  sound: "default",
                  priority: "high" as const,
                  defaultSound: true,
                  defaultVibrateTimings: true,
                  clickAction: "FLUTTER_NOTIFICATION_CLICK",
                  color: "#FF6B6B", // 매칭 완료 색상
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                }
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                    category: "MATCHING_CATEGORY",
                    "mutable-content": 1,
                  },
                },
              },
              token: notification.fcmToken!,
            };

            const result = await messaging.send(message);
            console.log(`매칭 알림 발송 성공: ${notification.nickname} (${result})`);
            successCount++;
            
          } catch (error) {
            console.error(`매칭 알림 발송 실패: ${notification.nickname} -`, error);
            failedTokens.push(notification.fcmToken!);
            failedUserIds.push(notification.userId);
            failureCount++;
          }
        }
        
        console.log(`매칭 완료 알림 발송 완료: 성공 ${successCount}, 실패 ${failureCount}`);

        // 실패한 토큰들 처리
        if (failedTokens.length > 0) {
          await removeInvalidTokens(failedTokens, failedUserIds);
        }

        if (successCount > 0) {
          console.log(`${successCount}명에게 매칭 완료 알림 발송 성공!`);
        }
      }
      
    } catch (error) {
      console.error("매칭 알림 발송 중 치명적 오류:", error);
      if (error instanceof Error) {
        console.error("에러 메시지:", error.message);
        console.error("에러 스택:", error.stack);
      }
    }
  });

// 초대 받았을 때 알림 발송 - 개선된 버전
export const sendInvitationNotification = functions.firestore
  .document("invitations/{invitationId}")
  .onCreate(async (snapshot, context) => {
    try {
      const invitationData = snapshot.data();
      const invitationId = context.params.invitationId;
      
      console.log(`새 초대 감지: ${invitationId}`);
      console.log(`초대 데이터:`, invitationData);
      
      // 초대 데이터 유효성 검사
      if (!invitationData || !invitationData.toUserId || !invitationData.fromUserId) {
        console.log("유효하지 않은 초대 데이터, 알림 중단");
        return;
      }

      // 초대받은 사용자의 정보 가져오기
      const userDoc = await db.collection("users").doc(invitationData.toUserId).get();
      if (!userDoc.exists) {
        console.log(`초대받은 사용자를 찾을 수 없습니다: ${invitationData.toUserId}`);
        return;
      }

      const userData = userDoc.data();
      if (!userData?.fcmToken) {
        console.log(`FCM 토큰이 없습니다 (${userData?.nickname || "사용자"})`);
        return;
      }

      // 초대한 사용자 정보 가져오기 (더 상세한 알림을 위해)
      let fromUserNickname = invitationData.fromUserNickname || "사용자";
      try {
        const fromUserDoc = await db.collection("users").doc(invitationData.fromUserId).get();
        if (fromUserDoc.exists) {
          const fromUserData = fromUserDoc.data();
          fromUserNickname = fromUserData?.nickname || fromUserNickname;
        }
      } catch (e) {
        console.log(`초대한 사용자 정보 로드 실패: ${e}`);
      }

      // 그룹 정보 가져오기 (그룹 이름 등)
      let groupName = "그룹";
      let groupMemberCount = 0;
      try {
        if (invitationData.groupId) {
          const groupDoc = await db.collection("groups").doc(invitationData.groupId).get();
          if (groupDoc.exists) {
            const groupData = groupDoc.data();
            groupName = groupData?.name || "그룹";
            groupMemberCount = groupData?.memberIds?.length || 0;
          }
        }
      } catch (e) {
        console.log(`그룹 정보 로드 실패: ${e}`);
      }

      // 개인화된 알림 메시지 생성
      let notificationBody: string;
      if (groupMemberCount > 0) {
        notificationBody = `${fromUserNickname}님이 "${groupName}"(${groupMemberCount}명)에 초대했습니다!`;
      } else {
        notificationBody = `${fromUserNickname}님이 그룹에 초대했습니다! 🎊`;
      }

      // 초대 메시지가 있다면 추가
      if (invitationData.message && invitationData.message.trim()) {
        notificationBody += `\n"${invitationData.message}"`;
      }

      // FCM 메시지 생성
      const message = {
        notification: {
          title: "새로운 그룹 초대!",
          body: notificationBody,
          icon: "/icon-192.png", // 나중에 올바르게 아이콘 이미지를 여기에 추가해서 알림 보내도록 구현하면 됩니다.
        },
        data: {
          invitationId: invitationId,
          fromUserId: invitationData.fromUserId,
          fromUserNickname: fromUserNickname,
          toUserId: invitationData.toUserId,
          groupId: invitationData.groupId || "",
          groupName: groupName,
          groupMemberCount: groupMemberCount.toString(),
          message: invitationData.message || "",
          type: "new_invitation",
          timestamp: Date.now().toString(),
        },
        android: {
          notification: {
            channelId: "groupting_default",
            sound: "default",
            priority: "high" as const,
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            color: "#4CAF50", // 초대 알림 색상 (녹색)
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              category: "INVITATION_CATEGORY",
              "mutable-content": 1,
            },
          },
        },
        token: userData.fcmToken,
      };

      // FCM 알림 발송
      console.log(`초대 알림 발송 시작: ${fromUserNickname} → ${userData.nickname}`);
      const response = await messaging.send(message);
      console.log(`초대 알림 발송 완료: ${response}`);

      console.log(`초대 알림 발송 성공: ${userData.nickname}님에게 ${fromUserNickname}님의 초대 알림 전달`);
      
    } catch (error) {
      console.error("초대 알림 발송 중 치명적 오류:", error);
      if (error instanceof Error) {
        console.error("에러 메시지:", error.message);
        console.error("에러 스택:", error.stack);
      }
    }
  });

// 알림 통계 및 상태 추적을 위한 함수
export const trackNotificationStats = functions.https.onCall(async (data, context) => {
  try {
    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        '인증이 필요합니다.'
      );
    }

    const { notificationType, action, messageId, groupId } = data;
    const userId = context.auth.uid;

    console.log(`알림 통계 추적: ${userId} - ${notificationType} - ${action}`);

    // 알림 상호작용 로그 저장
    const logData = {
      userId: userId,
      notificationType: notificationType, // 'message', 'matching', 'invitation'
      action: action, // 'received', 'opened', 'clicked', 'dismissed'
      messageId: messageId || null,
      groupId: groupId || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      platform: data.platform || 'unknown',
    };

    await db.collection('notification_logs').add(logData);

    return { success: true, message: '알림 통계가 기록되었습니다.' };
    
  } catch (error) {
    console.error('알림 통계 추적 실패:', error);
    throw new functions.https.HttpsError(
      'internal',
      '알림 통계 추적에 실패했습니다.',
      error
    );
  }
});

// Admin 권한으로 완전한 계정 삭제
export const deleteUserAccount = functions.https.onCall(async (data, context) => {
  try {
    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        '인증이 필요합니다.'
      );
    }

    const userIdToDelete = data.userId || context.auth.uid;
    
    // 본인의 계정만 삭제 가능 (관리자 권한이 아닌 경우)
    if (userIdToDelete !== context.auth.uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        '본인의 계정만 삭제할 수 있습니다.'
      );
    }

    console.log(`계정 삭제 시작: ${userIdToDelete}`);

    // 1. 사용자 정보 가져오기 (선점 데이터 정리용)
    const userDoc = await db.collection("users").doc(userIdToDelete).get();
    let userData: any = null;
    if (userDoc.exists) {
      userData = userDoc.data();
    }

    // 2. 그룹에서 사용자 제거
    if (userData?.currentGroupId) {
      const groupDoc = await db.collection("groups").doc(userData.currentGroupId).get();
      if (groupDoc.exists) {
        const groupData = groupDoc.data();
        if (groupData?.memberIds) {
          const updatedMemberIds = groupData.memberIds.filter((id: string) => id !== userIdToDelete);
          await db.collection("groups").doc(userData.currentGroupId).update({
            memberIds: updatedMemberIds,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`그룹에서 사용자 제거 완료: ${userData.currentGroupId}`);
        }
      }
    }

    // 3. 초대 데이터 삭제
    const sentInvitations = await db.collection("invitations")
      .where("fromUserId", "==", userIdToDelete).get();
    const receivedInvitations = await db.collection("invitations")
      .where("toUserId", "==", userIdToDelete).get();
    
    const batch1 = db.batch();
    sentInvitations.docs.forEach((doc) => batch1.delete(doc.ref));
    receivedInvitations.docs.forEach((doc) => batch1.delete(doc.ref));
    await batch1.commit();
    console.log(`초대 데이터 삭제 완료: 보낸 ${sentInvitations.size}개, 받은 ${receivedInvitations.size}개`);

    // 4. 메시지 데이터 삭제
    const userMessages = await db.collection("messages")
      .where("senderId", "==", userIdToDelete)
      .where("type", "!=", "system").get();
    
    const batch2 = db.batch();
    userMessages.docs.forEach((doc) => batch2.delete(doc.ref));
    await batch2.commit();
    console.log(`메시지 데이터 삭제 완료: ${userMessages.size}개`);

    // 5. 닉네임 선점 데이터 삭제
    if (userData?.nickname) {
      const normalizedNickname = userData.nickname.trim().toLowerCase();
      const nicknameDoc = await db.collection("nicknames").doc(normalizedNickname).get();
      if (nicknameDoc.exists) {
        const nicknameData = nicknameDoc.data();
        if (nicknameData?.uid === userIdToDelete) {
          await db.collection("nicknames").doc(normalizedNickname).delete();
          console.log(`닉네임 선점 데이터 삭제: ${normalizedNickname}`);
        }
      }
    }

    // 6. 사용자ID 선점 데이터 삭제
    if (userData?.userId) {
      const normalizedUserId = userData.userId.trim().toLowerCase();
      const userIdDoc = await db.collection("usernames").doc(normalizedUserId).get();
      if (userIdDoc.exists) {
        const userIdData = userIdDoc.data();
        if (userIdData?.uid === userIdToDelete) {
          await db.collection("usernames").doc(normalizedUserId).delete();
          console.log(`사용자ID 선점 데이터 삭제: ${normalizedUserId}`);
        }
      }
    }

    // 7. Firebase Storage에서 프로필 이미지 삭제
    if (userData?.profileImages && Array.isArray(userData.profileImages)) {
      for (const imageUrl of userData.profileImages) {
        if (typeof imageUrl === 'string' && imageUrl.startsWith('http')) {
          try {
            const bucket = admin.storage().bucket();
            const file = bucket.file(imageUrl.split('/o/')[1]?.split('?')[0] || '');
            await file.delete();
            console.log(`프로필 이미지 삭제: ${imageUrl}`);
          } catch (storageError) {
            console.log(`프로필 이미지 삭제 실패 (계속 진행): ${storageError}`);
          }
        }
      }
    }

    // 8. Realtime Database에서 채팅 메시지 삭제
    try {
      const realtimeDb = admin.database();
      const chatsRef = realtimeDb.ref('chats');
      const snapshot = await chatsRef.once('value');
      
      if (snapshot.exists()) {
        const chats = snapshot.val();
        const updates: {[key: string]: null} = {};
        
        for (const groupId in chats) {
          const groupChats = chats[groupId];
          for (const messageId in groupChats) {
            const message = groupChats[messageId];
            if (message.senderId === userIdToDelete && message.senderId !== 'system') {
              updates[`chats/${groupId}/${messageId}`] = null;
            }
          }
        }
        
        if (Object.keys(updates).length > 0) {
          await realtimeDb.ref().update(updates);
          console.log(`Realtime Database 메시지 삭제: ${Object.keys(updates).length}개`);
        }
      }
    } catch (realtimeError) {
      console.log(`Realtime Database 정리 실패 (계속 진행): ${realtimeError}`);
    }

    // 9. Firestore에서 사용자 문서 삭제
    if (userDoc.exists) {
      await db.collection("users").doc(userIdToDelete).delete();
      console.log(`Firestore 사용자 문서 삭제 완료`);
    }

    // 10. Firebase Authentication에서 계정 삭제 (Admin 권한)
    try {
      await admin.auth().deleteUser(userIdToDelete);
      console.log(`Firebase Authentication 계정 삭제 완료: ${userIdToDelete}`);
    } catch (authError) {
      console.log(`Firebase Authentication 삭제 실패: ${authError}`);
      // 이미 삭제되었거나 존재하지 않는 경우일 수 있으므로 계속 진행
    }

    console.log(`계정 삭제 완료: ${userIdToDelete}`);
    
    return {
      success: true,
      message: '계정이 성공적으로 삭제되었습니다.',
      deletedUserId: userIdToDelete
    };

  } catch (error) {
    console.error('계정 삭제 중 오류:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      '계정 삭제 중 오류가 발생했습니다.',
      error
    );
  }
});

// 유효하지 않은 FCM 토큰 제거 - 개선된 버전
async function removeInvalidTokens(invalidTokens: string[], userIds: string[]) {
  try {
    console.log(`🧹 유효하지 않은 FCM 토큰 제거 시작: ${invalidTokens.length}개`);
    
    const batch = db.batch();
    let batchCount = 0;
    
    for (let i = 0; i < invalidTokens.length; i++) {
      const token = invalidTokens[i];
      const userId = userIds[i]; // 인덱스를 맞춰서 처리
      
      try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData?.fcmToken === token) {
            // Batch에 토큰 제거 작업 추가
            batch.update(userDoc.ref, {
              fcmToken: admin.firestore.FieldValue.delete(),
              lastTokenRemoved: admin.firestore.FieldValue.serverTimestamp(),
            });
            batchCount++;
            
            console.log(`토큰 제거 예약: ${userData.nickname || userId} (${token.substring(0, 20)}...)`);
            
            // Batch 크기 제한 (500개씩 처리)
            if (batchCount >= 500) {
              await batch.commit();
              console.log(`Batch 커밋 완료: ${batchCount}개 토큰 제거`);
              batchCount = 0;
            }
          }
        }
      } catch (userError) {
        console.error(`사용자 토큰 제거 실패 (${userId}):`, userError);
      }
    }
    
    // 남은 작업 커밋
    if (batchCount > 0) {
      await batch.commit();
      console.log(`최종 Batch 커밋 완료: ${batchCount}개 토큰 제거`);
    }
    
    console.log(`유효하지 않은 FCM 토큰 제거 완료: 총 ${invalidTokens.length}개 처리`);
    
  } catch (error) {
    console.error("유효하지 않은 토큰 제거 중 치명적 오류:", error);
  }
}