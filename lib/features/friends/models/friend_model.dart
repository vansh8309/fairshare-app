import 'package:cloud_firestore/cloud_firestore.dart';

class Friend {
  final String uid;
  final String name;
  final String? profilePicUrl;
  final DateTime addedAt;

  Friend({
    required this.uid,
    required this.name,
    this.profilePicUrl,
    required this.addedAt,
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return Friend(
      uid: doc.id,
      name: data['name'] as String? ?? 'Unknown',
      profilePicUrl: data['profilePicUrl'] as String?,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'profilePicUrl': profilePicUrl,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}