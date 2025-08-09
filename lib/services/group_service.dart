import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';
import 'realtime_chat_service.dart';
import 'dart:async'; // Added for StreamSubscription

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
      // print('매칭 시작: $groupId');

      // 1. 그룹 상태를 매칭 중으로 변경
      await _groupsCollection.doc(groupId).update({
        'status': GroupStatus.matching.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // print('그룹 상태를 매칭 중으로 변경 완료');

      // 2. 매칭 가능한 그룹 찾기 (초기 시도)
      await _findAndMatchGroups(groupId);
      
      // 3. 실시간 매칭 감지 시작 (새로운 추가!)
      _startMatchingListener(groupId);
    } catch (e) {
      // print('매칭 시작 실패: $e');
      throw Exception('매칭 시작에 실패했습니다: $e');
    }
  }

  // 실시간 매칭 감지 리스너 추가
  static final Map<String, StreamSubscription> _matchingListeners = {};
  
  void _startMatchingListener(String groupId) {
    // 기존 리스너가 있다면 제거
    _matchingListeners[groupId]?.cancel();
    
    // print('실시간 매칭 감지 시작: $groupId');
    
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
              // print('그룹 $groupId가 더 이상 매칭 중이 아님. 리스너 정지');
              _stopMatchingListener(groupId);
              return;
            }
            
            // 변화된 그룹들 중에서 새로 추가된 그룹만 확인
            bool hasNewGroup = false;
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added && 
                  change.doc.id != groupId) {
                hasNewGroup = true;
                // print('새로운 매칭 그룹 발견: ${change.doc.id}');
                break;
              }
            }
            
            // 새로운 그룹이 추가된 경우에만 매칭 재시도
            if (hasNewGroup) {
              // print('새로운 매칭 가능 그룹으로 인한 매칭 재시도: $groupId');
              await _findAndMatchGroups(groupId);
            }
          } catch (e) {
            // print('실시간 매칭 처리 중 오류: $e');
          }
        });
        
    _matchingListeners[groupId] = listener;
  }
  
  void _stopMatchingListener(String groupId) {
    _matchingListeners[groupId]?.cancel();
    _matchingListeners.remove(groupId);
    // print('매칭 리스너 정지: $groupId');
  }

  // 모든 매칭 리스너 정리 (앱 종료 시 사용)
  static void stopAllMatchingListeners() {
    // print('모든 매칭 리스너 정리 중...');
    for (final listener in _matchingListeners.values) {
      listener.cancel();
    }
    _matchingListeners.clear();
    // print('모든 매칭 리스너 정리 완료');
  }

  // 디버깅용: 현재 매칭 중인 그룹들 확인
  Future<void> debugMatchingGroups() async {
    try {
      final query = await _groupsCollection
          .where('status', isEqualTo: GroupStatus.matching.toString().split('.').last)
          .get();
      
      // print('=== 현재 매칭 중인 그룹들 ===');
      // print('총 ${query.docs.length}개 그룹이 매칭 대기 중');
      
      for (final doc in query.docs) {
        final group = GroupModel.fromFirestore(doc);
        final members = await getGroupMembers(group.id);
        // print('그룹 ${group.id}:');
        // print('  - 멤버 수: ${group.memberCount}');
        // print('  - 멤버들: ${members.map((m) => m.nickname).join(', ')}');
        if (members.isNotEmpty) {
          // print('  - 활동지역: ${members.first.activityArea}');
        }
      }
      // print('==========================');
    } catch (e) {
      // print('매칭 그룹 디버깅 실패: $e');
    }
  }

  // 매칭 가능한 그룹을 찾아서 매칭 처리
  Future<void> _findAndMatchGroups(String groupId) async {
    try {
      // 현재 그룹 정보 가져오기
      final currentGroup = await getGroupById(groupId);
      if (currentGroup == null) {
        // print('현재 그룹을 찾을 수 없음: $groupId');
        return;
      }

      // 이미 매칭된 그룹인지 다시 한번 확인
      if (currentGroup.status != GroupStatus.matching) {
        // print('그룹 $groupId이 더 이상 매칭 중이 아님: ${currentGroup.status}');
        return;
      }

      // print('현재 그룹 정보: 멤버수=${currentGroup.memberCount}');
      
      // 1:1 매칭인지 그룹 매칭인지 확인
      if (currentGroup.memberCount == 1) {
        // print('1:1 매칭 모드로 진행');
      } else {
        // print('그룹 매칭 모드로 진행 (${currentGroup.memberCount}명)');
      }

      // 현재 그룹의 멤버들 정보 가져오기
      final currentMembers = await getGroupMembers(groupId);
      if (currentMembers.isEmpty) {
        // print('현재 그룹 멤버가 없음');
        return;
      }

      // 대표 활동지역 (첫 번째 멤버의 활동지역 사용)
      final activityArea = currentMembers.first.activityArea;
      // print('활동지역: $activityArea');

      // 매칭 가능한 그룹들 찾기
      final matchableGroups = await findMatchableGroups(
        currentGroup.memberCount,
        activityArea,
        groupId,
      );

      // print('매칭 가능한 그룹 수: ${matchableGroups.length}');
      
      // 1:1 매칭 특별 디버깅 [주석 필요]
      if (currentGroup.memberCount == 1) {
        // print('=== 1:1 매칭 디버깅 정보 ===');
        // print('현재 그룹 ID: $groupId');
        // print('현재 그룹 활동지역: $activityArea');
        // print('현재 그룹 멤버 수: ${currentGroup.memberCount}');
        // print('매칭 대기 중인 1:1 그룹들:');
        for (int i = 0; i < matchableGroups.length; i++) {
          final group = matchableGroups[i];
          // print('  - 그룹 ${i+1}: ID=${group.id}, 멤버수=${group.memberCount}');
        }
      }

      if (matchableGroups.isNotEmpty) {
        // 첫 번째 매칭 가능한 그룹과 매칭 시도 (트랜잭션으로 안전하게 처리)
        final targetGroup = matchableGroups.first;
        // print('매칭 대상 그룹: ${targetGroup.id} (멤버수: ${targetGroup.memberCount})');

        final success = await _safeCompleteMatching(groupId, targetGroup.id);
        
        if (success) {
          if (currentGroup.memberCount == 1 && targetGroup.memberCount == 1) {
            // print('1:1 매칭 완료: $groupId ↔ ${targetGroup.id}');
          } else {
            // print('그룹 매칭 완료: $groupId (${currentGroup.memberCount}명) ↔ ${targetGroup.id} (${targetGroup.memberCount}명)');
          }
        } else {
          // print('매칭 시도 실패 (이미 다른 그룹과 매칭되었을 수 있음)');
        }
      } else {
        if (currentGroup.memberCount == 1) {
          // print('1:1 매칭 가능한 상대가 없음. 대기 상태 유지');
        } else {
          // print('그룹 매칭 가능한 그룹이 없음. 대기 상태 유지');
        }
      }
    } catch (e) {
      // print('매칭 처리 실패: $e');
    }
  }

  // 안전한 매칭 완료 처리 (중복 매칭 방지)
  Future<bool> _safeCompleteMatching(String groupId1, String groupId2) async {
    try {
      bool success = false;
      String? failureReason;
      
      // print('매칭 트랜잭션 시작: $groupId1 ↔ $groupId2');
      
      await _firebaseService.runTransaction((transaction) async {
        // 두 그룹의 현재 상태 확인
        final group1Doc = await transaction.get(_groupsCollection.doc(groupId1));
        final group2Doc = await transaction.get(_groupsCollection.doc(groupId2));
        
        if (!group1Doc.exists || !group2Doc.exists) {
          failureReason = '그룹 중 하나가 존재하지 않음 (Group1: ${group1Doc.exists}, Group2: ${group2Doc.exists})';
          // print('매칭 트랜잭션 실패: $failureReason');
          return;
        }
        
        final group1 = GroupModel.fromFirestore(group1Doc);
        final group2 = GroupModel.fromFirestore(group2Doc);
        
        // 두 그룹 모두 매칭 중인지 확인
        if (group1.status != GroupStatus.matching || group2.status != GroupStatus.matching) {
          failureReason = '그룹 중 하나가 이미 매칭되었거나 매칭 중이 아님 (Group1: ${group1.status}, Group2: ${group2.status})';
          // print('매칭 트랜잭션 실패: $failureReason');
          return;
        }
        
        // print('트랜잭션 검증 완료 - 두 그룹 모두 매칭 상태 확인됨');
        
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
        
        // print('Group1 업데이트 데이터: $group1Update');
        // print('Group2 업데이트 데이터: $group2Update');

        transaction.update(_groupsCollection.doc(groupId1), group1Update);
        transaction.update(_groupsCollection.doc(groupId2), group2Update);
        
        success = true;
        // print('매칭 트랜잭션 성공');
      });
      
      if (success) {
        // print('매칭 트랜잭션 완료 - 후속 처리 시작');
        
        // 매칭 성공시 리스너 정지
        _stopMatchingListener(groupId1);
        _stopMatchingListener(groupId2);
        // print('매칭 리스너 정지 완료');
        
        // 매칭 완료 시스템 메시지 전송
        try {
          final chatRoomId = groupId1.compareTo(groupId2) < 0
              ? '${groupId1}_${groupId2}'
              : '${groupId2}_${groupId1}';
          
          // print('매칭 완료 - 채팅방 ID: $chatRoomId');
          
          // 실시간 채팅 서비스 초기화 및 환영 메시지 전송
          final realtimeChatService = RealtimeChatService();
          await realtimeChatService.initializeChatRoom(chatRoomId);
          // print('채팅방 초기화 완료');
          
          await realtimeChatService.sendSystemMessage(
            groupId: chatRoomId,
            content: '매칭이 완료되었습니다! 서로 인사해보세요 👋',
          );
          // print('매칭 완료 시스템 메시지 전송 완료');
        } catch (e) {
          // print('매칭 완료 시스템 메시지 전송 실패: $e');
          // 시스템 메시지 실패는 매칭 성공에 영향을 주지 않음
        }
        
        // print('매칭 완료 처리 모든 단계 성공');
      } else {
        // print('매칭 트랜잭션 실패 - 이유: ${failureReason ?? "알 수 없는 이유"}');
      }
      
      return success;
    } catch (e) {
      // print('안전한 매칭 완료 처리 실패: $e');
      // print('에러 타입: ${e.runtimeType}');
      
      // Firebase 관련 에러인 경우 추가 정보 출력
      if (e.toString().contains('permission-denied')) {
        // print('권한 거부 에러 - Firestore 규칙을 확인하세요');
        // print('매칭 상태에서 matched 상태로 업데이트 권한이 필요합니다');
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
      // print('매칭 가능한 그룹 찾기 시작');
      // print(
      //   '찾는 조건 - 멤버수: $memberCount, 활동지역: $activityArea, 제외그룹: $excludeGroupId',
      // );

      final query = await _groupsCollection
          .where(
            'status',
            isEqualTo: GroupStatus.matching.toString().split('.').last,
          )
          .get();

      // print('매칭 중인 그룹 총 ${query.docs.length}개 발견');

      final groups = query.docs
          .map((doc) => GroupModel.fromFirestore(doc))
          .where((group) => group.id != excludeGroupId) // 자기 그룹 제외
          .toList();

      // print('자기 그룹 제외 후: ${groups.length}개');

      for (int i = 0; i < groups.length; i++) {
        final g = groups[i];
        // print('그룹 $i: ID=${g.id}, 멤버수=${g.memberCount}, 상태=${g.status}');
      }

      // 매칭 조건을 만족하는 그룹들 필터링 (1:1 매칭 포함)
      final matchableGroups = <GroupModel>[];

      for (final group in groups) {
        // print('그룹 ${group.id} 검사 중...');
        // print(
        //   '- 멤버수 비교: ${group.memberCount} vs $memberCount',
        // );

        // 1:1 매칭 또는 같은 인원 수 매칭 허용
        bool canMatchBySize = false;
        if (memberCount == 1 && group.memberCount == 1) {
          // 1:1 매칭
          canMatchBySize = true;
          // print('- 1:1 매칭 가능');
        } else if (memberCount > 1 && group.memberCount == memberCount) {
          // 같은 인원 수 그룹 매칭
          canMatchBySize = true;
          // print('- 같은 인원 수 매칭 가능');
        }

        if (canMatchBySize) {
          // 그룹 멤버들 정보 가져오기
          // print('- 멤버 정보 가져오는 중: ${group.memberIds}');
          final members = await Future.wait(
            group.memberIds.map((id) => _userService.getUserById(id)),
          );

          final validMembers = members.whereType<UserModel>().toList();
          // print('- 유효한 멤버 수: ${validMembers.length}');

          if (validMembers.isEmpty) {
            // print('- 건너뜀: 유효한 멤버 없음');
            continue;
          }

          // 활동지역 매칭 확인
          // print('- 멤버들의 활동지역:');
          for (final member in validMembers) {
            // print('  * ${member.nickname}: ${member.activityArea}');
          }

          final hasMatchingArea = validMembers.any(
            (member) => member.activityArea == activityArea,
          );

          // print('- 활동지역 매칭: $hasMatchingArea');

          // 1:1 매칭의 경우 활동지역 조건을 더 유연하게 처리
          bool shouldMatch = false;
          if (memberCount == 1 && group.memberCount == 1) {
            // 1:1 매칭은 활동지역이 다르더라도 매칭 허용 (테스트용)
            shouldMatch = true;
            // print('- 1:1 매칭: 활동지역 조건 완화하여 매칭 허용');
          } else {
            // 그룹 매칭은 기존대로 활동지역 일치 필요
            shouldMatch = hasMatchingArea;
          }

          if (shouldMatch) {
            // print('- 매칭 가능한 그룹으로 추가!');
            matchableGroups.add(group);
          } else {
            // print('- 건너뜀: 활동지역 불일치');
          }
        } else {
          // print('- 건너뜀: 멤버수 불일치');
        }
      }

      // print('최종 매칭 가능한 그룹 수: ${matchableGroups.length}');
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

  // 그룹 멤버 정보 가져오기 (매칭된 그룹 멤버 포함)
  Future<List<UserModel>> getGroupMembers(String groupId) async {
    try {
      final group = await getGroupById(groupId);
      if (group == null) return [];

      List<String> allMemberIds = List.from(group.memberIds);

      // 매칭된 그룹이 있으면 매칭된 그룹의 멤버들도 포함
      if (group.status == GroupStatus.matched && group.matchedGroupId != null) {
        // print('매칭된 그룹 멤버도 포함: ${group.matchedGroupId}');
        final matchedGroup = await getGroupById(group.matchedGroupId!);
        if (matchedGroup != null) {
          allMemberIds.addAll(matchedGroup.memberIds);
          // print('전체 멤버 ID: $allMemberIds');
        }
      }

      final members = await Future.wait(
        allMemberIds.map((id) => _userService.getUserById(id)),
      );

      final validMembers = members.whereType<UserModel>().toList();
      // print('로드된 멤버 수: ${validMembers.length}');

      return validMembers;
    } catch (e) {
      throw Exception('그룹 멤버 정보를 가져오는데 실패했습니다: $e');
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
      // print('그룹 나가기 시작: 그룹ID=$groupId, 사용자ID=$userId');

      // 그룹 정보 가져오기
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        // print('그룹을 찾을 수 없음: $groupId');
        return false;
      }

      final group = GroupModel.fromFirestore(groupDoc);
      // print('현재 그룹 상태: ${group.status}, 멤버수: ${group.memberCount}');

      // 나가는 사용자 정보 가져오기 (시스템 메시지용)
      final leavingUser = await _userService.getUserById(userId);
      final leavingUserNickname = leavingUser?.nickname ?? '알 수 없는 사용자';

      // 매칭 중이었다면 리스너 정리
      if (group.status == GroupStatus.matching) {
        _stopMatchingListener(groupId);
        // print('매칭 중인 그룹 나가기로 인한 리스너 정리');
      }

      // 매칭된 상태에서 나가는 경우 채팅방에 시스템 메시지 전송
      if (group.status == GroupStatus.matched && group.matchedGroupId != null) {
        try {
          final chatRoomId = groupId.compareTo(group.matchedGroupId!) < 0
              ? '${groupId}_${group.matchedGroupId!}'
              : '${group.matchedGroupId!}_${groupId}';
          
          final realtimeChatService = RealtimeChatService();
          await realtimeChatService.sendSystemMessage(
            groupId: chatRoomId,
            content: '$leavingUserNickname님이 채팅을 나갔습니다.',
          );
          // print('사용자 나가기 시스템 메시지 전송 완료');
        } catch (e) {
          // print('시스템 메시지 전송 실패: $e');
          // 시스템 메시지 실패는 그룹 나가기에 영향을 주지 않음
        }
      }

      // 멤버가 1명인 경우 (그룹 소유자) - 그룹 삭제
      if (group.memberCount <= 1) {
        // print('마지막 멤버 나가기 - 그룹 삭제');
        await _groupsCollection.doc(groupId).delete();
        // print('그룹 삭제 완료: $groupId');
        
        // 사용자의 현재 그룹 ID 제거
        await _userService.updateCurrentGroupId(userId, null);
        // print('사용자의 currentGroupId 제거 완료');
        
        return true;
      }

      // 멤버가 여러 명인 경우 - 멤버 목록에서 제거
      final updatedMemberIds = List<String>.from(group.memberIds)
        ..remove(userId);

      // 방장이 나가는 경우 새로운 방장 선정
      String newOwnerId = group.ownerId;
      if (group.ownerId == userId && updatedMemberIds.isNotEmpty) {
        newOwnerId = updatedMemberIds.first;
        // print('새로운 방장 선정: $newOwnerId');
      }

      await _groupsCollection.doc(groupId).update({
        'memberIds': updatedMemberIds,
        'ownerId': newOwnerId,
        'memberCount': updatedMemberIds.length,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 사용자의 현재 그룹 ID 제거
      await _userService.updateCurrentGroupId(userId, null);
      // print('사용자의 currentGroupId 제거 완료');

      // print('그룹에서 멤버 제거 완료. 남은 멤버수: ${updatedMemberIds.length}');
      return true;
    } catch (e) {
      // print('그룹 나가기 실패: $e');
      return false;
    }
  }
}
