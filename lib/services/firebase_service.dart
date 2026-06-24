import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/candidate.dart';
import '../models/app_user.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _userId {
    return _auth.currentUser?.uid;
  }

  // Candidates
  static Future<void> saveCandidate(Candidate candidate) async {
    final uid = _userId;
    if (uid == null) return;
    
    final collectionRef = _firestore.collection('users').doc(uid).collection('candidates');
    final docRef = candidate.id == null ? collectionRef.doc() : collectionRef.doc(candidate.id);
    
    candidate.id = docRef.id;
    
    await docRef.set({
      ...candidate.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<Candidate>> getCandidates() async {
    final uid = _userId;
    if (uid == null) return [];
    
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('candidates')
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Candidate.fromJson(doc.data(), doc.id)).toList();
  }

  static Future<void> updateCandidateStatus(String candidateId, String status, bool isShortlisted) async {
    final uid = _userId;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).collection('candidates').doc(candidateId).update({
      'pipelineStatus': status,
      'isShortlisted': isShortlisted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  static Future<void> deleteCandidate(String candidateId) async {
    final uid = _userId;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).collection('candidates').doc(candidateId).delete();
  }

  // Storage
  static Future<String> uploadResumePdf(String fileName, List<int> bytes) async {
    final uid = _userId;
    if (uid == null) return '';
    
    final safeFileName = '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.\-]'), '_')}';
    final ref = _storage.ref().child('users/$uid/resumes/$safeFileName');
    
    final metadata = SettableMetadata(contentType: 'application/pdf');
    final uploadTask = ref.putData(Uint8List.fromList(bytes), metadata);
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Settings / API Keys
  static Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    final uid = _userId;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getUserSettings() async {
    final uid = _userId;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data()!.containsKey('settings')) {
      return doc.data()!['settings'] as Map<String, dynamic>;
    }
    return null;
  }

  // Admin & User Profiles
  static Future<AppUser> syncUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return AppUser(uid: 'local', email: 'local@app.com', tokensUsed: 0, monthlyQuota: 9999, isBlocked: false, isAdmin: true);
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      // First time login
      // TODO: Replace with your exact email address for security
      final bool isAdmin = user.email == 'akhan110@gmail.com'; 
      final appUser = AppUser(
        uid: user.uid,
        email: user.email ?? '',
        tokensUsed: 0,
        monthlyQuota: 50,
        isBlocked: false,
        isAdmin: isAdmin,
      );
      await docRef.set(appUser.toJson());
      return appUser;
    } else {
      // Retroactive admin check for existing users
      bool shouldBeAdmin = user.email == 'akhan110@gmail.com';
      var appUser = AppUser.fromJson(doc.data()!, doc.id);
      
      if (shouldBeAdmin && !appUser.isAdmin) {
        await docRef.update({'isAdmin': true});
        appUser = AppUser(
          uid: appUser.uid,
          email: appUser.email,
          tokensUsed: appUser.tokensUsed,
          monthlyQuota: appUser.monthlyQuota,
          isBlocked: appUser.isBlocked,
          isAdmin: true,
          createdAt: appUser.createdAt,
        );
      }
      return appUser;
    }
  }

  static Future<AppUser> getCurrentUserProfile() async {
    final uid = _userId;
    if (uid == null) return await syncUserProfile();
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return await syncUserProfile();
    return AppUser.fromJson(doc.data()!, doc.id);
  }

  static Future<void> incrementTokenUsage(int amount) async {
    final uid = _userId;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'tokensUsed': FieldValue.increment(amount),
    });
  }

  static Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => AppUser.fromJson(doc.data(), doc.id)).toList();
  }

  static Future<void> updateUserStatus(String targetUid, {bool? isBlocked, int? monthlyQuota}) async {
    final Map<String, dynamic> updates = {};
    if (isBlocked != null) updates['isBlocked'] = isBlocked;
    if (monthlyQuota != null) updates['monthlyQuota'] = monthlyQuota;
    
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(targetUid).update(updates);
    }
  }
}
