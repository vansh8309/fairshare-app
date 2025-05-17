import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Placeholder states for notification toggles
  // In a real app, these would be loaded from a service (e.g., SharedPreferences or Firestore)
  bool _masterPushNotifications = true; // Overall switch for all notifications
  bool _newExpenseInGroup = true;
  bool _expenseEditedDeleted = true;
  bool _newFriendRequest = true;
  bool _friendRequestAccepted = true;
  bool _settlementRecorded = true;
  // Add more specific notification toggles as needed

  @override
  void initState() {
    super.initState();
    // TODO: Load initial notification settings from SharedPreferences or backend
    // For example:
    // _loadNotificationPreferences();
  }

  // --- Placeholder for loading preferences ---
  // Future<void> _loadNotificationPreferences() async {
  //   // final prefs = await SharedPreferences.getInstance();
  //   // setState(() {
  //   //   _masterPushNotifications = prefs.getBool('masterPushNotifications') ?? true;
  //   //   _newExpenseInGroup = prefs.getBool('newExpenseInGroup') ?? true;
  //   //   // ... load other preferences
  //   // });
  // }

  // --- Placeholder for saving a preference ---
  // Future<void> _updateNotificationPreference(String key, bool value) async {
  //   // final prefs = await SharedPreferences.getInstance();
  //   // await prefs.setBool(key, value);
  //   // TODO: If settings are also stored in backend, update them here
  //   // For example:
  //   // await _userService.updateNotificationPreference(key, value);
  //   print("Notification setting '$key' updated to $value (Placeholder)");
  // }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.kLargePadding,
        bottom: AppDimens.kSmallPadding,
        left: AppDimens.kLargePadding,
        right: AppDimens.kLargePadding,
      ),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        children: <Widget>[
          _buildHeader("General"),
          SwitchListTile(
            title: Text('Push Notifications', style: theme.textTheme.titleMedium),
            subtitle: Text(
                _masterPushNotifications ? 'Receive all push notifications' : 'All push notifications are disabled',
                 style: theme.textTheme.bodySmall,
            ),
            value: _masterPushNotifications,
            onChanged: (bool value) {
              setState(() {
                _masterPushNotifications = value;
                // If master is turned off, consider turning off all sub-notifications
                if (!value) {
                  _newExpenseInGroup = false;
                  _expenseEditedDeleted = false;
                  _newFriendRequest = false;
                  _friendRequestAccepted = false;
                  _settlementRecorded = false;
                }
              });
              // TODO: _updateNotificationPreference('masterPushNotifications', value);
              print("Master Push Notifications Toggled: $value (Placeholder - actual saving not implemented)");
            },
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding /2),
          ),
          const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding),

          _buildHeader("Group Activity"),
          SwitchListTile(
            title: Text('New Expense in Group', style: theme.textTheme.titleMedium),
            subtitle: Text('Notify when a member adds an expense', style: theme.textTheme.bodySmall),
            value: _newExpenseInGroup,
            onChanged: _masterPushNotifications ? (bool value) {
              setState(() {
                _newExpenseInGroup = value;
              });
              // TODO: _updateNotificationPreference('newExpenseInGroup', value);
               print("New Expense in Group Toggled: $value (Placeholder - actual saving not implemented)");
            } : null, // Disabled if master push notifications are off
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding /2),
          ),
          SwitchListTile(
            title: Text('Expense Updates', style: theme.textTheme.titleMedium),
            subtitle: Text('Notify on expense edits or deletions', style: theme.textTheme.bodySmall),
            value: _expenseEditedDeleted,
            onChanged: _masterPushNotifications ? (bool value) {
              setState(() {
                _expenseEditedDeleted = value;
              });
              // TODO: _updateNotificationPreference('expenseEditedDeleted', value);
              print("Expense Updates Toggled: $value (Placeholder - actual saving not implemented)");
            } : null,
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding /2),
          ),
           SwitchListTile(
            title: Text('Settlements Recorded', style: theme.textTheme.titleMedium),
            subtitle: Text('Notify when a settlement is recorded in your groups', style: theme.textTheme.bodySmall),
            value: _settlementRecorded,
            onChanged: _masterPushNotifications ? (bool value) {
              setState(() {
                _settlementRecorded = value;
              });
              // TODO: _updateNotificationPreference('settlementRecorded', value);
              print("Settlements Recorded Toggled: $value (Placeholder - actual saving not implemented)");
            } : null,
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding /2),
          ),
          const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding),

         _buildHeader("Friend Activity"),
          SwitchListTile(
            title: Text('New Friend Request', style: theme.textTheme.titleMedium),
            subtitle: Text('Notify when someone sends you a friend request', style: theme.textTheme.bodySmall),
            value: _newFriendRequest,
            onChanged: _masterPushNotifications ? (bool value) {
              setState(() {
                _newFriendRequest = value;
              });
              // TODO: _updateNotificationPreference('newFriendRequest', value);
              print("New Friend Request Toggled: $value (Placeholder - actual saving not implemented)");
            } : null,
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding /2),
          ),
          SwitchListTile(
            title: Text('Friend Request Accepted', style: theme.textTheme.titleMedium),
            subtitle: Text('Notify when your friend request is accepted', style: theme.textTheme.bodySmall),
            value: _friendRequestAccepted,
            onChanged: _masterPushNotifications ? (bool value) {
              setState(() {
                _friendRequestAccepted = value;
              });
              // TODO: _updateNotificationPreference('friendRequestAccepted', value);
               print("Friend Request Accepted Toggled: $value (Placeholder - actual saving not implemented)");
            } : null,
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding /2),
          ),
          // Add more SwitchListTiles for other notification types as needed
        ],
      ),
    );
  }
}