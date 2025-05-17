import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:fair_share/features/profile/screens/edit_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  
import 'package:fair_share/features/auth/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:fair_share/features/profile/screens/notification_settings_screen.dart';
import 'package:fair_share/features/profile/screens/change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  late final String? _myUid;
  bool _isEmailPasswordUser = false;

  Widget _buildThemeSettings(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimens.kSpacingLarge),
        const Divider(),
        const SizedBox(height: AppDimens.kSpacingMedium),
        Align(
          alignment: Alignment.centerLeft,
          child: Text("App Preferences", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: AppDimens.kSpacingSmall),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: Text("Theme", style: theme.textTheme.bodyLarge),
          subtitle: Text(_getThemeDisplayName(profile.themePreference), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.getMutedTextColor(theme.brightness))),
          onTap: () => _showThemePickerDialog(context, profile),
        ),
        // Currency setting will go here later
      ],
    );
  }

  String _getThemeDisplayName(String? preference) {
    switch (preference) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'system':
      default:
        return 'System Default';
    }
  }

  Future<void> _showThemePickerDialog(BuildContext context, UserProfile profile) async {
    String? selectedTheme = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Light'),
                value: 'light',
                groupValue: profile.themePreference,
                onChanged: (String? value) => Navigator.pop(context, value),
              ),
              RadioListTile<String>(
                title: const Text('Dark'),
                value: 'dark',
                groupValue: profile.themePreference,
                onChanged: (String? value) => Navigator.pop(context, value),
              ),
              RadioListTile<String>(
                title: const Text('System Default'),
                value: 'system',
                groupValue: profile.themePreference,
                onChanged: (String? value) => Navigator.pop(context, value),
              ),
            ],
          ),
        );
      },
    );

    if (selectedTheme != null && selectedTheme != profile.themePreference) {
      await _userService.updateThemePreference(profile.uid, selectedTheme);
      // The UI will automatically update due to the StreamBuilder
    }
  }

  @override
  void initState() {
    super.initState();
    _myUid = _authService.getCurrentUser()?.uid;
    _checkUserAuthProvider();
  }

  void _checkUserAuthProvider() {
    User? currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      print("Provider Data: ${currentUser.providerData}");
      for (UserInfo providerData in currentUser.providerData) {
        if (providerData.providerId == 'password') {
          setState(() {
            _isEmailPasswordUser = true;
          });
          break;
        }
      }
    }
  } 

  void _navigateToEditProfile(UserProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(initialProfile: profile)),
    );
  }

  void _navigateToNotificationSettings() {
     Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text("Delete Account", style: TextStyle(color: theme.colorScheme.error)),
          content: const Text(
            "Are you sure you want to permanently delete your account? This action cannot be undone, and all your data will be lost.",
          ),
          actions: <Widget>[
            TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: const Text("Delete"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteAccount(context);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    if (_myUid == null) return;

    try {
      // 1. Re-authenticate user (future scope)
      User? user = _authService.getCurrentUser();
      if (user != null) {
        // 2. Delete user's profile picture from Storage
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('/profile_pictures/$_myUid.profile.jpg');
        try {
          await storageRef.delete();
          print('Profile picture deleted.');
        } catch (e) {
          print('Error deleting profile picture: $e');
        }
        await _deleteOwnedGroups(_myUid!);
        // 3. Delete the Firebase Authentication user
        await user.delete();

        // 4. Logout and navigate to AuthGate
        await _authService.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthGate()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during account deletion: $e');
      // Handle specific errors like requires-recent-login
      if (e.code == 'requires-recent-login') {
        // Prompt user to re-authenticate
        // This would typically involve navigating to a re-authentication screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please re-authenticate to delete your account.')),
          );
          // Optionally navigate to a re-authentication flow
        }
      } else {
        // Show other error messages
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: ${e.message}')),
          );
        }
      }
    } catch (e) {
      print('Error during account deletion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred while deleting your account.')),
        );
      }
    }
  }

  Future<void> _deleteOwnedGroups(String uid) async {
    // 1. Query for groups where the current user is the owner
    final QuerySnapshot groupSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('createdBy', isEqualTo: uid)
        .get();

    // 2. Iterate through the groups and delete them
    for (final doc in groupSnapshot.docs) {
      try {
        await FirebaseFirestore.instance.collection('groups').doc(doc.id).delete();
        print('Deleted group: ${doc.id}');
      } catch (e) {
        print('Error deleting group ${doc.id}: $e');
        // Consider handling errors more gracefully, perhaps logging them or showing a message to the user
      }
    }
  }

  // Sign Out Logic
  Future<void> _signOut() async {
     final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to logout?"),
            actions: <Widget>[
              TextButton( child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false)),
              TextButton( style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text("Logout"), onPressed: () => Navigator.of(context).pop(true)),
            ],
          );
        },
     );

     if (confirm == true) {
        await _authService.signOut();
         if (mounted) {
             Navigator.of(context).pop();
         }
     }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    if (_myUid == null) {
       return Scaffold(appBar: AppBar(title: const Text('My Profile')), body: const Center(child: Text("Error: Could not identify user.")));
    }

    return Scaffold(  
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _userService.getUserProfileStream(_myUid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading profile: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Profile not found."));
          }

          final UserProfile profile = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.kLargePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: profile.profilePicUrl != null
                          ? NetworkImage(profile.profilePicUrl!)
                          : null,
                      child: profile.profilePicUrl == null
                          ? Icon(Icons.person, size: 70, color: theme.colorScheme.onSurfaceVariant)
                          : null,
                    ),
                    Container(
                       decoration: BoxDecoration( color: theme.colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: theme.scaffoldBackgroundColor, width: 2)), margin: const EdgeInsets.all(4),
                       child: IconButton( icon: const Icon(Icons.edit, size: 20), color: theme.colorScheme.onPrimary, onPressed: () => _navigateToEditProfile(profile), tooltip: 'Edit Profile',),
                    )
                  ],
                ),
                const SizedBox(height: AppDimens.kSpacingMedium),
                Text(
                  profile.name,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.kSpacingSmall / 2),
                Text(
                  profile.email ?? profile.phone ?? 'No contact info',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.getMutedTextColor(brightness)),
                  textAlign: TextAlign.center,
                ),
                _buildThemeSettings(context, profile),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Account Settings", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))
                ),
                const SizedBox(height: AppDimens.kSpacingSmall),
                ListTile(
                   leading: const Icon(Icons.notifications_none_outlined),
                   title: Text("Notifications", style: theme.textTheme.bodyLarge),
                   subtitle: const Text("Manage notifications"),
                   onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                      );
                    },
                ),
                if (_isEmailPasswordUser)
                  ListTile(
                    key: const ValueKey('changePasswordTile'), // Added key for testing/identification
                    leading: const Icon(Icons.lock_outline),
                    title: Text("Change Password", style: theme.textTheme.bodyLarge),
                    subtitle: const Text("Update your account password"),
                    onTap: _navigateToChangePassword,
                    trailing: const Icon(Icons.chevron_right),
                  )
                else if (_myUid != null) // Only show this if user is identified but not email/pass type
                  ListTile(
                    key: const ValueKey('securityInfoTile'),
                    leading: Icon(Icons.shield_outlined, color: theme.disabledColor),
                    title: Text("Security", style: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor)),
                    subtitle: Text("Password settings managed by your login provider", style: TextStyle(color: theme.disabledColor)),
                    onTap: null, // Disabled
                  ),
                const SizedBox(height: AppDimens.kSpacingMedium),
                ListTile(
                  key: const ValueKey('deleteAccountTile'),
                  leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                  title: Text("Delete Account", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
                  subtitle: Text("Permanently delete your account and all data", style: TextStyle(color: theme.colorScheme.error.withOpacity(0.7))),
                  onTap: () => _confirmDeleteAccount(context),
                ),
                const SizedBox(height: AppDimens.kSpacingLarge * 2),
                ElevatedButton.icon(
                   icon: const Icon(Icons.logout),
                   label: const Text("Logout"),
                   onPressed: _signOut,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: theme.colorScheme.errorContainer,
                     foregroundColor: theme.colorScheme.onErrorContainer,
                     minimumSize: const Size(double.infinity, 45),
                     padding: AppDimens.kContinueButtonPadding,
                   ),
                ),
                const SizedBox(height: AppDimens.kSpacingMedium),
              ],
            ),
          );
        },
      ),
    );
  }
}