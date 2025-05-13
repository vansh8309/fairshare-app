import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

typedef PhoneCodeSentCallback = void Function(String verificationId, int? resendToken);
typedef PhoneVerificationFailedCallback = void Function(FirebaseAuthException e);
typedef PhoneVerificationCompletedCallback = void Function(PhoneAuthCredential credential);
typedef PhoneCodeTimeoutCallback = void Function(String verificationId);


class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    print("AuthService: Attempting Google Sign In...");
    try {
      await _googleSignIn.signOut();
      print("AuthService: Signed out from Google Sign-In package locally.");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { print('AuthService: Google Sign In cancelled.'); return null; }
      print('AuthService: Google user selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
      );

      return await signInWithCredential(credential);

    } on FirebaseAuthException catch (e) {
      print("AuthService: FirebaseAuthException during Google Sign In (signInWithCredential): ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("AuthService: Unexpected error during Google Sign In steps: $e");
      return null;
    }
  }

  // Phone Auth Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneCodeSentCallback onCodeSent,
    required PhoneVerificationFailedCallback onVerificationFailed,
    required PhoneVerificationCompletedCallback onVerificationCompleted,
    required PhoneCodeTimeoutCallback onCodeTimeout,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
}) async {
    print("AuthService: Verifying phone number: $phoneNumber (Resend Token: $forceResendingToken)");
    try {
        await _firebaseAuth.verifyPhoneNumber(
            phoneNumber: phoneNumber,
            verificationCompleted: onVerificationCompleted,
            verificationFailed: onVerificationFailed,
            codeSent: onCodeSent,
            codeAutoRetrievalTimeout: onCodeTimeout,
            timeout: timeout,
            forceResendingToken: forceResendingToken,
        );
    } on FirebaseAuthException catch (e) {
      print("Error initiating phone number verification: ${e.code} - ${e.message}");
      onVerificationFailed(e);
    } catch (e) {
       print("Unexpected error initiating phone number verification: $e");
        onVerificationFailed(FirebaseAuthException( code: 'unexpected-error', message: e.toString(), ));
    }
  }

  // Phone Auth Sign In with OTP
  Future<User?> signInWithOtp({required String verificationId, required String smsCode}) async {
    print("AuthService: Creating OTP credential. VerificationID: $verificationId");
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
       print("AuthService: FirebaseAuthException during OTP Sign In: ${e.code} - ${e.message}");
       throw e;
    } catch (e) {
       print("AuthService: Unexpected error during OTP Sign In: $e");
       throw Exception("An unexpected error occurred during OTP sign-in.");
    }
  }

  // Generic Sign In with any AuthCredential
  Future<User?> signInWithCredential(AuthCredential credential) async {
      print("AuthService: Attempting signInWithCredential...");
      try {
         final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
         print("AuthService: signInWithCredential successful: ${userCredential.user?.uid}");
         return userCredential.user;
      } on FirebaseAuthException catch (e) {
          print("AuthService: signInWithCredential failed: ${e.code} - ${e.message}");
          throw e;
      } catch (e) {
           print("AuthService: Unexpected error in signInWithCredential: $e");
           throw Exception("An unexpected error occurred during sign-in.");
      }
  }

  // Email/Password Sign Up
  Future<User?> createUserWithEmailPassword({ required String email, required String password, }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(), password: password,
      );
      print("Email/Pass Sign Up Successful: ${userCredential.user?.uid}");
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception during Email Sign Up: ${e.code} - ${e.message}");
      throw e;
    } catch (e) {
      print("Unexpected error during Email Sign Up: $e");
      throw Exception("An unexpected error occurred during sign up.");
    }
  }

  // Email/Password Sign In
  Future<User?> signInWithEmailPassword({ required String email, required String password, }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(), password: password,
      );
      print("Email/Pass Sign In Successful: ${userCredential.user?.uid}");
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Exception during Email Sign In: ${e.code} - ${e.message}");
      throw e;
    } catch (e) {
      print("Unexpected error during Email Sign In: $e");
      throw Exception("An unexpected error occurred during sign in.");
    }
  }

  // Password Reset
  Future<void> sendPasswordResetEmail({required String email}) async {
     try {
       await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
       print("Password reset email sent successfully to $email");
     } on FirebaseAuthException catch (e) {
       print("Firebase Auth Exception during Password Reset: ${e.code} - ${e.message}");
       throw e;
     } catch (e) {
        print("Unexpected error during Password Reset: $e");
        throw Exception("An unexpected error occurred while sending reset email.");
     }
  }

  // Sign Out
  Future<void> signOut() async {
     try {
       if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
          print("Signed out from Google.");
       }
       await _firebaseAuth.signOut();
       print("Signed out from Firebase.");
     } catch (e) {
       print("Error during sign out: $e");
     }
  }

  // Get Current User
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  // Auth State Changes Stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

}