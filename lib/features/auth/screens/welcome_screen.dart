import 'dart:async';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/screens/login_screen.dart';
import 'package:fair_share/features/auth/screens/otp_screen.dart';
import 'package:fair_share/features/auth/screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? completePhoneNumber;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final AuthService _authService = AuthService();

  // Google Sign-In Logic
  Future<void> _signInWithGoogle() async {
    if (mounted) setState(() => _isGoogleLoading = true);
    try {
       final User? user = await _authService.signInWithGoogle();
       if (user != null) { print("Google Sign In successful via UI..."); }
       else { if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Google Sign-In failed or cancelled.')), ); } }
    } catch (e) {
        print("Error during Google Sign In UI: $e");
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('An error occurred during Google Sign-In: ${e.toString()}')), ); }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kDefaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(context, screenHeight),
              const SizedBox(height: AppDimens.kSpacingLarge),
              _buildWelcomeTitle(context, brightness),
              const SizedBox(height: AppDimens.kSpacingVLarge),
              _buildPhoneInput(context, theme, brightness),
              const SizedBox(height: AppDimens.kSpacingLarge),
              _buildContinueButton(context, buttonFgColor),
              const SizedBox(height: AppDimens.kSpacingVLarge),
              _buildDivider(context, theme, brightness),
              const SizedBox(height: AppDimens.kSpacingLarge),
              _buildAlternateLogins(context, screenWidth, brightness),
              const SizedBox(height: AppDimens.kSpacingLarge),
              _buildRegisterLink(context),
              SizedBox(height: AppDimens.kDefaultPadding + MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context, double screenHeight) {
     return SizedBox( height: screenHeight * AppDimens.kLogoHeightPercent, child: Image.asset( "assets/icon/ICON2.png", fit: BoxFit.contain, semanticLabel: 'FairShare Logo',),);
  }

  Widget _buildWelcomeTitle(BuildContext context, Brightness brightness) {
     return Text( 'Welcome', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge?.copyWith( fontWeight: FontWeight.w600, color: AppColors.getTextColor(brightness),),);
  }

  Widget _buildPhoneInput(BuildContext context, ThemeData theme, Brightness brightness) {
     return IntlPhoneField(
        decoration: const InputDecoration( labelText: 'Enter your phone number', ),
        style: TextStyle(color: AppColors.getTextColor(brightness), fontSize: 16),
        dropdownTextStyle: TextStyle(color: AppColors.getTextColor(brightness)),
        dropdownIcon: Icon(Icons.arrow_drop_down, color: AppColors.getDropdownIconColor(brightness)),
        initialCountryCode: 'IN', languageCode: "en", keyboardType: TextInputType.phone,
        onChanged: (phone) { setState(() { completePhoneNumber = phone.completeNumber; }); },
     );
  }

  // Continue Button with Timeout Logic
  Widget _buildContinueButton(BuildContext context, Color buttonFgColor) {
     return ElevatedButton(
       onPressed: (completePhoneNumber?.isNotEmpty ?? false) && !_isLoading
          ? () async {
              if (completePhoneNumber == null || completePhoneNumber!.isEmpty){
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter phone number.')));
                 return;
              }
              if (mounted) setState(() => _isLoading = true);

              final PhoneCodeSentCallback onCodeSent = (verificationId, resendToken) {
                 if (mounted) { Navigator.push( context, MaterialPageRoute( builder: (context) => OtpScreen(verificationId: verificationId, phoneNumber: completePhoneNumber!, resendToken: resendToken,),),); setState(() => _isLoading = false); }
              };
              final PhoneVerificationFailedCallback onVerificationFailed = (e) {
                 String msg = 'Verification failed: ${e.message ?? 'Unknown error'}'; if (e.code == 'invalid-phone-number') { msg = 'Enter a valid phone number.'; } else if (e.code == 'too-many-requests') { msg = 'Too many requests. Please try again later.'; } if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3))); setState(() => _isLoading = false); }
              };
              final PhoneVerificationCompletedCallback onVerificationCompleted = (credential) async {
                 print("WelcomeScreen: VerificationCompleted (Auto-retrieval/Instant)"); if(mounted) setState(() => _isLoading = true); try { await _authService.signInWithCredential(credential); print("WelcomeScreen: Auto sign-in successful!");} catch(e) { print("WelcomeScreen: Auto sign-in failed: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto sign-in failed: ${e.toString()}'))); setState(() => _isLoading = false); } }
              };
               final PhoneCodeTimeoutCallback onCodeTimeout = (verificationId) {
                   print("WelcomeScreen: Code Auto Retrieval Timeout"); if (mounted) { setState(() => _isLoading = false); }
               };

              // Call AuthService
              try {
                  await _authService.verifyPhoneNumber( phoneNumber: completePhoneNumber!, onCodeSent: onCodeSent, onVerificationFailed: onVerificationFailed, onVerificationCompleted: onVerificationCompleted, onCodeTimeout: onCodeTimeout,)
                    .timeout( const Duration(seconds: 20), onTimeout: () { throw TimeoutException('Verification timed out. Check network or try again.'); });
              } catch (e) {
                 print("WelcomeScreen: Error during verifyPhoneNumber call/timeout: $e");
                 if (mounted) {
                    String message = e is TimeoutException ? e.message ?? 'Verification timed out.' : 'Failed to initiate verification. Please try again.';
                    ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(message), duration: const Duration(seconds: 3)), );
                    setState(() { _isLoading = false; });
                 }
              }
          }
          : null,
       style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: buttonFgColor, padding: AppDimens.kContinueButtonPadding, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),),
       child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: buttonFgColor)) : const Text('Continue'),
    );
  }

  Widget _buildDivider(BuildContext context, ThemeData theme, Brightness brightness) {
      return Row( children: <Widget>[ const Expanded(child: Divider()), Padding( padding: const EdgeInsets.symmetric(horizontal: AppDimens.kDefaultPadding), child: Text('or continue with', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.getMutedTextColor(brightness))),), const Expanded(child: Divider()),], );
  }

  Widget _buildAlternateLogins(BuildContext context, double screenWidth, Brightness brightness) {
     return Row( mainAxisAlignment: MainAxisAlignment.center, children: [ IconButton( icon: const Icon(Icons.email_outlined), iconSize: 30, tooltip: 'Login with Email', color: AppColors.getMutedTextColor(brightness), onPressed: _isGoogleLoading ? null : () { Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())); }, ), SizedBox(width: screenWidth * AppDimens.kIconButtonSpacingPercent), _isGoogleLoading ? Container( padding: const EdgeInsets.all(8.0), width: 48, height: 48, child: const CircularProgressIndicator(strokeWidth: 2.0), ) : IconButton( icon: const Icon(Icons.g_mobiledata_outlined), iconSize: 34, tooltip: 'Sign in with Google', color: AppColors.getMutedTextColor(brightness), onPressed: _signInWithGoogle, ), ], );
  }

   Widget _buildRegisterLink(BuildContext context) {
      return TextButton( onPressed: _isLoading || _isGoogleLoading ? null : () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())); }, child: const Text('New user? Register with Email'),);
   }

}