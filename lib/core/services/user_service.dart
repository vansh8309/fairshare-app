import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fair_share/features/profile/models/user_profile.dart'; // Import the model

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'users'; // Collection name

  /// Fetches a single user profile based on UID.
  /// Returns null if the user document doesn't exist.
  Future<UserProfile?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final docSnapshot = await _firestore.collection(_collectionPath).doc(uid).get();
      if (docSnapshot.exists) {
        return UserProfile.fromFirestore(docSnapshot);
      } else {
        print("UserService: No profile found for UID: $uid");
        return null; // Return null if document doesn't exist
      }
    } catch (e) {
      print("UserService: Error fetching user profile for $uid: $e");
      return null; // Return null on error
    }
  }

  /// Provides a stream for a single user profile document.
  Stream<UserProfile?> getUserProfileStream(String uid) {
     if (uid.isEmpty) return Stream.value(null);
     try {
       return _firestore
           .collection(_collectionPath)
           .doc(uid)
           .snapshots() // Listen to changes
           .map((snapshot) {
              if (snapshot.exists) {
                 return UserProfile.fromFirestore(snapshot);
              } else {
                 return null;
              }
           })
           .handleError((error) {
              print("UserService: Error in user profile stream for $uid: $error");
              return null; // Emit null on error
           });
     } catch(e) {
        print("UserService: Exception setting up user profile stream for $uid: $e");
        return Stream.value(null);
     }
  }

  Future<UserProfile?> findUserByEmailOrPhone(String emailOrPhone) async {
     if (emailOrPhone.trim().isEmpty) return null;
     print("UserService: Searching for user with email/phone: $emailOrPhone");
     try {
        QuerySnapshot queryByEmail = await _firestore
            .collection(_collectionPath)
            .where('email', isEqualTo: emailOrPhone.trim())
            .limit(1)
            .get();

        if (queryByEmail.docs.isNotEmpty) {
           print("UserService: Found user by email.");
           return UserProfile.fromFirestore(queryByEmail.docs.first);
        }

        // If not found by email, try by phone
         QuerySnapshot queryByPhone = await _firestore
            .collection(_collectionPath)
            .where('phone', isEqualTo: emailOrPhone.trim()) // Assumes phone stored with country code
            .limit(1)
            .get();

         if (queryByPhone.docs.isNotEmpty) {
            print("UserService: Found user by phone.");
            return UserProfile.fromFirestore(queryByPhone.docs.first);
         }

        print("UserService: No user found matching '$emailOrPhone'.");
        return null; // Not found by either

     } catch (e) {
        print("UserService: Error finding user by email/phone: $e");
        // Check for specific errors like needing an index
        if (e is FirebaseException && e.code == 'failed-precondition') {
            print("UserService: Query likely requires a Firestore index on 'email' or 'phone'. Check Firestore console.");
        }
        return null;
     }
  }
  Future<bool> updateUserProfile(String uid, Map<String, dynamic> dataToUpdate) async {
    if (uid.isEmpty || dataToUpdate.isEmpty) {
      print("UserService Error: Invalid UID or empty data for update.");
      return false;
    }
    try {
      // Add/update a timestamp for the last update
      dataToUpdate['lastUpdatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collectionPath).doc(uid).update(dataToUpdate);
      print("UserService: Profile updated successfully for UID: $uid");
      return true;
    } catch (e) {
      print("UserService: Error updating profile for $uid: $e");
      return false;
    }
  }

  Future<void> updateThemePreference(String uid, String theme) async {
    await _firestore.collection('users').doc(uid).update({'themePreference': theme});
  }

    // Add this method to UserService
  Future<void> deleteUserProfile(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

}
