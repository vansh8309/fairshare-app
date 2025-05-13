import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String groupName;
  final String groupType;
  final String createdBy;
  final DateTime createdAt;
  final List<String> members;
  final String currencyCode;
  final DateTime? lastActivityAt;
  final String? groupImageUrl;

  Group({
    required this.id,
    required this.groupName,
    required this.groupType,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.currencyCode,
    this.lastActivityAt,
    this.groupImageUrl,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    return Group(
      id: doc.id,
      groupName: data['groupName'] as String? ?? 'Unnamed Group',
      groupType: data['groupType'] as String? ?? 'Other',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      members: List<String>.from(data['members'] as List? ?? []),
      currencyCode: data['currencyCode'] as String? ?? 'INR',
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate(),
      groupImageUrl: data['groupImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'groupType': groupType,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members,
      'currencyCode': currencyCode,
      'lastActivityAt': lastActivityAt != null ? Timestamp.fromDate(lastActivityAt!) : null,
      'groupImageUrl': groupImageUrl,
    };
  }
}