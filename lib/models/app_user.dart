import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final int tokensUsed;
  final int monthlyQuota;
  final bool isBlocked;
  final bool isAdmin;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.tokensUsed,
    required this.monthlyQuota,
    required this.isBlocked,
    required this.isAdmin,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json, String id) {
    return AppUser(
      uid: id,
      email: json['email'] ?? '',
      tokensUsed: json['tokensUsed'] ?? 0,
      monthlyQuota: json['monthlyQuota'] ?? 50,
      isBlocked: json['isBlocked'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'tokensUsed': tokensUsed,
      'monthlyQuota': monthlyQuota,
      'isBlocked': isBlocked,
      'isAdmin': isAdmin,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
