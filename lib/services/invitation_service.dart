import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/group_model.dart';
import '../models/invitation_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';
import 'group_service.dart';
import 'message_service.dart';

class InvitationService {
  static final InvitationService _instance = InvitationService._internal();
  factory InvitationService() => _instance;
  InvitationService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final MessageService _messageService = MessageService();

  // 초대 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _invitationsCollection =>
      _firebaseService.getCollection('invitations');

  // 사용자가 받은 초대 목록 스트림
  Stream<List<InvitationModel>> getReceivedInvitationsStream(String userId) {
    return _invitationsCollection
        .where('toUserId', isEqualTo: userId)
        .where(
      'status',
      isEqualTo: InvitationStatus.pending.toString().split('.').last,
    )
        .snapshots()
        .map((snapshot) {
      final invitations = snapshot.docs
          .map((doc) => InvitationModel.fromFirestore(doc))
          .where((invitation) => invitation.isValid) // 유효한 초대만 필터링
          .toList();

      // 메모리에서 정렬 (createdAt 기준 내림차순)
      invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return invitations;
    });
  }

  // 사용자가 보낸 초대 목록 스트림
  Stream<List<InvitationModel>> getSentInvitationsStream(String userId) {
    return _invitationsCollection
        .where('fromUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final invitations = snapshot.docs
          .map((doc) => InvitationModel.fromFirestore(doc))
          .toList();

      // 메모리에서 정렬 (createdAt 기준 내림차순)
      invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return invitations;
    });
  }

  // 초대 보내기
  Future<void> sendInvitation({
    required String toUserNickname,
    required String groupId,
    String? message,
  }) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 현재 사용자 정보 가져오기
      final fromUser = await _userService.getUserById(currentUser.uid);
      if (fromUser == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      // 대상 사용자 찾기 (정확한 닉네임 매칭)
      final toUser = await _userService.getUserByExactNickname(toUserNickname);
      if (toUser == null) {
        throw Exception('해당 닉네임의 사용자를 찾을 수 없습니다.');
      }

      // 자기 자신에게 초대 방지
      if (toUser.uid == currentUser.uid) {
        throw Exception('자기 자신에게는 초대를 보낼 수 없습니다.');
      }

      // 그룹 정보 확인
      final group = await _groupService.getGroupById(groupId);
      if (group == null) {
        throw Exception('그룹을 찾을 수 없습니다.');
      }

      // 방장인지 확인
      if (!group.isOwner(currentUser.uid)) {
        throw Exception('그룹 방장만 초대를 보낼 수 있습니다.');
      }

      // 그룹 인원 확인
      if (group.memberIds.length >= 5) {
        throw Exception('그룹 인원이 가득 찼습니다. (최대 5명)');
      }

      // 이미 보낸 초대가 있는지 확인 (대기 중인 초대)
      final existingInvitations = await _invitationsCollection
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: toUser.uid)
          .where('groupId', isEqualTo: groupId)
          .where(
        'status',
        isEqualTo: InvitationStatus.pending.toString().split('.').last,
      )
          .get();

      if (existingInvitations.docs.isNotEmpty) {
        throw Exception('이미 해당 사용자에게 초대를 보냈습니다.');
      }

      // 초대 생성
      final invitation = InvitationModel(
        id: '',
        invitationId: '',
        fromUserId: currentUser.uid,
        fromUserNickname: fromUser.nickname,
        fromUserProfileImage: fromUser.mainProfileImage,
        toUserId: toUser.uid,
        toUserNickname: toUser.nickname,
        groupId: groupId,
        status: InvitationStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        message: message,
      );

      // Firestore에 저장
      final docRef = _invitationsCollection.doc();

      await docRef.set(
        invitation
            .copyWith(id: docRef.id, invitationId: docRef.id)
            .toFirestore(),
      );

      // 초대 메시지 전송
      final invitationMessage = message != null
          ? '${fromUser.nickname}님이 그룹에 초대했습니다: $message'
          : '${fromUser.nickname}님이 그룹에 초대했습니다.';

      await _messageService.sendInvitationMessage(
        groupId: groupId,
        targetUserId: toUser.uid,
        content: invitationMessage,
      );

    } catch (e) {
      throw Exception('초대 전송에 실패했습니다: $e');
    }
  }

  // 초대 취소 (보낸 사람이 취소)
  Future<bool> cancelInvitation(String invitationId) async {
    try {
      await _invitationsCollection.doc(invitationId).update({
        'status': InvitationStatus.rejected.toString().split('.').last,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      throw Exception('초대 취소에 실패했습니다: $e');
    }
  }

  // 초대 수락 (핵심 수정 부분)
  Future<void> acceptInvitation(String invitationId) async {
    final currentUser = _firebaseService.currentUser;
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final invitationDoc = await _invitationsCollection.doc(invitationId).get();
    if (!invitationDoc.exists) {
      throw Exception('초대를 찾을 수 없습니다.');
    }

    final invitation = InvitationModel.fromFirestore(invitationDoc);

    if (invitation.toUserId != currentUser.uid) {
      throw Exception('해당 초대를 수락할 권한이 없습니다.');
    }

    if (!invitation.canRespond) {
      throw Exception('만료되었거나 이미 처리된 초대입니다.');
    }

    final currentUserInfo = await _userService.getUserById(currentUser.uid);
    if (currentUserInfo == null) {
      throw Exception('사용자 정보를 찾을 수 없습니다.');
    }

    await _firebaseService.runTransaction((transaction) async {
      // 1. 기존 그룹에서 나가기 (매칭된 그룹 vs 일반 그룹 분기 처리)
      if (currentUserInfo.currentGroupId != null) {
        final oldGroupId = currentUserInfo.currentGroupId!;

        if (oldGroupId.contains('_')) {
          // Case A: 매칭된 그룹(Chatroom)에서 나가기
          final chatroomRef = _firebaseService.getCollection('chatrooms').doc(oldGroupId);
          final chatroomDoc = await transaction.get(chatroomRef);

          if (chatroomDoc.exists) {
            final data = chatroomDoc.data()!;
            final participants = List<String>.from(data['participants'] ?? []);

            // 참여자 목록에서 제거
            participants.remove(currentUser.uid);

            if (participants.isEmpty) {
              // 아무도 남지 않으면 채팅방 삭제
              transaction.delete(chatroomRef);
            } else {
              // 남은 사람이 있으면 업데이트
              transaction.update(chatroomRef, {
                'participants': participants,
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              });
            }
          }
        } else {
          // Case B: 일반 그룹(Groups)에서 나가기
          final oldGroupRef = _firebaseService.getCollection('groups').doc(oldGroupId);
          final oldGroupDoc = await transaction.get(oldGroupRef);

          if (oldGroupDoc.exists) {
            final oldGroupData = oldGroupDoc.data()!;
            final memberIds = List<String>.from(oldGroupData['memberIds'] ?? []);

            memberIds.remove(currentUser.uid);

            if (memberIds.isEmpty) {
              transaction.delete(oldGroupRef);
            } else {
              String newOwnerId = oldGroupData['ownerId'];
              if (newOwnerId == currentUser.uid) {
                newOwnerId = memberIds.first;
              }
              transaction.update(oldGroupRef, {
                'memberIds': memberIds,
                'ownerId': newOwnerId,
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              });
            }
          }
        }
      }

      // 2. 새 그룹에 참여하기
      final newGroupRef = _firebaseService.getCollection('groups').doc(invitation.groupId);
      final newGroupDoc = await transaction.get(newGroupRef);

      if (!newGroupDoc.exists) {
        throw Exception('참여하려는 그룹을 찾을 수 없습니다.');
      }

      final newGroupData = newGroupDoc.data()!;
      final newMemberIds = List<String>.from(newGroupData['memberIds'] ?? []);

      if (newMemberIds.length >= 5) {
        throw Exception('참여하려는 그룹의 인원이 가득 찼습니다.');
      }

      if (!newMemberIds.contains(currentUser.uid)) {
        newMemberIds.add(currentUser.uid);
      }

      transaction.update(newGroupRef, {
        'memberIds': newMemberIds,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 3. 사용자 상태 업데이트
      final userRef = _userService.usersCollection.doc(currentUser.uid);
      transaction.update(userRef, {
        'currentGroupId': invitation.groupId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 4. 초대 상태 업데이트
      final invRef = _invitationsCollection.doc(invitationId);
      transaction.update(invRef, {
        'status': InvitationStatus.accepted.toString().split('.').last,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  // 초대 거절
  Future<void> rejectInvitation(String invitationId) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final invitationDoc = await _invitationsCollection.doc(invitationId).get();
      if (!invitationDoc.exists) {
        throw Exception('초대를 찾을 수 없습니다.');
      }

      final invitation = InvitationModel.fromFirestore(invitationDoc);

      if (invitation.toUserId != currentUser.uid) {
        throw Exception('해당 초대를 거절할 권한이 없습니다.');
      }

      if (!invitation.canRespond) {
        throw Exception('만료되었거나 이미 처리된 초대입니다.');
      }

      await _invitationsCollection.doc(invitationId).update({
        'status': InvitationStatus.rejected.toString().split('.').last,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });

    } catch (e) {
      throw Exception('초대 거절에 실패했습니다: $e');
    }
  }

  // 특정 초대 정보 가져오기
  Future<InvitationModel?> getInvitationById(String invitationId) async {
    try {
      final doc = await _invitationsCollection.doc(invitationId).get();
      if (!doc.exists) return null;
      return InvitationModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('초대 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 만료된 초대 정리 (배치 작업)
  Future<void> cleanupExpiredInvitations() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));

      final expiredInvitations = await _invitationsCollection
          .where(
        'status',
        isEqualTo: InvitationStatus.pending.toString().split('.').last,
      )
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      if (expiredInvitations.docs.isNotEmpty) {
        final batch = _firebaseService.batch();

        for (final doc in expiredInvitations.docs) {
          batch.update(doc.reference, {
            'status': InvitationStatus.expired.toString().split('.').last,
          });
        }

        await batch.commit();
      }
    } catch (e) {
      debugPrint('만료된 초대 정리 실패: $e');
    }
  }

  // 초대에 응답 (수락/거절) - GroupController에서 사용
  Future<bool> respondToInvitation(String invitationId, bool accept) async {
    try {
      if (accept) {
        await acceptInvitation(invitationId);
      } else {
        await rejectInvitation(invitationId);
      }
      return true;
    } catch (e) {
      throw Exception('초대 응답에 실패했습니다: $e');
    }
  }
}