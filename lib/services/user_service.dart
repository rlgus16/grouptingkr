import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // 사용자 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firebaseService.getCollection('users');

  // 사용자 ID로 사용자 정보 가져오기 (재시도 로직 포함)
  Future<UserModel?> getUserById(String userId, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('UserService: 사용자 조회 시도 ($attempt/$maxRetries) - UID: $userId');
        
        // Firestore에서 문서 가져오기
        final doc = await _usersCollection.doc(userId).get();
        print('UserService: 문서 존재 여부: ${doc.exists}');
        
        // 문서가 존재하지 않거나 데이터가 null인 경우 null 반환
        if (!doc.exists || doc.data() == null) {
          print('UserService: 문서가 존재하지 않거나 데이터가 null입니다 - UID: $userId');
          return null;
        }
        
        // print('UserService: 문서 데이터: ${doc.data()}');
        final user = UserModel.fromFirestore(doc);
        print('UserService: 사용자 조회 성공 - 닉네임: ${user.nickname.isNotEmpty ? user.nickname : "프로필 미완성"}');
        return user;
      } catch (e) {
        print('UserService: 사용자 조회 실패 (시도 $attempt/$maxRetries) - $e');
        
        if (attempt == maxRetries) {
          // 최종 실패
          throw Exception('사용자 정보를 가져오는데 실패했습니다: $e');
        }
        
        // 재시도 전 잠시 대기
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    
    return null; // 이 코드는 실행되지 않지만 타입 안전성을 위해 추가
  }

  // 닉네임으로 사용자 검색
  Future<UserModel?> getUserByNickname(String nickname) async {
    try {
      final query = await _usersCollection
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return UserModel.fromFirestore(query.docs.first);
    } catch (e) {
      throw Exception('사용자 검색에 실패했습니다: $e');
    }
  }

  // 사용자 정보 업데이트
  Future<void> updateUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).update(user.toFirestore());
    } catch (e) {
      throw Exception('사용자 정보 업데이트에 실패했습니다: $e');
    }
  }

  // 사용자 생성
  Future<void> createUser(UserModel user) async {
    try {
      // print('UserService: 사용자 생성 시도 - UID: ${user.uid}');
      // print('UserService: 현재 Firebase Auth 사용자: ${_firebaseService.currentUser?.uid}');
      // print('UserService: 사용자 이메일: ${_firebaseService.currentUser?.email}');
      
      // 현재 인증된 사용자와 생성하려는 사용자 UID가 일치하는지 확인
      if (_firebaseService.currentUser?.uid != user.uid) {
        throw Exception('인증된 사용자와 생성하려는 사용자가 일치하지 않습니다.');
      }
      
      // ID 토큰 확인
      try {
        final idToken = await _firebaseService.currentUser?.getIdToken();
        // print('UserService: ID 토큰 존재 여부: ${idToken != null}');
        if (idToken != null) {
          // print('UserService: ID 토큰 길이: ${idToken.length}');
        }
      } catch (e) {
        // print('UserService: ID 토큰 확인 실패: $e');
      }
      
      // print('UserService: Firestore 컬렉션 경로: ${_usersCollection.path}');
      // print('UserService: 생성할 문서 데이터: ${user.toFirestore()}');
      
      await _usersCollection.doc(user.uid).set(user.toFirestore());
      // print('UserService: 사용자 생성 성공');
    } catch (e) {
      // print('UserService: 사용자 생성 실패 - $e');
      throw Exception('사용자 생성에 실패했습니다: $e');
    }
  }

  // 여러 사용자 정보 가져오기
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];

      final List<UserModel> users = [];

      // Firestore에서는 in 쿼리가 최대 10개까지만 가능하므로 청크로 나누어 처리
      const chunkSize = 10;
      for (int i = 0; i < userIds.length; i += chunkSize) {
        final chunk = userIds.skip(i).take(chunkSize).toList();
        final query = await _usersCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in query.docs) {
          users.add(UserModel.fromFirestore(doc));
        }
      }

      return users;
    } catch (e) {
      throw Exception('사용자 목록을 가져오는데 실패했습니다: $e');
    }
  }

  // 사용자 삭제
  Future<void> deleteUser(String userId) async {
    try {
      await _usersCollection.doc(userId).delete();
    } catch (e) {
      throw Exception('사용자 삭제에 실패했습니다: $e');
    }
  }

  // 사용자 존재 여부 확인
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // 사용자의 현재 그룹 ID 업데이트
  Future<void> updateCurrentGroupId(String userId, String? groupId) async {
    try {
      await _usersCollection.doc(userId).update({
        'currentGroupId': groupId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('그룹 ID 업데이트에 실패했습니다: $e');
    }
  }

  // 닉네임으로 사용자 검색 (여러 결과 - 부분 일치)
  Future<List<UserModel>> searchUsersByNickname(String nickname) async {
    try {
      final query = await _usersCollection
          .where('nickname', isGreaterThanOrEqualTo: nickname)
          .where('nickname', isLessThan: '${nickname}z')
          .limit(10)
          .get();

      return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('사용자 검색에 실패했습니다: $e');
    }
  }

  // 정확한 닉네임으로 사용자 검색
  Future<UserModel?> getUserByExactNickname(String nickname) async {
    try {
      final query = await _usersCollection
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return UserModel.fromFirestore(query.docs.first);
    } catch (e) {
      throw Exception('사용자 검색에 실패했습니다: $e');
    }
  }

  // 사용자 컬렉션 참조 getter (서비스 내부에서 사용)
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _usersCollection;
}
