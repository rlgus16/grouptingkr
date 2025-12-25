import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Getters
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;
  FirebaseStorage get storage => _storage;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  // Auth Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Collections
  CollectionReference<Map<String, dynamic>> get users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get messages =>
      _firestore.collection('messages');
  CollectionReference<Map<String, dynamic>> get invitations =>
      _firestore.collection('invitations');

  // Helper methods
  CollectionReference<Map<String, dynamic>> getCollection(String path) =>
      _firestore.collection(path);
  DocumentReference<Map<String, dynamic>> getDocument(String path) =>
      _firestore.doc(path);
  Future<T> runTransaction<T>(TransactionHandler<T> updateFunction) =>
      _firestore.runTransaction(updateFunction);
  WriteBatch batch() => _firestore.batch();

  // Auth methods
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    Duration? timeout,
  }) => _auth.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    verificationCompleted: verificationCompleted,
    verificationFailed: verificationFailed,
    codeSent: codeSent,
    codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    timeout: timeout ?? const Duration(seconds: 60),
  );

  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) =>
      _auth.signInWithCredential(credential);

  Future<void> signOut() => _auth.signOut();

  /// 비밀번호 재설정 이메일 발송
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // Storage methods
  Reference getStorageRef(String path) => _storage.ref(path);
}
