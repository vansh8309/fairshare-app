import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/screens/forgot_password_screen.dart';
import 'package:fair_share/features/auth/screens/signup_screen.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Login Logic
  Future<void> _loginUser() async {
    setState(() { _errorMessage = null; });
    if (!_formKey.currentState!.validate()) { return; }
    if (mounted) setState(() => _isLoading = true);

    try {
      final User? user = await _authService.signInWithEmailPassword(
        email: _emailController.text, password: _passwordController.text,
      );
      if (user != null) {
        print("LoginScreen: User signed in successfully: ${user.uid}");
        if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
       print("LoginScreen: FirebaseAuthException: ${e.code} - ${e.message}");
       String friendlyErrorMessage = 'Login failed. Please try again.';
       if (e.code == 'invalid-credential' || e.code == 'user-not-found' || e.code == 'wrong-password') { friendlyErrorMessage = 'Invalid email or password.'; }
       else if (e.code == 'invalid-email') { friendlyErrorMessage = 'The email address format is not valid.'; }
       else if (e.code == 'too-many-requests') { friendlyErrorMessage = 'Too many attempts. Please try again later.'; }
       else if (e.code == 'user-disabled') { friendlyErrorMessage = 'This account has been disabled.'; }
       if (mounted) { setState(() { _errorMessage = friendlyErrorMessage; _isLoading = false; }); }
    } catch (e) {
       print("LoginScreen: Unexpected error: $e");
       if (mounted) { setState(() { _errorMessage = 'An unexpected error occurred.'; _isLoading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login with Email'),
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
                _buildEmailField(context),
                const SizedBox(height: AppDimens.kSpacingMedium),
                _buildPasswordField(context),
                const SizedBox(height: AppDimens.kSmallPadding),
                _buildForgotPasswordLink(context),
                const SizedBox(height: AppDimens.kSpacingMedium),
                _buildErrorMessage(context),
                _buildLoginButton(context),
                const SizedBox(height: AppDimens.kSpacingLarge),
                _buildSignUpLink(context),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
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
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Password',
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppColors.getMutedTextColor(brightness),
          ),
          onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); },
        ),
      ),
      obscureText: _obscurePassword,
       autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (value == null || value.isEmpty) { return 'Please enter your password'; }
        return null;
      },
    );
  }

 Widget _buildForgotPasswordLink(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
         onPressed: _isLoading ? null : () {
           Navigator.push( context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()), );
         },
         child: const Text('Forgot Password?'),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context){
     if (_errorMessage == null) {
        return const SizedBox.shrink();
     }
     return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.kSpacingMedium),
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
  }

  Widget _buildLoginButton(BuildContext context) {
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
     return ElevatedButton(
       onPressed: _isLoading ? null : _loginUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: buttonFgColor,
          padding: AppDimens.kContinueButtonPadding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),
       ),
       child: _isLoading
          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: buttonFgColor))
          : const Text('Login'),
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return TextButton(
      onPressed: _isLoading ? null : () {
         Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => const SignUpScreen()), );
      },
      child: const Text("Don't have an account? Sign Up"),
    );
  }

}