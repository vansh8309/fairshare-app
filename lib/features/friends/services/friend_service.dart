import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fair_share/features/friends/models/friend_model.dart';
import 'package:fair_share/features/friends/models/friend_request_model.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  String? get _currentUserId => _auth.currentUser?.uid;
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _requestsCollection => _firestore.collection('friend_requests');

  Stream<List<Friend>> getFriendsStream() {
    final String? userId = _currentUserId;
    if (userId == null) {
      print("FriendService: Cannot get friends stream, user not logged in.");
      return Stream.value([]);
    }
    try {
      return _usersCollection.doc(userId).collection('friends')
          .orderBy('addedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) => Friend.fromFirestore(doc)).toList();
          })
          .handleError((error) {
            print("FriendService: Error in getFriendsStream: $error");
            return [];
          });
    } catch (e) {
       print("FriendService: Exception setting up friend stream: $e");
       return Stream.value([]);
    }
  }

  Stream<List<FriendRequest>> getSentFriendRequestsStream() {
    final String? userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    try {
      return _requestsCollection
          .where('senderUid', isEqualTo: userId)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
             return snapshot.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList();
           })
          .handleError((error) {
            print("FriendService: Error in getSentFriendRequestsStream: $error");
             if (error is FirebaseException && error.code == 'failed-precondition') {
                print("FriendService: Query likely requires Firestore index on (senderUid, status, createdAt). Check Firestore console.");
             }
            return [];
          });
    } catch (e) {
        print("FriendService: Exception setting up sent friend request stream: $e");
        return Stream.value([]);
    }
  }

  Future<bool> cancelFriendRequest(String requestId) async {
     final String? myUid = _currentUserId;
     if (myUid == null) return false;
     try {
        await _requestsCollection.doc(requestId).delete();
        print("FriendService: Cancelled friend request ID: $requestId");
        return true;
     } catch (e) {
        print("FriendService: Error cancelling friend request: $e");
        return false;
     }
  }

  Future<bool> sendFriendRequest(String receiverUid) async {
    final String? senderUid = _currentUserId;
    if (senderUid == null || receiverUid.isEmpty || senderUid == receiverUid) {
      print("FriendService: Cannot send request - invalid input or self-request.");
      return false;
    }

    try {
      final friendDoc = await _usersCollection.doc(senderUid).collection('friends').doc(receiverUid).get();
      if (friendDoc.exists) {
        print("FriendService: Already friends with $receiverUid.");
        return false;
      }

      final sentQuery = await _requestsCollection.where('senderUid', isEqualTo: senderUid).where('receiverUid', isEqualTo: receiverUid).where('status', isEqualTo: FriendRequestStatus.pending.name).limit(1).get();
      final receivedQuery = await _requestsCollection.where('senderUid', isEqualTo: receiverUid).where('receiverUid', isEqualTo: senderUid).where('status', isEqualTo: FriendRequestStatus.pending.name).limit(1).get();

      if (sentQuery.docs.isNotEmpty || receivedQuery.docs.isNotEmpty) {
         print("FriendService: Pending friend request already exists between $senderUid and $receiverUid.");
         return false;
      }

      final UserProfile? senderProfile = await _userService.getUserProfile(senderUid);
      if (senderProfile == null) {
         print("FriendService: Could not find sender profile.");
         return false;
      }

      final requestData = {
        'senderUid': senderProfile.uid, 'senderName': senderProfile.name, 'senderProfilePicUrl': senderProfile.profilePicUrl,
        'receiverUid': receiverUid, 'status': FriendRequestStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(), 'respondedAt': null,
      };
      await _requestsCollection.add(requestData);
      print("FriendService: Friend request sent from $senderUid to $receiverUid");
      return true;

    } catch (e) {
       print("FriendService: Error sending friend request: $e");
       if (e is FirebaseException && e.code == 'failed-precondition') { print("FriendService: Query likely requires a Firestore index for checking pending requests."); }
       return false;
    }
  }

  Stream<List<FriendRequest>> getIncomingFriendRequestsStream() {
    final String? userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    try {
      return _requestsCollection.where('receiverUid', isEqualTo: userId).where('status', isEqualTo: FriendRequestStatus.pending.name).orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList())
          .handleError((error) {
            print("FriendService: Error in getIncomingFriendRequestsStream: $error");
             if (error is FirebaseException && error.code == 'failed-precondition') { print("FriendService: Query requires Firestore index on (receiverUid, status, createdAt). Check Firestore console."); }
            return [];
          });
    } catch (e) { print("FriendService: Exception setting up incoming friend request stream: $e"); return Stream.value([]); }
  }

  Future<bool> acceptFriendRequest(FriendRequest request) async {
     final String? myUid = _currentUserId;
     if (myUid == null || request.receiverUid != myUid || request.status != FriendRequestStatus.pending) { return false; }
     final String senderUid = request.senderUid;
     try {
        bool added = await _addFriendInternal(myUid: myUid, friendUid: senderUid);
        if (added) {
           await _requestsCollection.doc(request.id).update({ 'status': FriendRequestStatus.accepted.name, 'respondedAt': FieldValue.serverTimestamp(), });
           print("FriendService: Accepted friend request ID: ${request.id}");
           return true;
        } else { print("FriendService: Failed to add mutual friendship for request ID: ${request.id}"); return false; }
     } catch (e) { print("FriendService: Error accepting friend request: $e"); return false; }
  }

   Future<bool> declineFriendRequest(String requestId) async {
      final String? myUid = _currentUserId;
      if (myUid == null) return false;
      try {
         await _requestsCollection.doc(requestId).update({ 'status': FriendRequestStatus.declined.name, 'respondedAt': FieldValue.serverTimestamp(), });
         print("FriendService: Declined friend request ID: $requestId");
         return true;
      } catch (e) { print("FriendService: Error declining friend request: $e"); return false; }
   }

  Future<bool> _addFriendInternal({required String myUid, required String friendUid}) async {
    if (myUid == friendUid) return false;
    final UserProfile? myProfile = await _userService.getUserProfile(myUid);
    final UserProfile? friendProfile = await _userService.getUserProfile(friendUid);
    if (myProfile == null || friendProfile == null) { print("FriendService: Could not find profile for self or friend during add."); return false; }

    final timestamp = Timestamp.now();
    final friendDataForMe = { 'uid': friendProfile.uid, 'name': friendProfile.name, 'profilePicUrl': friendProfile.profilePicUrl, 'addedAt': timestamp };
    final myDataForFriend = { 'uid': myProfile.uid, 'name': myProfile.name, 'profilePicUrl': myProfile.profilePicUrl, 'addedAt': timestamp };

    WriteBatch batch = _firestore.batch();
    batch.set(_usersCollection.doc(myUid).collection('friends').doc(friendUid), friendDataForMe);
    batch.set(_usersCollection.doc(friendUid).collection('friends').doc(myUid), myDataForFriend);
    await batch.commit();
    return true;
  }

  Future<bool> removeFriend(String friendUid) async {
     final String? myUid = _currentUserId;
     if (myUid == null || friendUid.isEmpty || myUid == friendUid) return false;
     try {
        WriteBatch batch = _firestore.batch();
        batch.delete(_usersCollection.doc(myUid).collection('friends').doc(friendUid));
        batch.delete(_usersCollection.doc(friendUid).collection('friends').doc(myUid));
        await batch.commit();
        print("FriendService: Friendship removed between $myUid and $friendUid");
        return true;
     } catch (e) { print("FriendService: Error removing friend: $e"); return false; }
  }

}