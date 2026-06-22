import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/candidate.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }
    return user.uid;
  }

  // Candidates
  static Future<void> saveCandidate(Candidate candidate) async {
    final uid = _userId;
    
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
    await _firestore.collection('users').doc(uid).collection('candidates').doc(candidateId).update({
      'pipelineStatus': status,
      'isShortlisted': isShortlisted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  static Future<void> deleteCandidate(String candidateId) async {
    final uid = _userId;
    await _firestore.collection('users').doc(uid).collection('candidates').doc(candidateId).delete();
  }

  // Storage
  static Future<String> uploadResumePdf(String fileName, List<int> bytes) async {
    final uid = _userId;
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
    await _firestore.collection('users').doc(uid).set({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getUserSettings() async {
    final uid = _userId;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data()!.containsKey('settings')) {
      return doc.data()!['settings'] as Map<String, dynamic>;
    }
    return null;
  }
}
