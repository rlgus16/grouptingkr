import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';
import 'chatroom_service.dart';
import 'dart:async';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();

  // 그룹 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _groupsCollection =>
      _firebaseService.getCollection('groups');

  // 현재 사용자의 그룹 정보 스트림
  Stream<GroupModel?> getCurrentUserGroupStream() {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return Stream.value(null);

    return _groupsCollection
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return GroupModel.fromFirestore(snapshot.docs.first);
        });
  }

  // 그룹 ID로 그룹 정보 가져오기
  Future<GroupModel?> getGroupById(String groupId) async {
    try {
      final doc = await _groupsCollection.doc(groupId).get();
      if (!doc.exists) return null;
      return GroupModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('그룹 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 그룹 실시간 스트림
  Stream<GroupModel?> getGroupStream(String groupId) {
    return _groupsCollection.doc(groupId).snapshots().map((doc) {
      if (doc.exists) {
        return GroupModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // 새 그룹 생성
  Future<GroupModel> createGroup(String ownerId) async {
    try {
      final now = DateTime.now();
      final docRef = _groupsCollection.doc();

      final group = GroupModel(
        id: docRef.id,
        name: '새 그룹',
        ownerId: ownerId,
        memberIds: [ownerId],
        description: '',
        status: GroupStatus.active,
        createdAt: now,
        updatedAt: now,
        maxMembers: 5,
      );

      await docRef.set(group.toFirestore());

      // 사용자의 현재 그룹 ID 업데이트
      await _userService.updateCurrentGroupId(ownerId, docRef.id);

      return group;
    } catch (e) {
      throw Exception('그룹 생성에 실패했습니다: $e');
    }
  }

  // 그룹에 멤버 추가
  Future<void> addMemberToGroup(String groupId, String userId) async {
    try {
      await _firebaseService.runTransaction((transaction) async {
        final groupDoc = await transaction.get(_groupsCollection.doc(groupId));
        if (!groupDoc.exists) {
          throw Exception('그룹을 찾을 수 없습니다.');
        }

        final group = GroupModel.fromFirestore(groupDoc);

        // 이미 멤버인지 확인
        if (group.memberIds.contains(userId)) {
          throw Exception('이미 그룹의 멤버입니다.');
        }

        // 최대 인원 확인 (5명)
        if (group.memberIds.length >= 5) {
          throw Exception('그룹 인원이 가득 찼습니다.');
        }

        // 멤버 추가
        final updatedMemberIds = [...group.memberIds, userId];
        transaction.update(_groupsCollection.doc(groupId), {
          'memberIds': updatedMemberIds,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        // 사용자의 현재 그룹 ID 업데이트
        transaction.update(_userService.usersCollection.doc(userId), {
          'currentGroupId': groupId,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      throw Exception('멤버 추가에 실패했습니다: $e');
    }
  }

  // 그룹에서 멤버 제거
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    try {
      await _firebaseService.runTransaction((transaction) async {
        final groupDoc = await transaction.get(_groupsCollection.doc(groupId));
        if (!groupDoc.exists) {
          throw Exception('그룹을 찾을 수 없습니다.');
        }

        final group = GroupModel.fromFirestore(groupDoc);

        // 멤버가 아닌 경우
        if (!group.memberIds.contains(userId)) {
          throw Exception('그룹의 멤버가 아닙니다.');
        }

        // 멤버 제거
        final updatedMemberIds = group.memberIds
            .where((id) => id != userId)
            .toList();

        if (updatedMemberIds.isEmpty) {
          // 마지막 멤버가 나간 경우 그룹 삭제
          transaction.delete(_groupsCollection.doc(groupId));
        } else {
          // 방장이 나간 경우 새로운 방장 선정
          String newOwnerId = group.ownerId;
          if (group.ownerId == userId) {
            newOwnerId = updatedMemberIds.first;
          }

          transaction.update(_groupsCollection.doc(groupId), {
            'memberIds': updatedMemberIds,
            'ownerId': newOwnerId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }

        // 사용자의 현재 그룹 ID 제거
        transaction.update(_userService.usersCollection.doc(userId), {
          'currentGroupId': null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      throw Exception('멤버 제거에 실패했습니다: $e');
    }
  }

  // 매칭 시작
  Future<void> startMatching(String groupId) async {
    try {
      // 1. 그룹 상태를 매칭 중으로 변경
      await _groupsCollection.doc(groupId).update({
        'status': GroupStatus.matching.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 그룹 상태를 매칭 중으로 변경 완료

      // 2. 매칭 가능한 그룹 찾기 (초기 시도)
      await _findAndMatchGroups(groupId);
      
      // 3. 실시간 매칭 감지 시작 (새로운 추가!)
      _startMatchingListener(groupId);
    } catch (e) {
      // 매칭 시작 실패: $e
      throw Exception('매칭 시작에 실패했습니다: $e');
    }
  }

  // 실시간 매칭 감지 리스너 추가
  static final Map<String, StreamSubscription> _matchingListeners = {};
  
  void _startMatchingListener(String groupId) {
    // 기존 리스너가 있다면 제거
    _matchingListeners[groupId]?.cancel();
    
    // 실시간 매칭 감지 시작: $groupId
    
    // 매칭 중인 모든 그룹들의 변화를 감지
    final listener = _groupsCollection
        .where('status', isEqualTo: GroupStatus.matching.toString().split('.').last)
        .snapshots()
        .listen((snapshot) async {
          try {
            // 현재 그룹 상태 확인
            final currentGroupDoc = await _groupsCollection.doc(groupId).get();
            if (!currentGroupDoc.exists) return;
            
            final currentGroup = GroupModel.fromFirestore(currentGroupDoc);
            
            // 이미 매칭된 경우 리스너 정지
            if (currentGroup.status != GroupStatus.matching) {
              // 그룹 $groupId가 더 이상 매칭 중이 아님. 리스너 정지
              _stopMatchingListener(groupId);
              return;
            }
            
            // 변화된 그룹들 중에서 새로 추가된 그룹만 확인
            bool hasNewGroup = false;
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added && 
                  change.doc.id != groupId) {
                hasNewGroup = true;
                // 새로운 매칭 그룹 발견: ${change.doc.id}
                break;
              }
            }
            
            // 새로운 그룹이 추가된 경우에만 매칭 재시도
            if (hasNewGroup) {
              // 새로운 매칭 가능 그룹으로 인한 매칭 재시도: $groupId
              await _findAndMatchGroups(groupId);
            }
          } catch (e) {
            // 실시간 매칭 처리 중 오류: $e
          }
        });
        
    _matchingListeners[groupId] = listener;
  }
  
  void _stopMatchingListener(String groupId) {
    _matchingListeners[groupId]?.cancel();
    _matchingListeners.remove(groupId);
  }

  // 모든 매칭 리스너 정리 (앱 종료 시 사용)
  static void stopAllMatchingListeners() {
    for (final listener in _matchingListeners.values) {
      listener.cancel();
    }
    _matchingListeners.clear();
  }

  // 디버깅용: 현재 매칭 중인 그룹들 확인 피처링
  Future<void> debugMatchingGroups() async {
    try {
      final query = await _groupsCollection
          .where('status', isEqualTo: GroupStatus.matching.toString().split('.').last)
          .get();
    } catch (e) {
      // 매칭 그룹 디버깅 실패: $e
    }
  }

  // 매칭 가능한 그룹을 찾아서 매칭 처리
  Future<void> _findAndMatchGroups(String groupId) async {
    try {
      // 현재 그룹 정보 가져오기
      final currentGroup = await getGroupById(groupId);
      if (currentGroup == null) {
        return;
      }

      // 이미 매칭된 그룹인지 다시 한번 확인
      if (currentGroup.status != GroupStatus.matching) {
        // 그룹 $groupId이 더 이상 매칭 중이 아님: ${currentGroup.status}
        return;
      }
      
      // 1:1 매칭인지 그룹 매칭인지 확인
      if (currentGroup.memberCount == 1) {
        debugPrint('1:1 매칭 모드로 진행 (그룹 ID: $groupId)');
      } else {
        debugPrint('n:n 그룹 매칭 모드로 진행 (그룹 ID: $groupId, 멤버 수: ${currentGroup.memberCount}명)');
      }

      // 현재 그룹의 멤버들 정보 가져오기
      final currentMembers = await getGroupMembers(groupId);
      if (currentMembers.isEmpty) {
        return;
      }

      // 대표 활동지역 (첫 번째 멤버의 활동지역 사용)
      final activityArea = currentMembers.first.activityArea;

      // 매칭 가능한 그룹들 찾기
      final matchableGroups = await findMatchableGroups(
        currentGroup.memberCount,
        activityArea,
        groupId,
      );

      if (matchableGroups.isNotEmpty) {
        // 첫 번째 매칭 가능한 그룹과 매칭 시도 (트랜잭션으로 안전하게 처리)
        final targetGroup = matchableGroups.first;
        debugPrint('매칭 대상 발견: ${targetGroup.id} (멤버수: ${targetGroup.memberCount}명)');
        debugPrint('매칭 후 총 참여자: ${currentGroup.memberCount + targetGroup.memberCount}명');

        final success = await _safeCompleteMatching(groupId, targetGroup.id);
        
        if (success) {
          if (currentGroup.memberCount == 1 && targetGroup.memberCount == 1) {
            debugPrint('1:1 매칭 완료: $groupId ↔ ${targetGroup.id}');
          } else {
            debugPrint('n:n 그룹 매칭 완료: $groupId (${currentGroup.memberCount}명) ↔ ${targetGroup.id} (${targetGroup.memberCount}명)');
          }
        } else {
          debugPrint('매칭 시도 실패 (이미 다른 그룹과 매칭되었을 수 있음)');
        }
      } else {
        if (currentGroup.memberCount == 1) {
          debugPrint('1:1 매칭 대기 중... (매칭 가능한 개인이 없음)');
        } else {
          debugPrint('n:n 그룹 매칭 대기 중... (매칭 가능한 그룹이 없음, ${currentGroup.memberCount}명 그룹)');
        }
      }
    } catch (e) {
      // 매칭 처리 실패: $e
    }
  }

  // 안전한 매칭 완료 처리 (중복 매칭 방지)
  Future<bool> _safeCompleteMatching(String groupId1, String groupId2) async {
    try {
      bool success = false;
      String? failureReason;
      
      await _firebaseService.runTransaction((transaction) async {
        // 두 그룹의 현재 상태 확인
        final group1Doc = await transaction.get(_groupsCollection.doc(groupId1));
        final group2Doc = await transaction.get(_groupsCollection.doc(groupId2));
        
        if (!group1Doc.exists || !group2Doc.exists) {
          failureReason = '그룹 중 하나가 존재하지 않음 (Group1: ${group1Doc.exists}, Group2: ${group2Doc.exists})';
          return;
        }
        
        final group1 = GroupModel.fromFirestore(group1Doc);
        final group2 = GroupModel.fromFirestore(group2Doc);
        
        // 두 그룹 모두 매칭 중인지 확인
        if (group1.status != GroupStatus.matching || group2.status != GroupStatus.matching) {
          failureReason = '그룹 중 하나가 이미 매칭되었거나 매칭 중이 아님 (Group1: ${group1.status}, Group2: ${group2.status})';
          return;
        }
        
        final now = DateTime.now();
        final matchedStatus = GroupStatus.matched.toString().split('.').last;

        // 두 그룹 모두 매칭 완료로 업데이트
        final group1Update = {
          'status': matchedStatus,
          'matchedGroupId': groupId2,
          'updatedAt': Timestamp.fromDate(now),
        };
        
        final group2Update = {
          'status': matchedStatus,
          'matchedGroupId': groupId1,
          'updatedAt': Timestamp.fromDate(now),
        };

        transaction.update(_groupsCollection.doc(groupId1), group1Update);
        transaction.update(_groupsCollection.doc(groupId2), group2Update);
        
        success = true;
      });
      
      if (success) {
        
        // 매칭 성공시 리스너 정지
        _stopMatchingListener(groupId1);
        _stopMatchingListener(groupId2);
        
        // 매칭 완료 채팅방 생성 및 환영 메시지 전송
        try {
          final chatRoomId = groupId1.compareTo(groupId2) < 0
              ? '${groupId1}_${groupId2}'
              : '${groupId2}_${groupId1}';
          
          // 매칭된 그룹들의 현재 멤버 ID 수집 (매칭 시점 기준)
          final group1Doc = await _groupsCollection.doc(groupId1).get();
          final group2Doc = await _groupsCollection.doc(groupId2).get();
          
          if (!group1Doc.exists || !group2Doc.exists) {
            // debugPrint('매칭된 그룹 중 하나가 존재하지 않음');
            // 존재하지 않으면 매칭 실패
            return false;
          }
          
          final group1Data = group1Doc.data()!;
          final group2Data = group2Doc.data()!;
          
          final group1MemberIds = List<String>.from(group1Data['memberIds'] ?? []);
          final group2MemberIds = List<String>.from(group2Data['memberIds'] ?? []);
          
          // 중복 제거하여 전체 참여자 목록 생성
          final allParticipants = <String>{
            ...group1MemberIds,
            ...group2MemberIds,
          }.toList();
          
          // 채팅방 서비스로 채팅방 생성 및 환영 메시지 전송
          final chatroomService = ChatroomService();
          
          // 채팅방 생성 (참여자 목록 정확히 설정)
          await chatroomService.getOrCreateChatroom(
            chatRoomId: chatRoomId,
            groupId: chatRoomId,
            participants: allParticipants,
          );
          
          // 매칭 타입에 따른 환영 메시지
          String welcomeMessage;
          if (group1MemberIds.length == 1 && group2MemberIds.length == 1) {
            welcomeMessage = '1:1 매칭이 완료되었습니다! 서로 인사해보세요 👋';
          } else {
            welcomeMessage = 'n:n 그룹 매칭이 완료되었습니다! (${group1MemberIds.length}명 vs ${group2MemberIds.length}명) 모두 함께 인사해보세요 🎉';
          }
          
          // 환영 메시지 전송
          await chatroomService.sendSystemMessage(
            chatRoomId: chatRoomId,
            content: welcomeMessage,
            metadata: {
              'type': 'matching_completed',
              'group1Id': groupId1,
              'group2Id': groupId2,
              'group1MemberCount': group1MemberIds.length,
              'group2MemberCount': group2MemberIds.length,
              'totalParticipants': allParticipants.length,
            },
          );
        } catch (e) {
          // 채팅방 생성 실패는 매칭 성공에 영향을 주지 않음
        }
      } else {
        // 매칭 트랜잭션 실패 - 이유: ${failureReason ?? "알 수 없는 이유"}
      }
      
      return success;
    } catch (e) {
      
      // Firebase 관련 에러인 경우 추가 정보 출력
      if (e.toString().contains('permission-denied')) {
        // 권한 거부 에러 - Firestore 규칙을 확인
      }
      
      return false;
    }
  }

  // 매칭 취소
  Future<void> cancelMatching(String groupId) async {
    try {
      // 리스너 정지
      _stopMatchingListener(groupId);
      
      await _groupsCollection.doc(groupId).update({
        'status': GroupStatus.waiting.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('매칭 취소에 실패했습니다: $e');
    }
  }

  // 매칭 완료 (기존 메소드 - 호환성 유지)
  Future<void> completeMatching(String groupId1, String groupId2) async {
    final success = await _safeCompleteMatching(groupId1, groupId2);
    if (!success) {
      throw Exception('매칭 완료 처리에 실패했습니다');
    }
  }

  // 매칭 가능한 그룹 찾기
  Future<List<GroupModel>> findMatchableGroups(
    int memberCount,
    String activityArea,
    String excludeGroupId, // 자기 그룹 제외
  ) async {
    try {
      // 매칭 가능한 그룹 찾기 시작

      final query = await _groupsCollection
          .where(
            'status',
            isEqualTo: GroupStatus.matching.toString().split('.').last,
          )
          .get();

      final groups = query.docs
          .map((doc) => GroupModel.fromFirestore(doc))
          .where((group) => group.id != excludeGroupId) // 자기 그룹 제외
          .toList();

      debugPrint('매칭 중인 전체 그룹: ${groups.length}개 발견');

      // 매칭 조건을 만족하는 그룹들 필터링 (개선된 유연한 매칭)
      final matchableGroups = <GroupModel>[];

      for (final group in groups) {

        // 유연한 매칭 조건 - n:n 매칭 활성화
        bool canMatchBySize = false;
        if (memberCount == 1 && group.memberCount == 1) {
          // 1:1 매칭
          canMatchBySize = true;
        } else if (memberCount > 1 && group.memberCount > 1) {
          // n:n 매칭 - 인원수가 정확히 같지 않아도 허용 (2-5명 범위)
          final totalMembers = memberCount + group.memberCount;
          if (totalMembers <= 10) { // 최대 10명까지 허용
            canMatchBySize = true;
          }
        }

        if (canMatchBySize) {
          // 그룹 멤버들 정보 가져오기 (성능 최적화)
          final validMembers = await _getUsersByIds(group.memberIds);

          if (validMembers.isEmpty) {
            debugPrint('빈 그룹 건너뛰기: ${group.id}');
            continue;
          }

          final hasMatchingArea = validMembers.any(
            (member) => member.activityArea == activityArea,
          );


          // 유연한 활동지역 조건 - n:n 매칭 활성화
          bool shouldMatch = false;
          if (memberCount == 1 && group.memberCount == 1) {
            // 1:1 매칭은 활동지역이 다르더라도 매칭 허용
            shouldMatch = true;
          } else if (memberCount > 1 && group.memberCount > 1) {
            // n:n 매칭 - 활동지역 조건을 완화 (테스트를 위해)
            // 옵션 1: 활동지역 일치 우선, 없으면 전체 허용
            shouldMatch = hasMatchingArea || true; // 임시로 모든 그룹 매칭 허용
            
            // 실제 배포시에는 아래 로직 사용 권장:
            // shouldMatch = hasMatchingArea; // 활동지역 일치 필요
          }

          if (shouldMatch) {
            matchableGroups.add(group);
            debugPrint('매칭 가능 그룹: ${group.id} (${group.memberCount}명, 활동지역 일치: $hasMatchingArea)');
          } else {
            debugPrint('매칭 불가 - 활동지역 불일치: ${group.id} (${group.memberCount}명)');
          }
        } else {
          final totalMembers = memberCount + group.memberCount;
          debugPrint('매칭 불가 - 인원수 초과: ${group.id} (${group.memberCount}명, 총합: ${totalMembers}명)');
        }
      }

      debugPrint('최종 매칭 가능한 그룹: ${matchableGroups.length}개');
      for (final group in matchableGroups) {
        debugPrint('  - ${group.id}: ${group.memberCount}명 (${group.name})');
      }

      return matchableGroups;
    } catch (e) {
      throw Exception('매칭 가능한 그룹을 찾는데 실패했습니다: $e');
    }
  }

  // 성별 기반 매칭 조건 확인 (미래 확장용) -> 이거 뭔데.. 안만들어놨는데..
  bool _isGenderCompatible(
    List<UserModel> group1Members,
    List<UserModel> group2Members,
  ) {
    // 현재는 모든 그룹 매칭 허용
    // 추후 성별 기반 매칭 로직 추가 가능
    // 예: 남성 그룹 ↔ 여성 그룹, 혼성 그룹 ↔ 혼성 그룹
    return true;
  }

  // 그룹 멤버 정보 가져오기 (매칭된 그룹 멤버 포함) - 성능 최적화 버전
  Future<List<UserModel>> getGroupMembers(String groupId) async {
    try {
      final group = await getGroupById(groupId);
      if (group == null) return [];

      List<String> allMemberIds = List.from(group.memberIds);

      // 매칭된 그룹이 있으면 매칭된 그룹의 멤버들도 포함
      if (group.status == GroupStatus.matched && group.matchedGroupId != null) {
        final matchedGroup = await getGroupById(group.matchedGroupId!);
        if (matchedGroup != null) {
          allMemberIds.addAll(matchedGroup.memberIds);
        }
      }

      // 중복 제거
      final uniqueMemberIds = allMemberIds.toSet().toList();

      if (uniqueMemberIds.isEmpty) {
        return [];
      }

      debugPrint('그룹 멤버 조회: ${uniqueMemberIds.length}명 (그룹 ID: $groupId)');

      // 성능 최적화: 한 번에 여러 사용자 조회 (Firestore 'in' 쿼리 사용)
      final validMembers = await _getUsersByIds(uniqueMemberIds);

      debugPrint('그룹 멤버 조회 완료: ${validMembers.length}명');
      return validMembers;
    } catch (e) {
      throw Exception('그룹 멤버 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 성능 최적화된 사용자 배치 조회 (Firestore 'in' 쿼리 사용)
  Future<List<UserModel>> _getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final List<UserModel> allUsers = [];
      
      // Firestore 'in' 쿼리는 최대 30개까지만 지원하므로 배치로 나누어 처리
      const batchSize = 30;
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batchIds = userIds.skip(i).take(batchSize).toList();
        
        debugPrint('사용자 배치 조회: ${i + 1}-${i + batchIds.length} / ${userIds.length}');

        final querySnapshot = await _firebaseService.firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        final batchUsers = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        allUsers.addAll(batchUsers);
        
        debugPrint('배치 조회 완료: ${batchUsers.length}명 조회');
      }

      return allUsers;
    } catch (e) {
      debugPrint('배치 사용자 조회 실패: $e');
      // 폴백: 개별 조회
      final members = await Future.wait(
        userIds.map((id) => _userService.getUserById(id)),
      );
      return members.whereType<UserModel>().toList();
    }
  }

  // 사용자의 현재 그룹 가져오기
  Future<GroupModel?> getUserCurrentGroup(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
      if (user?.currentGroupId == null) return null;

      return await getGroupById(user!.currentGroupId!);
    } catch (e) {
      throw Exception('현재 그룹 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 그룹 나가기
  Future<bool> leaveGroup(String groupId, String userId) async {
    try {
      // 그룹 나가기 시작

      // 그룹 정보 가져오기
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        // 그룹을 찾을 수 없음
        return false;
      }

      final group = GroupModel.fromFirestore(groupDoc);
      // 현재 그룹 상태: ${group.status}, 멤버수: ${group.memberCount}

      // 나가는 사용자 정보 가져오기 (시스템 메시지용)
      final leavingUser = await _userService.getUserById(userId);
      final leavingUserNickname = leavingUser?.nickname ?? '알 수 없는 사용자';

      // 매칭 중이었다면 리스너 정리
      if (group.status == GroupStatus.matching) {
        _stopMatchingListener(groupId);
        // 매칭 중인 그룹 나가기로 인한 리스너 정리
      }

      // 매칭된 상태에서 나가는 경우 채팅방에 시스템 메시지 전송 및 참여자 목록 업데이트
      if (group.status == GroupStatus.matched && group.matchedGroupId != null) {
        try {
          final chatRoomId = groupId.compareTo(group.matchedGroupId!) < 0
              ? '${groupId}_${group.matchedGroupId!}'
              : '${group.matchedGroupId!}_${groupId}';
          
          final chatroomService = ChatroomService();
          
          // 현재 채팅방 참여자 목록 가져오기
          final currentParticipants = await _getCurrentChatroomParticipants(chatRoomId);
          
          // 나가는 사용자를 참여자 목록에서 제거
          final updatedParticipants = currentParticipants.where((id) => id != userId).toList();
          
          // 채팅방 참여자 목록 업데이트 (FCM 알림 대상에서 제외하기 위함)
          await chatroomService.updateParticipants(
            chatRoomId: chatRoomId,
            participants: updatedParticipants,
          );
          debugPrint('채팅방 참여자 목록 업데이트: ${currentParticipants.length}명 → ${updatedParticipants.length}명');
          
          // 시스템 메시지 전송
          await chatroomService.sendSystemMessage(
            chatRoomId: chatRoomId,
            content: '$leavingUserNickname님이 채팅을 나갔습니다.',
            metadata: {'type': 'user_left', 'userId': userId},
          );
          
        } catch (e) {
          debugPrint('채팅방 참여자 목록 업데이트 실패: $e');
          // 시스템 메시지 실패는 그룹 나가기에 영향을 주지 않음
        }
      }

      // 매칭된 상태인 경우 상대방 그룹 정보도 업데이트 필요
      if (group.status == GroupStatus.matched && group.matchedGroupId != null) {
        await _handleMatchedGroupMemberLeave(groupId, group.matchedGroupId!, userId);
      }

      // 멤버가 1명인 경우 (그룹 소유자) - 그룹 삭제
      if (group.memberCount <= 1) {
        await _groupsCollection.doc(groupId).delete();
        // 그룹 삭제 완료: $groupId

        // [빠른손] 매칭 전 상태인 경우 임시 채팅방 삭제
        if (group.status != GroupStatus.matched) {
          await ChatroomService().deleteChatroom(groupId);
        }

        // 사용자의 현재 그룹 ID 제거
        await _userService.updateCurrentGroupId(userId, null);
        // 사용자의 currentGroupId 제거 완료
        
        return true;
      }

      // 멤버가 여러 명인 경우 - 멤버 목록에서 제거
      final updatedMemberIds = List<String>.from(group.memberIds)
        ..remove(userId);

      // 방장이 나가는 경우 새로운 방장 선정
      String newOwnerId = group.ownerId;
      if (group.ownerId == userId && updatedMemberIds.isNotEmpty) {
        newOwnerId = updatedMemberIds.first;
        // 새로운 방장 선정: $newOwnerId
      }

      // 그룹 정보 업데이트
      await _groupsCollection.doc(groupId).update({
        'memberIds': updatedMemberIds,
        'ownerId': newOwnerId,
        'memberCount': updatedMemberIds.length,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 사용자의 현재 그룹 ID 제거
      await _userService.updateCurrentGroupId(userId, null);
      // 사용자의 currentGroupId 제거 완료

      // 그룹에서 멤버 제거 완료. 남은 멤버수: ${updatedMemberIds.length}
      return true;
    } catch (e) {
      // 그룹 나가기 실패: $e
      return false;
    }
  }
  
  // 매칭된 그룹에서 멤버가 나갔을 때 상대방 그룹 상태 처리
  Future<void> _handleMatchedGroupMemberLeave(
      String leavingGroupId, String matchedGroupId, String leavingUserId) async {
    try {
      // 상대방 그룹 정보 가져오기
      final matchedGroupDoc = await _groupsCollection.doc(matchedGroupId).get();
      if (!matchedGroupDoc.exists) {
        // 매칭된 그룹을 찾을 수 없음: $matchedGroupId
        return;
      }
      
      final matchedGroup = GroupModel.fromFirestore(matchedGroupDoc);
      // 매칭된 그룹 현재 상태: ${matchedGroup.status}, 멤버수: ${matchedGroup.memberCount}
      
      // 채팅방에 참여했던 모든 사용자들에게 실시간 상태 변경 알림
      // (실제로는 ChatController나 다른 리스너에서 자동으로 감지될 것)

      // [빠른손] 매칭했던 그룹으로 실시간 상태 변경 알림
      await _groupsCollection.doc(matchedGroupId).update({
        'updatedAt': DateTime.now(),
      });

      // 필요에 따라 매칭 상태 해제나 다른 로직 추가 가능
      // 예: 한 그룹의 모든 멤버가 나가면 매칭 해제 등
      
    } catch (e) {
      // 매칭된 그룹 상태 처리 실패: $e
    }
  }

  // 현재 채팅방 참여자 목록 가져오기 (FCM 알림 대상 관리용)
  Future<List<String>> _getCurrentChatroomParticipants(String chatRoomId) async {
    try {
      final chatroomDoc = await _firebaseService.firestore
          .collection('chatrooms')
          .doc(chatRoomId)
          .get();
      
      if (chatroomDoc.exists) {
        final data = chatroomDoc.data();
        final participants = data?['participants'] as List<dynamic>?;
        return participants?.cast<String>() ?? [];
      }
      
      return [];
    } catch (e) {
      debugPrint('채팅방 참여자 목록 조회 실패: $e');
      return [];
    }
  }
}
