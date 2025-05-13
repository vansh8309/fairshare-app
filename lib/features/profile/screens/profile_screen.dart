import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:fair_share/features/profile/screens/edit_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  late final String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = _authService.getCurrentUser()?.uid;
  }

  void _navigateToEditProfile(UserProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(initialProfile: profile)),
    );
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
                const SizedBox(height: AppDimens.kSpacingLarge),
                const Divider(),
                const SizedBox(height: AppDimens.kSpacingMedium),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Account Settings", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))
                ),
                const SizedBox(height: AppDimens.kSpacingSmall),
                ListTile(
                   leading: const Icon(Icons.notifications_none_outlined),
                   title: Text("Notifications", style: theme.textTheme.bodyLarge),
                   subtitle: const Text("Manage push notifications (Coming Soon)"),
                   onTap: () { /* TODO: Navigate to Notification Settings */ },
                ),
                ListTile(
                   leading: const Icon(Icons.shield_outlined),
                   title: Text("Security", style: theme.textTheme.bodyLarge),
                   subtitle: const Text("Change password, etc. (Coming Soon)"),
                    onTap: () { /* TODO: Navigate to Security Settings */ },
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