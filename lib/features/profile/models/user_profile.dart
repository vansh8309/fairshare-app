import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String? email;
  final String? phone;
  final String? profilePicUrl;
  final DateTime? createdAt;
  String? themePreference; // Added theme preference
  String? currencyPreference; // Added currency preference

  UserProfile({
    required this.uid,
    required this.name,
    this.email,
    this.phone,
    this.profilePicUrl,
    this.createdAt,
    this.themePreference = 'system', // Default to system
    this.currencyPreference = 'INR',
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      name: data['name'] as String? ?? 'Unknown User',
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      profilePicUrl: data['profilePicUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      themePreference: data['themePreference'] as String? ?? 'system',
      currencyPreference: data['currencyPreference'] as String? ?? 'USD',
    );
  }

   factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
     return UserProfile(
       uid: uid,
       name: data['name'] as String? ?? 'Unknown User',
       email: data['email'] as String?,
       phone: data['phone'] as String?,
       profilePicUrl: data['profilePicUrl'] as String?,
       createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
       themePreference: data['themePreference'] as String? ?? 'system',
       currencyPreference: data['currencyPreference'] as String? ?? 'USD',
     );
   }

   Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'profilePicUrl': profilePicUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'themePreference': themePreference,
      'currencyPreference': currencyPreference,
    };
  }
}