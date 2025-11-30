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

  CollectionReference<Map<String, dynamic>> get _groupsCollection =>
      _firebaseService.getCollection('groups');
  CollectionReference<Map<String, dynamic>> get _chatroomsCollection =>
      _firebaseService.getCollection('chatrooms');

  Stream<GroupModel?> getGroupStream(String groupId) {
    if (groupId.contains('_')) {
      return _chatroomsCollection.doc(groupId).snapshots().map((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          return GroupModel(
            id: doc.id,
            name: '매칭된 그룹',
            ownerId: (data['participants'] as List<dynamic>).first as String,
            memberIds: List<String>.from(data['participants'] as List<dynamic>),
            status: GroupStatus.matched,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            updatedAt: (data['createdAt'] as Timestamp).toDate(),
            maxMembers: 10,
          );
        }
        return null;
      });
    } else {
      return _groupsCollection.doc(groupId).snapshots().map((doc) {
        if (doc.exists) return GroupModel.fromFirestore(doc);
        return null;
      });
    }
  }
  
  Future<GroupModel?> getGroupById(String groupId) async {
    if (groupId.contains('_')) {
        return getMatchedGroupFromChatroom(groupId);
    }
    try {
      final doc = await _groupsCollection.doc(groupId).get();
      if (!doc.exists) return null;
      return GroupModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('그룹 정보를 가져오는데 실패했습니다: $e');
    }
  }

  Future<GroupModel> createGroup(String ownerId) async {
    try {
      final now = DateTime.now();
      final docRef = _groupsCollection.doc();
      final group = GroupModel(
        id: docRef.id,
        name: '새 그룹',
        ownerId: ownerId,
        memberIds: [ownerId],
        status: GroupStatus.waiting,
        createdAt: now,
        updatedAt: now,
        maxMembers: 5,
      );
      await docRef.set(group.toFirestore());
      await _userService.updateCurrentGroupId(ownerId, docRef.id);
      return group;
    } catch (e) {
      throw Exception('그룹 생성에 실패했습니다: $e');
    }
  }

  Future<List<UserModel>> getGroupMembers(String groupId) async {
    try {
      List<String> memberIds = [];
      if (groupId.contains('_')) {
        final doc = await _chatroomsCollection.doc(groupId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          memberIds = List<String>.from(data['participants'] ?? []);
        }
      } else {
        final doc = await _groupsCollection.doc(groupId).get();
        if (doc.exists) {
          final group = GroupModel.fromFirestore(doc);
          memberIds = group.memberIds;
        }
      }

      if (memberIds.isEmpty) return [];
      return await _getUsersByIds(memberIds);
    } catch (e) {
      throw Exception('그룹 멤버 정보를 가져오는데 실패했습니다: $e');
    }
  }
  
    Future<List<UserModel>> _getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final List<UserModel> allUsers = [];
      const batchSize = 30;
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batchIds = userIds.skip(i).take(batchSize).toList();
        
        final querySnapshot = await _firebaseService.firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        final batchUsers = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        allUsers.addAll(batchUsers);
      }

      return allUsers;
    } catch (e) {
      debugPrint('배치 사용자 조회 실패: $e');
      final members = await Future.wait(
        userIds.map((id) => _userService.getUserById(id)),
      );
      return members.whereType<UserModel>().toList();
    }
  }
  
  Future<GroupModel?> getUserCurrentGroup(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
      if (user?.currentGroupId == null) return null;

      final groupId = user!.currentGroupId!;
      if (groupId.contains('_')) {
        return getMatchedGroupFromChatroom(groupId);
      } else {
        return await getGroupById(groupId);
      }
    } catch (e) {
      throw Exception('현재 그룹 정보를 가져오는데 실패했습니다: $e');
    }
  }
  
  Future<GroupModel?> getMatchedGroupFromChatroom(String chatroomId) async {
    try {
      final doc = await _chatroomsCollection.doc(chatroomId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return GroupModel(
        id: doc.id,
        name: '매칭된 그룹',
        ownerId: (data['participants'] as List<dynamic>).first as String,
        memberIds: List<String>.from(data['participants'] as List<dynamic>),
        status: GroupStatus.matched,
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: (data['createdAt'] as Timestamp).toDate(),
        maxMembers: 10,
      );
    } catch (e) {
      throw Exception('매칭된 그룹 정보를 가져오는데 실패했습니다: $e');
    }
  }
  
    Future<void> startMatching(String groupId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'status': GroupStatus.matching.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('매칭 시작에 실패했습니다: $e');
    }
  }

  Future<void> cancelMatching(String groupId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'status': GroupStatus.waiting.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('매칭 취소에 실패했습니다: $e');
    }
  }
  
  Future<void> leaveGroup(String groupId, String userId) async {
    if(groupId.contains('_')) {
      // Logic to leave a matched group (chatroom)
      final chatroomRef = _chatroomsCollection.doc(groupId);
      await _firebaseService.runTransaction((transaction) async {
          final doc = await transaction.get(chatroomRef);
          if(doc.exists) {
            final List<String> participants = List<String>.from(doc.data()!['participants'] ?? []);
            participants.remove(userId);
            if(participants.isEmpty){
                transaction.delete(chatroomRef);
            } else {
                transaction.update(chatroomRef, {'participants': participants});
            }
          }
      });
       await _userService.updateCurrentGroupId(userId, null);

    } else {
      // Logic to leave a pre-match group
      final groupRef = _groupsCollection.doc(groupId);
       await _firebaseService.runTransaction((transaction) async {
           final doc = await transaction.get(groupRef);
           if(doc.exists) {
             final group = GroupModel.fromFirestore(doc);
             final newMemberIds = group.memberIds.where((id) => id != userId).toList();
             if(newMemberIds.isEmpty) {
                transaction.delete(groupRef);
             } else {
               transaction.update(groupRef, {
                 'memberIds': newMemberIds,
                 'ownerId': newMemberIds.first, // Simple reassignment
               });
             }
           }
       });
       await _userService.updateCurrentGroupId(userId, null);
    }
  }
}
