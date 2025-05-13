import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/screens/verify_email_screen.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpUser() async {
    setState(() { _errorMessage = null; });
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    User? user;

    try {
      user = await _authService.createUserWithEmailPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (user != null) {
        print("SignUpScreen: User created successfully: ${user.uid}");

        try {
          if (!mounted) return;
          await user.sendEmailVerification();
          print("SignUpScreen: Verification email sent to ${user.email}");
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('lastVerificationSent_${user.uid}', DateTime.now().millisecondsSinceEpoch);
          print("SignUpScreen: Stored verification sent timestamp for ${user.uid}");

           if (mounted) {
             Navigator.pushReplacement(
                 context,
                 MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
             );
           }

        } catch (e) {
          print("SignUpScreen: Failed to send verification email: $e");
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Registration successful, but failed to send verification email. Please use Resend on the next screen.')),
             );
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
            );
          }
        }
      }

    } on FirebaseAuthException catch (e) {
       print("SignUpScreen: FirebaseAuthException: ${e.code} - ${e.message}");
       String friendlyErrorMessage = 'Registration failed. Please try again.';
       if (e.code == 'weak-password') { friendlyErrorMessage = 'The password provided is too weak.'; }
       else if (e.code == 'email-already-in-use') { friendlyErrorMessage = 'An account already exists for that email.'; }
       else if (e.code == 'invalid-email') { friendlyErrorMessage = 'The email address is not valid.'; }
       if (mounted) {
          setState(() { _errorMessage = friendlyErrorMessage; _isLoading = false; });
       }
    } catch (e) {
       print("SignUpScreen: Unexpected error: $e");
       if (mounted) {
          setState(() { _errorMessage = 'An unexpected error occurred.'; _isLoading = false; });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
    final brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register with Email'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.kSpacingLarge),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                     if (value == null || value.trim().isEmpty) { return 'Please enter your email'; }
                     bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value.trim());
                     if (!emailValid) { return 'Please enter a valid email address'; }
                     return null;
                  },
                ),
                const SizedBox(height: AppDimens.kSpacingMedium),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password (min. 6 characters)',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.getMutedTextColor(brightness)),
                      onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                     if (value == null || value.isEmpty) { return 'Please enter a password'; }
                     if (value.length < 6) { return 'Password must be at least 6 characters'; }
                     return null;
                  },
                ),
                const SizedBox(height: AppDimens.kSpacingMedium),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                     suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.getMutedTextColor(brightness)),
                      onPressed: () { setState(() { _obscureConfirmPassword = !_obscureConfirmPassword; }); },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                     if (value == null || value.isEmpty) { return 'Please confirm your password'; }
                     if (value != _passwordController.text) { return 'Passwords do not match'; }
                     return null;
                  },
                ),
                const SizedBox(height: AppDimens.kSpacingLarge),

                // Error Message Area
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.kSpacingMedium),
                    child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
                  ),

                // Sign Up Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUpUser,
                  style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.secondary,
                     foregroundColor: buttonFgColor,
                     padding: AppDimens.kContinueButtonPadding,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),
                  ),
                  child: _isLoading
                     ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: buttonFgColor))
                     : const Text('Sign Up'),
                ),
                const SizedBox(height: AppDimens.kSpacingMedium),

                // Link to Login Screen
                TextButton(
                  onPressed: _isLoading ? null : () { if (Navigator.canPop(context)) { Navigator.pop(context); } },
                  child: const Text('Already have an account? Login'),
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