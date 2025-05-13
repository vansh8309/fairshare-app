import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/groups/models/group_model.dart';
import 'package:fair_share/features/groups/screens/add_members_screen.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:flutter/material.dart';

class GroupMembersTab extends StatefulWidget {
  final Group group;
  final List<UserProfile> members;

  const GroupMembersTab({
    super.key,
    required this.group,
    required this.members,
  });

  @override
  State<GroupMembersTab> createState() => _GroupMembersTabState();
}

class _GroupMembersTabState extends State<GroupMembersTab> {
  final GroupService _groupService = GroupService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _isLeavingGroup = false;
  final Map<String, bool> _isRemovingMember = {};

  // Leave Group Logic
  Future<void> _leaveGroup() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Leave Group"),
          content: Text("Are you sure you want to leave the group '${widget.group.groupName}'?"),
          actions: <Widget>[
            TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text("Leave"), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      setState(() => _isLeavingGroup = true);
      bool success = await _groupService.leaveGroup(widget.group.id);
      if (mounted) {
          if (success) {
             ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("You have left the group.")));
             Navigator.of(context).popUntil((route) => route.isFirst);
          } else {
             ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Failed to leave group."), backgroundColor: Colors.red));
             setState(() => _isLeavingGroup = false);
          }
      }
    }
  }

  // Remove Member Logic
  Future<void> _removeMember(String memberUid, String memberName) async {
     if(memberUid == _authService.getCurrentUser()?.uid) return;

     final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Remove Member"),
            content: Text("Are you sure you want to remove $memberName from the group '${widget.group.groupName}'?"),
            actions: <Widget>[
              TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false)),
              TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text("Remove"), onPressed: () => Navigator.of(context).pop(true)),
            ],
          );
        },
     );

      if (confirm == true && mounted) {
        setState(() => _isRemovingMember[memberUid] = true);
        bool success = await _groupService.removeMemberFromGroup(widget.group.id, memberUid);
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(success ? "$memberName removed." : "Failed to remove $memberName.")),
            );
            setState(() => _isRemovingMember.remove(memberUid));
        }
      }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
    final String? myUid = _authService.getCurrentUser()?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.kDefaultPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Members (${widget.members.length})", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text("Add Member"),
                style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: buttonFgColor, padding: const EdgeInsets.symmetric(horizontal: AppDimens.kDefaultPadding, vertical: AppDimens.kSmallPadding / 2), textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                onPressed: () {
                   Navigator.push( context, MaterialPageRoute(builder: (context) => AddMembersScreen( groupId: widget.group.id, groupName: widget.group.groupName, currentMemberUids: widget.group.members, )), );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Member List
        Expanded(
          child: widget.members.isEmpty
            ? const Center(child: Text("No members found in this group yet."))
            : ListView.builder(
                itemCount: widget.members.length,
                itemBuilder: (context, index) {
                  final UserProfile profile = widget.members[index];
                  final bool isMe = profile.uid == myUid;
                  final bool amICreator = myUid == widget.group.createdBy;
                  final bool isProfileTheCreator = profile.uid == widget.group.createdBy;
                  final bool isLoadingForThisMember = _isRemovingMember[profile.uid] ?? false;

                  Widget? trailingWidget;
                  if (isMe) {
                     trailingWidget = _isLeavingGroup
                       ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                       : TextButton(
                           onPressed: _leaveGroup,
                           style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                           child: const Text("Leave"),
                         );
                  } else if (amICreator && !isProfileTheCreator) {
                     trailingWidget = isLoadingForThisMember
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                           icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error),
                           tooltip: 'Remove Member',
                           onPressed: () => _removeMember(profile.uid, profile.name),
                         );
                  } else if (isProfileTheCreator) {
                      trailingWidget = Chip(label: Text('Admin', style: theme.textTheme.labelSmall), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact);
                  } else {
                      trailingWidget = null;
                  }

                  return ListTile(
                    leading: CircleAvatar( radius: 20, backgroundColor: theme.colorScheme.surfaceVariant, backgroundImage: profile.profilePicUrl != null ? NetworkImage(profile.profilePicUrl!) : null, child: profile.profilePicUrl == null ? Icon(Icons.person_outline, size: 20, color: theme.colorScheme.onSurfaceVariant) : null,),
                    title: Text(profile.name + (isMe ? ' (You)' : '')),
                    subtitle: Text(profile.email ?? profile.phone ?? 'UID: ${profile.uid}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: trailingWidget,
                  );
                },
              ),
        ),
      ],
    );
  }
}