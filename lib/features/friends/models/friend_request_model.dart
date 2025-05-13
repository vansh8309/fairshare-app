import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus { pending, accepted, declined, cancelled }

class FriendRequest {
  final String id;
  final String senderUid;
  final String senderName;
  final String? senderProfilePicUrl;
  final String receiverUid;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendRequest({
    required this.id,
    required this.senderUid,
    required this.senderName,
    this.senderProfilePicUrl,
    required this.receiverUid,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  static FriendRequestStatus _statusFromString(String? statusString) {
    switch (statusString?.toLowerCase()) {
      case 'accepted': return FriendRequestStatus.accepted;
      case 'declined': return FriendRequestStatus.declined;
      case 'cancelled': return FriendRequestStatus.cancelled;
      case 'pending':
      default:
        return FriendRequestStatus.pending;
    }
  }

   String get statusString => status.name;


  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return FriendRequest(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Unknown Sender',
      senderProfilePicUrl: data['senderProfilePicUrl'] as String?,
      receiverUid: data['receiverUid'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'senderProfilePicUrl': senderProfilePicUrl,
      'receiverUid': receiverUid,
      'status': statusString,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}