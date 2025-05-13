import 'dart:async';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/screens/auth_gate.dart'; // For navigation fallback
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final AuthService _authService = AuthService(); 

  bool _isLoading = false; 
  bool _isResending = false; 
  bool _canResendCode = false; 
  Timer? _resendCooldownTimer;
  int _resendCooldown = 0; 
  static const int _resendDelaySeconds = 60;
  int? _currentResendToken;

  @override
  void initState() {
    super.initState();
    _currentResendToken = widget.resendToken;
    _startResendTimer();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  // Simple Resend Timer Logic
  void _startResendTimer() {
    if (!mounted) return;
    _resendCooldownTimer?.cancel();
    setState(() {
        _resendCooldown = _resendDelaySeconds; // Reset display countdown
        _canResendCode = false; // Disable button
    });
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendCooldown > 0) {
        setState(() { _resendCooldown--; });
      } else {
        timer.cancel();
        if (mounted) setState(() { _canResendCode = true; }); // Enable button
      }
    });
  }

  // Resend OTP
  Future<void> _resendOtp() async {
    if (!_canResendCode || _isResending) return;
    if (mounted) setState(() { _isResending = true; });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _currentResendToken,
        onCodeSent: (String verificationId, int? resendToken) {
           print("New code sent. New VID (using original): ${widget.verificationId}, New Token: $resendToken");
           _currentResendToken = resendToken;

           if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('A new code has been sent.')), );
              _startResendTimer();
              setState(() { _isResending = false; });
              _pinController.clear();
              _pinFocusNode.requestFocus();
           }
        },
        onVerificationFailed: (FirebaseAuthException e) {
           print("Resend: Verification failed: ${e.message}");
           if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Failed to resend code: ${e.message ?? 'Unknown error'}')),);
              setState(() { _isResending = false; });
           }
        },
        onVerificationCompleted: (PhoneAuthCredential credential) async {
           print("Resend: Phone number automatically verified.");
           if(mounted) setState(() => _isLoading = true);
           try {
              await _authService.signInWithCredential(credential);
              print("Resend: Auto sign-in successful!");
              if (mounted) Navigator.of(context).pop();
           } catch (e) {
                print("Resend: Auto sign-in failed: $e");
                 if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto sign-in failed after resend.')));
                    setState(() => _isLoading = false);
                 }
           } finally {
                 if (mounted) setState(() { _isResending = false; });
           }
        },
        onCodeTimeout: (String verificationId) {
           print("Resend: Auto retrieval timed out.");
           if(mounted) setState(() { _isResending = false; });
        },
      );
    } catch (e) {
      print("An unexpected error occurred during OTP resend initiation: $e");
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('An error occurred while resending: $e')),);
         setState(() { _isResending = false; });
      }
    }
  }

  // Verify OTP Action
  Future<void> _verifyOtp(String smsCode) async {
    if (smsCode.length != 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Please enter the complete 6-digit code.')), );
      return;
    }

    if (mounted) setState(() { _isLoading = true; });

    try {
      final User? user = await _authService.signInWithOtp(
          verificationId: widget.verificationId,
          smsCode: smsCode,
      );
      if (user != null) {
         print("OtpScreen: OTP Verification Successful via service! User: ${user.uid}");
         if (mounted) {
             Navigator.of(context).pop();
         }
      }
    } on FirebaseAuthException catch (e) {
       print("OtpScreen: Verification Failed: ${e.code} - ${e.message}");
       String errorMessage = "Verification failed. Please try again.";
       if (e.code == 'invalid-verification-code') { errorMessage = "Invalid code entered. Please try again."; }
       else if (e.code == 'session-expired') { errorMessage = "The verification code has expired. Please request a new one."; }
       else if (e.code == 'credential-already-in-use') { errorMessage = "This OTP code has already been used."; }
       if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)), );
       }
    } catch (e) {
       print("OtpScreen: An unexpected error occurred during OTP verification: $e");
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('An error occurred: ${e.toString()}')),);
        }
    } finally {
      if (mounted) {
         setState(() { _isLoading = false; });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
    final defaultPinTheme = PinTheme(
      width: 50, height: 56,
      textStyle: theme.textTheme.headlineSmall?.copyWith(color: AppColors.getTextColor(brightness)),
      decoration: BoxDecoration(
        color: AppColors.getInputFillColor(brightness),
        borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius * 0.75),
        border: Border.all(color: AppColors.getInputBorderColor(brightness)),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
     final submittedPinTheme = defaultPinTheme.copyWith(
       decoration: defaultPinTheme.decoration!.copyWith(
          border: Border.all(color: AppColors.secondary),
       )
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Verification Code'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          physics: const ClampingScrollPhysics(),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Text('Enter the 6-digit code sent to:', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.getMutedTextColor(brightness)), textAlign: TextAlign.center,),
                const SizedBox(height: AppDimens.kSmallPadding),
                Text( widget.phoneNumber, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.getTextColor(brightness)), textAlign: TextAlign.center, ),
                const SizedBox(height: AppDimens.kSpacingVLarge),
                Pinput(
                   length: 6, controller: _pinController, focusNode: _pinFocusNode, autofocus: true,
                   defaultPinTheme: defaultPinTheme, focusedPinTheme: focusedPinTheme, submittedPinTheme: submittedPinTheme,
                   separatorBuilder: (index) => const SizedBox(width: AppDimens.kSmallPadding),
                   hapticFeedbackType: HapticFeedbackType.lightImpact,
                   onCompleted: _verifyOtp,
                ),
                const SizedBox(height: AppDimens.kSpacingLarge),
                SizedBox( width: double.infinity, child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _verifyOtp(_pinController.text),
                    style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: buttonFgColor, padding: AppDimens.kContinueButtonPadding, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)), ),
                    child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: buttonFgColor)) : const Text('Verify OTP'),
                  ),
                ),
                const SizedBox(height: AppDimens.kSpacingLarge),
                Row( mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("Didn't receive code?", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.getMutedTextColor(brightness)),),
                    TextButton(
                      onPressed: _canResendCode && !_isResending ? _resendOtp : null,
                      child: _isResending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              _canResendCode ? 'Resend Code' : 'Resend in $_resendCooldown s',
                              style: TextStyle( color: _canResendCode ? theme.colorScheme.primary : AppColors.getMutedTextColor(brightness), fontWeight: FontWeight.bold,),
                            ),
                    ),
                  ],
                ),
                 SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}