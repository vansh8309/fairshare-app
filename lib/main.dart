import 'package:fair_share/core/theme/app_theme.dart';
import 'package:fair_share/features/auth/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:fair_share/core/services/user_service.dart'; 
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      print("Firebase App Check Activated (Provider: ${kDebugMode ? 'Debug' : 'PlayIntegrity'})");
  } catch(e) {
      print("!!! Firebase App Check Activation Failed: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();
    final UserService _userService = UserService();
    final String? currentUid = _authService.getCurrentUser()?.uid;
    return MaterialApp(
      title: 'FairShare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: currentUid == null
          ? const AuthGate() // Or handle the loading/unauthenticated state as needed
          : StreamBuilder<UserProfile?>(
              stream: _userService.getUserProfileStream(currentUid),
              builder: (context, snapshot) {
                ThemeMode currentThemeMode = ThemeMode.system;
                if (snapshot.hasData && snapshot.data?.themePreference != null) {
                  switch (snapshot.data!.themePreference) {
                    case 'light':
                      currentThemeMode = ThemeMode.light;
                      break;
                    case 'dark':
                      currentThemeMode = ThemeMode.dark;
                      break;
                    case 'system':
                    default:
                      currentThemeMode = ThemeMode.system;
                      break;
                  }
                }
                return MaterialApp( // Nested MaterialApp to apply theme based on user preference
                  title: 'FairShare',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: currentThemeMode,
                  home: const AuthGate(), // Your main app screen
                );
              },
            ),
    );
  }
}