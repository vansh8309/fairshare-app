import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fair_share/features/groups/models/group_model.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

    DocumentReference _groupDocRef(String groupId) {
     return _firestore.collection('groups').doc(groupId);
  }

  Future<String?> createGroup(String groupName, String groupType) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      print("GroupService Error: User not logged in to create group.");
      return null;
    }
    if (groupName.trim().isEmpty || groupType.trim().isEmpty) {
       print("GroupService Error: Group name and type cannot be empty.");
       return null;
    }

    final groupData = {
      'groupName': groupName.trim(),
      'groupType': groupType.trim(),
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [userId],
      'currencyCode': 'INR',
      'lastActivityAt': FieldValue.serverTimestamp(),
      'groupImageUrl': null,
    };

    try {
      final docRef = await _firestore.collection('groups').add(groupData);
      print("GroupService: Group created successfully with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      print("GroupService: Error creating group in Firestore: $e");
      return null;
    }
  }

  Stream<List<Group>> getUserGroupsStream() {
    final String? userId = _currentUserId;
    if (userId == null) {
      print("GroupService: Cannot get groups stream, user not logged in.");
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .orderBy('lastActivityAt', descending: true)
          .snapshots()
          .map((snapshot) {
              print("GroupService: Received ${snapshot.docs.length} group snapshots for user $userId");
              return snapshot.docs
                  .map((doc) => Group.fromFirestore(doc))
                  .toList();
           })
          .handleError((error) {
              print("GroupService: Error in getUserGroupsStream: $error");
              return [];
           });
    } catch (e) {
       print("GroupService: Exception setting up group stream: $e");
       return Stream.value([]); 
    }
  }

  Stream<Group?> getGroupStream(String groupId) {
     if (groupId.isEmpty) return Stream.value(null);
     try {
       return _firestore
           .collection('groups')
           .doc(groupId)
           .snapshots() 
           .map((snapshot) {
              if (snapshot.exists) {
                 return Group.fromFirestore(snapshot); 
              } else {
                 print("GroupService: Group document $groupId does not exist.");
                 return null;
              }
           })
           .handleError((error) {
              print("GroupService: Error in getGroupStream for $groupId: $error");
              return null;
           });
     } catch (e) {
        print("GroupService: Exception setting up single group stream for $groupId: $e");
        return Stream.value(null);
     }
  }

  Future<bool> addMemberToGroup(String groupId, String friendUidToAdd) async {
    final String? currentUserId = _currentUserId;
    if (currentUserId == null) return false;
    if (groupId.isEmpty || friendUidToAdd.isEmpty) return false;

    final DocumentReference groupRef = _firestore.collection('groups').doc(groupId);

    try {
      await groupRef.update({
          'members': FieldValue.arrayUnion([friendUidToAdd]),
          'lastActivityAt': FieldValue.serverTimestamp(),
      });
      print("GroupService: Added member $friendUidToAdd to group $groupId");
      return true;
    } catch (e) {
      print("GroupService: Error adding member $friendUidToAdd to group $groupId: $e");
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    final String? myUid = _currentUserId;
    if (myUid == null || groupId.isEmpty) {
      print("GroupService Error: Cannot leave group - invalid input or user not logged in.");
      return false;
    }

    final DocumentReference groupRef = _groupDocRef(groupId);

    try {
       await groupRef.update({
          'members': FieldValue.arrayRemove([myUid]),
          'lastActivityAt': FieldValue.serverTimestamp(),
       });
       print("GroupService: User $myUid left group $groupId");
       return true;
    } catch (e) {
       print("GroupService: Error leaving group $groupId: $e");
       return false;
    }
  }

  Future<bool> removeMemberFromGroup(String groupId, String memberUidToRemove) async {
     final String? removerUid = _currentUserId;
     if (removerUid == null || groupId.isEmpty || memberUidToRemove.isEmpty) {
       print("GroupService Error: Cannot remove member - invalid input or user not logged in.");
       return false;
     }
     if (removerUid == memberUidToRemove) {
        print("GroupService Error: Cannot remove self using this method.");
        return false;
     }

     final DocumentReference groupRef = _groupDocRef(groupId);

     try {
        final groupDoc = await groupRef.get();
        if (!groupDoc.exists) {
           print("GroupService Error: Group $groupId not found.");
           return false;
        }
        final groupData = groupDoc.data() as Map<String, dynamic>?;
        final members = List<String>.from(groupData?['members'] ?? []);
        final creatorUid = groupData?['createdBy'] as String?;

        if (creatorUid != removerUid) {
           print("GroupService Error: User $removerUid is not the creator of group $groupId.");
           return false;
        }
        if (memberUidToRemove == creatorUid) {
            print("GroupService Error: Creator cannot be removed by this method.");
            return false;
        }
        if (!members.contains(memberUidToRemove)) {
            print("GroupService Error: User $memberUidToRemove is not a member of group $groupId.");
            return false;
        }

        await groupRef.update({
           'members': FieldValue.arrayRemove([memberUidToRemove]),
           'lastActivityAt': FieldValue.serverTimestamp(),
        });
        print("GroupService: Creator $removerUid removed member $memberUidToRemove from group $groupId");
        return true;

     } catch (e) {
        print("GroupService: Error removing member $memberUidToRemove from group $groupId: $e");
        return false;
     }
  }

  Future<bool> updateGroupName(String groupId, String newName) async {
    if (groupId.isEmpty || newName.trim().isEmpty) return false;
    try {
      await _groupDocRef(groupId).update({
        'groupName': newName.trim(),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
      print("GroupService: Updated group $groupId name to '$newName'");
      return true;
    } catch (e) {
      print("GroupService: Error updating group name $groupId: $e");
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    final String? myUid = _currentUserId;
    if (myUid == null || groupId.isEmpty) return false;

    final DocumentReference groupRef = _groupDocRef(groupId);
    try {
      final groupDoc = await groupRef.get();
      if (!groupDoc.exists) { print("GroupService: Group $groupId not found for delete."); return false; }
      final groupData = groupDoc.data() as Map<String, dynamic>?;
      if (groupData?['createdBy'] != myUid) { print("GroupService: User $myUid is not creator, cannot delete group $groupId."); return false; }

      // Delete
      await groupRef.delete();
      print("GroupService: Deleted group $groupId");
      return true;
    } catch (e) {
      print("GroupService: Error deleting group $groupId: $e");
      return false;
    }
  }
}