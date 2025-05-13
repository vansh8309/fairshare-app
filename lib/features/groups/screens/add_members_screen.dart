import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/friends/models/friend_model.dart';
import 'package:fair_share/features/friends/services/friend_service.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:flutter/material.dart';

class AddMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<String> currentMemberUids;

  const AddMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentMemberUids,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final FriendService _friendService = FriendService();
  final GroupService _groupService = GroupService();

  final Map<String, bool> _addingState = {};

  late List<String> _currentMemberUidsInternal;

  @override
  void initState() {
    super.initState();
    _currentMemberUidsInternal = List.from(widget.currentMemberUids);
  }

  // Add Friend to Group Logic
  Future<void> _addFriendToGroup(Friend friend) async {
    // Prevent adding if already adding or already in our internal list
    if (_addingState[friend.uid] == true || _currentMemberUidsInternal.contains(friend.uid)) return;

    if (mounted) {
       setState(() => _addingState[friend.uid] = true);
    }

    bool success = await _groupService.addMemberToGroup(widget.groupId, friend.uid);

    if (mounted) {
        setState(() => _addingState.remove(friend.uid));

        if (success) {
            setState(() {
               _currentMemberUidsInternal.add(friend.uid);
            });
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("${friend.name} added to group."),
                    backgroundColor: AppColors.success,
                )
            );
        } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Failed to add ${friend.name}."),
                    backgroundColor: Theme.of(context).colorScheme.error,
                )
            );
        }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Friends to ${widget.groupName}'),
      ),
      body: StreamBuilder<List<Friend>>(
        stream: _friendService.getFriendsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading friends: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.kLargePadding),
                child: Text('You have no friends to add.\nAdd friends from the main Friends tab first.', textAlign: TextAlign.center,),
              ),
            );
          }
          final List<Friend> friendsToAdd = snapshot.data!
              .where((friend) => !_currentMemberUidsInternal.contains(friend.uid))
              .toList();
          if (friendsToAdd.isEmpty) {
             return const Center(
               child: Padding(
                padding: EdgeInsets.all(AppDimens.kLargePadding),
                child: Text('All your friends are already in this group.', textAlign: TextAlign.center,),
               ),
             );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.kSmallPadding),
            itemCount: friendsToAdd.length,
            itemBuilder: (context, index) {
              final Friend friend = friendsToAdd[index];
              final bool isAdding = _addingState[friend.uid] ?? false;

              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  backgroundImage: friend.profilePicUrl != null ? NetworkImage(friend.profilePicUrl!) : null,
                  child: friend.profilePicUrl == null ? Icon(Icons.person_outline, size: 20, color: theme.colorScheme.onSurfaceVariant) : null,
                ),
                title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.secondary,
                     foregroundColor: buttonFgColor,
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     textStyle: theme.textTheme.labelSmall,
                  ),
                  onPressed: isAdding ? null : () => _addFriendToGroup(friend),
                  child: isAdding
                     ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                     : const Text('Add'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}