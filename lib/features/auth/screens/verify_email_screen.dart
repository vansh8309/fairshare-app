import 'dart:async';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/screens/auth_gate.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';  
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  bool _isSendingVerification = false;
  bool _canResendEmail = false;
  Timer? _verificationCheckTimer;
  Timer? _resendCooldownTimer;
  int _resendCooldown = 0;
  bool _isVerified = false;

  static const int _resendDelaySeconds = 60;
  static const Duration _periodicCheckDuration = Duration(seconds: 4);

  User? get currentUser => _authService.getCurrentUser();

  @override
  void initState() {
    super.initState();
    _checkEmailVerification(showFeedback: false);
    _verificationCheckTimer =
        Timer.periodic(_periodicCheckDuration, (_) => _checkEmailVerification(showFeedback: false));
    _initializeResendState();
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  //Resend Timer Logic 
  Future<void> _initializeResendState() async {
    if (!mounted || currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String prefKey = 'lastVerificationSent_${currentUser!.uid}';
    final lastSentMillis = prefs.getInt(prefKey);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    if (lastSentMillis != null) {
      final elapsedSeconds = (nowMillis - lastSentMillis) ~/ 1000;
      final remainingCooldown = max(0, _resendDelaySeconds - elapsedSeconds);

      print("VerifyEmailScreen: Last sent ${elapsedSeconds}s ago. Remaining cooldown: ${remainingCooldown}s");

      if (remainingCooldown == 0) {
         if(mounted) setState(() => _canResendEmail = true);
      } else {
         _startResendDisplayTimer(startCooldown: remainingCooldown);
      }
    } else {
       print("VerifyEmailScreen: No previous send timestamp found. Enabling resend.");
       if(mounted) setState(() => _canResendEmail = true);
    }
  }

  void _startResendDisplayTimer({required int startCooldown}) {
     if (!mounted) return;
    _resendCooldownTimer?.cancel();
    setState(() {
        _resendCooldown = startCooldown;
        _canResendEmail = false;
    });
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendCooldown > 0) {
        setState(() { _resendCooldown--; });
      } else {
        timer.cancel();
        if (mounted) setState(() { _canResendEmail = true; });
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (currentUser == null || !_canResendEmail || _isSendingVerification) return;

    if (mounted) setState(() => _isSendingVerification = true);
    try {
      await currentUser!.sendEmailVerification();

      final prefs = await SharedPreferences.getInstance();
      final String prefKey = 'lastVerificationSent_${currentUser!.uid}';
      await prefs.setInt(prefKey, DateTime.now().millisecondsSinceEpoch);
      print("VerifyEmailScreen: Stored verification RESENT timestamp for ${currentUser!.uid}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Verification email resent! Please check your inbox.')), );
        _startResendDisplayTimer(startCooldown: _resendDelaySeconds);
      }
    } catch (e) {
        print("Error resending verification email: $e");
        if(mounted) {
            String errorMessage = 'Failed to resend verification email.';
            if (e is FirebaseAuthException && e.code == 'too-many-requests') { errorMessage = 'Too many requests. Please wait before trying again.'; }
            ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(errorMessage)), );
        }
    } finally {
      if (mounted) setState(() => _isSendingVerification = false);
    }
  }

  // Check Email Verification Logic
  Future<void> _checkEmailVerification({bool showFeedback = true}) async {
    if (_isVerified || !mounted) return;
    User? user = _authService.getCurrentUser();
    if (user == null) return;

    print("VerifyEmailScreen: Reloading user data...");
    try { await user.reload(); user = _authService.getCurrentUser(); }
    catch (e) {
      print("VerifyEmailScreen: Error reloading user: $e");
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update verification status: ${e.toString()}')),
        );
      }
      return;
    }

    print("VerifyEmailScreen: Checked email verification status: ${user?.emailVerified}");

    if (user != null && user.emailVerified) {
      print("VerifyEmailScreen: Email is verified!");
      _verificationCheckTimer?.cancel();
      _resendCooldownTimer?.cancel();
      if (mounted) {
        setState(() => _isVerified = true);
        if (showFeedback) {ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email successfully verified! Proceeding...')),
          );
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            print("VerifyEmailScreen: Navigating via AuthGate after verification.");
            Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const AuthGate()), (route) => false, );
          }
        });
      }
    }
    else if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not verified yet. Please click the link in your email or resend.')),
      );
    }
  }

  // Sign Out Logic
  Future<void> _signOut() async {
     _verificationCheckTimer?.cancel();
     _resendCooldownTimer?.cancel();
     await _authService.signOut();
     if(mounted){
         print("VerifyEmailScreen: Signing out and navigating via AuthGate.");
         Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const AuthGate()), (Route<dynamic> route) => false, );
     }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
    final userEmail = currentUser?.email ?? 'your email address';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          child: Center(
            child: _isVerified
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 80),
                      const SizedBox(height: AppDimens.kSpacingLarge),
                      Text('Email Verified!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                      const SizedBox(height: AppDimens.kSpacingSmall),
                      Text('You will be redirected shortly...', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.getMutedTextColor(brightness)), textAlign: TextAlign.center,),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 70, color: theme.colorScheme.primary),
                      const SizedBox(height: AppDimens.kSpacingMedium),
                      Text('Check Your Inbox!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                      const SizedBox(height: AppDimens.kSpacingMedium),
                      Text('A verification link has been sent to:', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center,),
                      Text(userEmail, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                      const SizedBox(height: AppDimens.kSmallPadding),
                      Text( 'Click the link in the email to activate your account. You may need to check your spam folder.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.getMutedTextColor(brightness)), textAlign: TextAlign.center,),
                      const SizedBox(height: AppDimens.kSpacingVLarge),

                      // Resend Button - State controlled by timer logic
                      ElevatedButton.icon(
                        icon: _isSendingVerification
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_outlined, size: 18),
                        label: Text(
                            _canResendEmail
                                ? 'Resend Verification Email'
                                : 'Resend available in $_resendCooldown s',
                            style: theme.textTheme.bodyMedium,
                        ),
                        // Enable button based on _canResendEmail flag
                        onPressed: _canResendEmail && !_isSendingVerification ? _resendVerificationEmail : null,
                        style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: buttonFgColor, padding: AppDimens.kContinueButtonPadding, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),),
                      ),
                      const SizedBox(height: AppDimens.kSpacingSmall),

                      // Cancel Button
                      TextButton(
                         onPressed: _signOut,
                         child: const Text('Cancel'),
                      ),
                      const Spacer(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}