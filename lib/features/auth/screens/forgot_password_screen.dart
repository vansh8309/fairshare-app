import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  // Send Reset Link Logic
  Future<void> _sendResetLink() async {
    setState(() { _feedbackMessage = null; _isSuccess = false; });
    if (!_formKey.currentState!.validate()) { return; }

    // Hide keyboard after validation, before showing loader
    FocusScope.of(context).unfocus();
    if (mounted) setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(email: _emailController.text);
      if (mounted) {
        setState(() {
          _feedbackMessage = 'Password reset link sent! Please check your email (including spam folder).';
          _isSuccess = true; _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
       String friendlyErrorMessage = 'Failed to send reset link.';
       if (e.code == 'user-not-found') { friendlyErrorMessage = 'No user found with this email address.'; }
       else if (e.code == 'invalid-email') { friendlyErrorMessage = 'The email address format is not valid.'; }
       if (mounted) { setState(() { _feedbackMessage = friendlyErrorMessage; _isSuccess = false; _isLoading = false; });}
    } catch (e) {
       if (mounted) { setState(() { _feedbackMessage = 'An unexpected error occurred.'; _isSuccess = false; _isLoading = false; }); }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
    final brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.kSpacingLarge),
                Text(
                  'Enter your account email address and we will send you a link to reset your password.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                     color: AppColors.getMutedTextColor(brightness)
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.kSpacingLarge),

                // Email Field with Keyboard Action
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your registered email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  textInputAction: TextInputAction.done, 
                  onFieldSubmitted: (_) => _sendResetLink(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { return 'Please enter your email'; }
                    bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value.trim());
                    if (!emailValid) { return 'Please enter a valid email address'; }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.kSpacingLarge),

                // Display Feedback Message using Visibility
                Visibility(
                  visible: _feedbackMessage != null,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.kSpacingMedium),
                    child: Text(
                      _feedbackMessage ?? '',
                      style: TextStyle(color: _isSuccess ? AppColors.success : theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Send Reset Link Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendResetLink,
                  style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.secondary,
                     foregroundColor: buttonFgColor,
                     padding: AppDimens.kContinueButtonPadding,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),
                  ),
                  child: _isLoading
                     ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: buttonFgColor))
                     : const Text('Send Reset Link'),
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