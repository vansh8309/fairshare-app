import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fair_share/features/auth/screens/verify_email_screen.dart';
import 'package:fair_share/features/auth/screens/welcome_screen.dart';
import 'package:fair_share/features/profile/screens/create_profile_screen.dart';
import 'package:fair_share/features/home/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // Helper to check if user signed in with Email/Password provider
  bool _isEmailPasswordUser(User user) {
    return user.providerData.any((userInfo) => userInfo.providerId == 'password');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to Firebase authentication state changes
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show loading indicator while checking auth state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged IN (authSnapshot has data)
        if (authSnapshot.hasData) {
          final User currentUser = authSnapshot.data!;
          print("AuthGate: User logged in: ${currentUser.uid} | Email: ${currentUser.email}");

          // Check if they used Email/Password AND their email is NOT yet verified
          if (_isEmailPasswordUser(currentUser) && !currentUser.emailVerified) {
             print("AuthGate: Email user ${currentUser.email} NOT verified. Checking status after reload...");

             // Return a FutureBuilder to handle the async user.reload()
             return FutureBuilder(
                // Call reload() then get the potentially updated user object
                future: currentUser.reload().then((_) => FirebaseAuth.instance.currentUser),
                builder: (context, reloadSnapshot) {
                   // While reloading, show a simple indicator
                   if (reloadSnapshot.connectionState == ConnectionState.waiting) {
                      // Use a Scaffold to avoid errors during transition
                      return const Scaffold(body: Center(child: Text("Checking verification status...")));
                   }

                   // Handle potential errors during reload
                   if (reloadSnapshot.hasError) {
                       print("AuthGate: Error during user.reload(): ${reloadSnapshot.error}");
                       // Fallback: Maybe show verify screen anyway or an error screen
                       return const VerifyEmailScreen();
                   }

                   // Get the potentially updated user data after reload
                   final User? reloadedUser = reloadSnapshot.data;

                   // If reload successful and email is STILL not verified, show VerifyEmailScreen
                   if (reloadedUser != null && !reloadedUser.emailVerified) {
                      print("AuthGate: Reload complete. Email still NOT verified for ${reloadedUser.email}. Showing VerifyEmailScreen.");
                      return const VerifyEmailScreen();
                   }
                   // If email IS verified after reload (or user somehow became null?), proceed
                   else {
                      print("AuthGate: Reload complete. Email is verified for ${reloadedUser?.email} (or user is null). Proceeding to profile check.");
                      // Proceed to the Firestore profile check
                      return _buildProfileCheckStream(currentUser.uid);
                   }
                }
             );
          }
          //If user is verified OR not an email/password user, proceed directly to profile check
          else {
              if(_isEmailPasswordUser(currentUser)){
                 print("AuthGate: Email user ${currentUser.email} IS verified. Checking profile...");
              } else {
                 print("AuthGate: Non-email user (${currentUser.providerData.map((p) => p.providerId).join(', ')}). Checking profile...");
              }
              return _buildProfileCheckStream(currentUser.uid);
          }
        }
        // If user is logged OUT (authSnapshot has no data)
        else {
          print("AuthGate: User logged out.");
          return const WelcomeScreen();
        }
      },
    );
  }

  //Helper Widget to build the Firestore profile check stream
  Widget _buildProfileCheckStream(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          print("AuthGate: Checking profile for $userId...");
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (profileSnapshot.hasError) {
          print("AuthGate: Error fetching profile: ${profileSnapshot.error}");
          return const Scaffold(body: Center(child: Text('Error loading profile data.')));
        }

        final profileData = profileSnapshot.data?.data() as Map<String, dynamic>?;
        // Check if profile exists and has a non-empty name
        final profileExists = profileSnapshot.hasData && profileSnapshot.data!.exists &&
                              profileData != null && profileData.containsKey('name') &&
                              (profileData['name'] as String? ?? '').isNotEmpty;

        print("AuthGate: Profile exists for $userId? $profileExists");

        if (profileExists) {
          return const HomeScreen(); // Go to main app
        } else {
          return const CreateProfileScreen(); // Go to profile creation
        }
      },
    );
  }
} // End of AuthGate