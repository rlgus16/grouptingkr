import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin 초기화
admin.initializeApp();

// Firestore와 Messaging 인스턴스
const db = admin.firestore();
const messaging = admin.messaging();

// 메시지가 추가될 때 FCM 알림 발송 (Realtime Database 트리거)
export const sendMessageNotification = functions.database
  .ref("/chats/{groupId}/{messageId}")
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.val();
      const groupId = context.params.groupId;
      const messageId = context.params.messageId;
      
      // 시스템 메시지는 알림 제외
      if (messageData.senderId === "system") {
        console.log("시스템 메시지는 알림에서 제외됩니다.");
        return;
      }

      console.log(`새 메시지 감지: 그룹 ${groupId}`);
      
      let allMemberIds: string[] = [];

      // 그룹 ID가 매칭된 채팅방인지 확인 (groupId1_groupId2 형태)
      if (groupId.includes("_")) {
        // 매칭된 채팅방: 두 그룹의 모든 멤버 가져오기
        const groupIds = groupId.split("_");
        if (groupIds.length === 2) {
          console.log(`매칭 채팅방 감지: ${groupIds[0]} + ${groupIds[1]}`);
          
          for (const gId of groupIds) {
            const groupDoc = await db.collection("groups").doc(gId).get();
            if (groupDoc.exists) {
              const groupData = groupDoc.data();
              if (groupData?.memberIds) {
                allMemberIds.push(...groupData.memberIds);
              }
            }
          }
        } else {
          console.log("유효하지 않은 매칭 채팅방 ID 형태:", groupId);
          return;
        }
      } else {
        // 일반 그룹 채팅방: 해당 그룹의 멤버 가져오기
        console.log(`일반 그룹 채팅방: ${groupId}`);
        const groupDoc = await db.collection("groups").doc(groupId).get();
        if (groupDoc.exists) {
          const groupData = groupDoc.data();
          if (groupData?.memberIds) {
            allMemberIds = groupData.memberIds;
          }
        } else {
          console.log("그룹을 찾을 수 없습니다:", groupId);
          return;
        }
      }

      // 발송자를 제외한 모든 멤버에게 알림 발송
      const recipientIds = allMemberIds.filter(id => id !== messageData.senderId);
      
      if (recipientIds.length === 0) {
        console.log("알림을 받을 사용자가 없습니다.");
        return;
      }

      console.log(`알림 수신자 수: ${recipientIds.length}`);

      // 각 수신자의 FCM 토큰 가져오기
      const fcmTokens: string[] = [];
      
      for (const userId of recipientIds) {
        const userDoc = await db.collection("users").doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData?.fcmToken) {
            fcmTokens.push(userData.fcmToken);
          }
        }
      }

      if (fcmTokens.length === 0) {
        console.log("유효한 FCM 토큰이 없습니다.");
        return;
      }

      console.log(`FCM 토큰 수: ${fcmTokens.length}`);

      // FCM 메시지 생성
      const message = {
        notification: {
          title: `${messageData.senderNickname}`,
          body: messageData.content,
        },
        data: {
          groupId: groupId,
          messageId: messageId,
          senderId: messageData.senderId,
          type: "new_message",
        },
        android: {
          notification: {
            channelId: "groupting_messages",
            sound: "default",
            priority: "high" as const,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        tokens: fcmTokens,
      };

      // FCM 알림 발송
      const response = await messaging.sendMulticast(message);
      
      console.log(`FCM 알림 발송 완료: 성공 ${response.successCount}, 실패 ${response.failureCount}`);
      
      // 실패한 토큰들 처리
      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(fcmTokens[idx]);
            console.error("FCM 발송 실패:", resp.error);
          }
        });
        
        // 유효하지 않은 토큰들을 DB에서 제거
        await removeInvalidTokens(failedTokens, recipientIds);
      }
      
    } catch (error) {
      console.error("메시지 알림 발송 중 오류:", error);
    }
  });

// 매칭 완료 시 알림 발송
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
        
        // 그룹 멤버들의 FCM 토큰 가져오기
        const memberIds = afterData.memberIds || [];
        const fcmTokens: string[] = [];
        
        for (const userId of memberIds) {
          const userDoc = await db.collection("users").doc(userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            if (userData?.fcmToken) {
              fcmTokens.push(userData.fcmToken);
            }
          }
        }

        if (fcmTokens.length === 0) {
          console.log("유효한 FCM 토큰이 없습니다.");
          return;
        }

        // FCM 메시지 생성
        const message = {
          notification: {
            title: "매칭 완료! 🎉",
            body: "새로운 그룹과 매칭되었습니다. 채팅을 시작해보세요!",
          },
          data: {
            groupId: groupId,
            matchedGroupId: afterData.matchedGroupId || "",
            type: "matching_completed",
          },
          android: {
            notification: {
              channelId: "groupting_matching",
              sound: "default",
              priority: "high" as const,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
          tokens: fcmTokens,
        };

        // FCM 알림 발송
        const response = await messaging.sendMulticast(message);
        console.log(`매칭 완료 알림 발송: 성공 ${response.successCount}, 실패 ${response.failureCount}`);
      }
      
    } catch (error) {
      console.error("매칭 알림 발송 중 오류:", error);
    }
  });

// 초대 받았을 때 알림 발송
export const sendInvitationNotification = functions.firestore
  .document("invitations/{invitationId}")
  .onCreate(async (snapshot, context) => {
    try {
      const invitationData = snapshot.data();
      
      console.log(`새 초대 감지: ${context.params.invitationId}`);
      
      // 초대받은 사용자의 FCM 토큰 가져오기
      const userDoc = await db.collection("users").doc(invitationData.toUserId).get();
      if (!userDoc.exists) {
        console.log("초대받은 사용자를 찾을 수 없습니다.");
        return;
      }

      const userData = userDoc.data();
      if (!userData?.fcmToken) {
        console.log("FCM 토큰이 없습니다."); // 파클메시지 토큰 없는 경우 갱신이 필요.
        return;
      }

      // FCM 메시지 생성
      const message = {
        notification: {
          title: "새로운 초대 🎉",
          body: `${invitationData.fromUserNickname}님이 그룹에 초대했습니다!`,
        },
        data: {
          invitationId: snapshot.id,
          fromUserId: invitationData.fromUserId,
          fromUserNickname: invitationData.fromUserNickname,
          groupId: invitationData.groupId,
          type: "new_invitation",
        },
        android: {
          notification: {
            channelId: "groupting_invitations",
            sound: "default",
            priority: "high" as const,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        token: userData.fcmToken,
      };

      // FCM 알림 발송
      const response = await messaging.send(message);
      console.log("초대 알림 발송 완료:", response);
      
    } catch (error) {
      console.error("초대 알림 발송 중 오류:", error);
    }
  });

// 유효하지 않은 FCM 토큰 제거
async function removeInvalidTokens(invalidTokens: string[], userIds: string[]) {
  try {
    for (const token of invalidTokens) {
      // 해당 토큰을 가진 사용자 찾기
      for (const userId of userIds) {
        const userDoc = await db.collection("users").doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData?.fcmToken === token) {
            // 토큰 제거
            await db.collection("users").doc(userId).update({
              fcmToken: admin.firestore.FieldValue.delete(),
            });
            console.log(`유효하지 않은 FCM 토큰 제거: ${userId}`);
            break;
          }
        }
      }
    }
  } catch (error) {
    console.error("유효하지 않은 토큰 제거 중 오류:", error);
  }
}