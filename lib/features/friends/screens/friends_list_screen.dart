import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/friends/models/friend_model.dart';
import 'package:fair_share/features/friends/models/friend_request_model.dart';
import 'package:fair_share/features/friends/services/friend_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:flutter/material.dart';

class FriendsListScreen extends StatefulWidget {
  final String searchQuery;

  const FriendsListScreen({super.key, required this.searchQuery});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final FriendService _friendService = FriendService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  final Map<String, bool> _requestLoadingState = {};

  // Add Friend Dialog Logic
  Future<void> _showAddFriendDialog() async {
    final TextEditingController searchController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    bool isSearching = false;
    String? dialogMessage;
    bool isError = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Friend"),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Enter the exact email or phone number (+country code) of the user to send a request."),
                    const SizedBox(height: AppDimens.kSpacingMedium),
                    TextFormField(
                      controller: searchController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email or Phone Number',
                        hintText: 'user@example.com or +91...',
                      ),
                      validator: (value) {
                         if (value == null || value.trim().isEmpty) { return 'Please enter an email or phone number'; } return null;
                      },
                    ),
                     Visibility(
                        visible: dialogMessage != null,
                        child: Padding(
                         padding: const EdgeInsets.only(top: AppDimens.kSmallPadding),
                         child: Text(dialogMessage ?? '', style: TextStyle(color: isError ? Theme.of(context).colorScheme.error : AppColors.success)),
                       ),
                     ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: isSearching ? null : () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                   style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: AppColors.getButtonForegroundColor(AppColors.secondary),),
                   onPressed: isSearching ? null : () async {
                     setDialogState(() { dialogMessage = null; isError = false; });
                     if (dialogFormKey.currentState!.validate()) {
                        final searchTerm = searchController.text.trim();
                        final String? myUid = _authService.getCurrentUser()?.uid;
                        if(myUid == null) { setDialogState(() { dialogMessage = "Error: Not logged in."; isError = true; }); return; }

                         setDialogState(() => isSearching = true);
                         try {
                            final UserProfile? foundUser = await _userService.findUserByEmailOrPhone(searchTerm);
                            if (foundUser == null) { setDialogState(() { dialogMessage = "User not found."; isError = true; }); }
                            else if (foundUser.uid == myUid) { setDialogState(() { dialogMessage = "You cannot send a request to yourself."; isError = true; }); }
                            else {
                                bool success = await _friendService.sendFriendRequest(foundUser.uid);
                                if (success && mounted) {
                                   setDialogState(() { dialogMessage = "Friend request sent to ${foundUser.name}!"; isError = false; searchController.clear();});
                                } else if (!success && mounted) {
                                     setDialogState(() { dialogMessage = "Could not send request (already friends or request pending?)."; isError = true; });
                                }
                            }
                         } catch(e) { print("Error during add friend process: $e"); setDialogState(() { dialogMessage = "An error occurred."; isError = true; }); }
                         finally { if(mounted) { setDialogState(() => isSearching = false); } }
                     }
                  },
                  child: isSearching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }


   //Remove Friend Logic
  Future<void> _removeFriend(String friendUid, String friendName) async {
     final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text("Remove Friend"), content: Text("Remove $friendName?"), actions: <Widget>[ TextButton( child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false), ), TextButton( style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text("Remove"), onPressed: () => Navigator.of(context).pop(true), ), ], ); }, );
     if (confirm == true) {
        bool success = await _friendService.removeFriend(friendUid);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(success ? "$friendName removed." : "Failed to remove friend.")), ); }
     }
  }


  // Accept Friend Request Logic
   Future<void> _acceptRequest(FriendRequest request) async {
      if (!mounted) return;
      setState(() => _requestLoadingState[request.id] = true);
      bool success = await _friendService.acceptFriendRequest(request);
       if (mounted) {
         setState(() => _requestLoadingState.remove(request.id));
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(success ? "Accepted ${request.senderName}'s request!" : "Failed to accept request.")),);
       }
   }

    // Decline Friend Request Logic
   Future<void> _declineRequest(String requestId) async {
      if (!mounted) return;
      setState(() => _requestLoadingState[requestId] = true);
      bool success = await _friendService.declineFriendRequest(requestId);
       if (mounted) {
         setState(() => _requestLoadingState.remove(requestId));
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(success ? "Declined request." : "Failed to decline request.")),);
       }
   }

    // Cancel Friend Request Logic
   Future<void> _cancelRequest(String requestId) async {
      bool success = await _friendService.cancelFriendRequest(requestId);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(success ? "Request cancelled." : "Failed to cancel request.")),
         );
      }
   }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add Friend Button
         Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.kLargePadding, AppDimens.kDefaultPadding, AppDimens.kLargePadding, AppDimens.kSmallPadding),
            child: SizedBox( width: double.infinity, child: ElevatedButton.icon( icon: const Icon(Icons.person_add_outlined, size: 20), label: const Text("Add Friend"), style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: buttonFgColor, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),), onPressed: _showAddFriendDialog,),),
         ),
         const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding,),
         _buildIncomingRequests(context, theme),
         _buildSentRequests(context, theme),
         Padding(
           padding: EdgeInsets.only(
             left: AppDimens.kLargePadding, right: AppDimens.kLargePadding,
             // Add top padding only if requests were shown (or always)
             top: AppDimens.kDefaultPadding,
             bottom: AppDimens.kSmallPadding,
            ),
           child: Text("My Friends", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
         ),
         const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding,),


        // Existing Friends List Stream
        Expanded(
          child: StreamBuilder<List<Friend>>(
            stream: _friendService.getFriendsStream(),
            builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (snapshot.hasError) { return Center(child: Text('Error: ${snapshot.error}')); }
                if (!snapshot.hasData || snapshot.data!.isEmpty) { return const Center(child: Padding(padding: EdgeInsets.all(AppDimens.kLargePadding), child: Text('No friends added yet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey),),),); }
                final List<Friend> allFriends = snapshot.data!;
                final List<Friend> filteredFriends = allFriends.where((friend) {
                    if (widget.searchQuery.isEmpty) {
                        return true;
                    }
                    return friend.name.toLowerCase().contains(widget.searchQuery.toLowerCase());
                }).toList();

                if (filteredFriends.isEmpty && allFriends.isNotEmpty) {
                  return Center( child: Padding( padding: const EdgeInsets.all(AppDimens.kLargePadding), child: Text( 'No Friend found matching "${widget.searchQuery}".', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey), ),), );
                }
                return ListView.separated(
                    itemCount: allFriends.length, padding: const EdgeInsets.only(bottom: AppDimens.kLargePadding), separatorBuilder: (context, index) => const Divider(height: 1, indent: AppDimens.kLargePadding + 56, endIndent: AppDimens.kLargePadding,),
                    itemBuilder: (context, index) { final Friend friend = allFriends[index]; return ListTile( contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding / 2), leading: CircleAvatar( radius: 20, backgroundColor: theme.colorScheme.surfaceVariant, backgroundImage: friend.profilePicUrl != null ? NetworkImage(friend.profilePicUrl!) : null, child: friend.profilePicUrl == null ? Icon(Icons.person_outline, size: 20, color: theme.colorScheme.onSurfaceVariant) : null, ), title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w500)), trailing: IconButton( icon: Icon(Icons.person_remove_outlined, color: theme.colorScheme.error), tooltip: 'Remove Friend', onPressed: () => _removeFriend(friend.uid, friend.name), ), onTap: () { print('Tapped on Friend: ${friend.name}'); }, ); },
                );
            },
          ),
        ),
      ],
    );
  }

  // Builder for Incoming Friend Requests
  Widget _buildIncomingRequests(BuildContext context, ThemeData theme) {
     return StreamBuilder<List<FriendRequest>>(
        stream: _friendService.getIncomingFriendRequestsStream(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) { return const SizedBox(height: 10); }
           if (!snapshot.hasData || snapshot.data!.isEmpty) { return const SizedBox.shrink(); } 
           final List<FriendRequest> requests = snapshot.data!;
           return ExpansionTile(
             key: const ValueKey('incoming_requests_tile'),
             title: Text("Friend Requests (${requests.length})", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
             initiallyExpanded: true,
             childrenPadding: const EdgeInsets.only(bottom: AppDimens.kSmallPadding),
             children: [
               ListView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: requests.length,
                    itemBuilder: (context, index) {
                       final request = requests[index];
                       final bool isLoading = _requestLoadingState[request.id] ?? false;
                       return ListTile(
                           leading: CircleAvatar( radius: 20, backgroundColor: theme.colorScheme.surfaceVariant, backgroundImage: request.senderProfilePicUrl != null ? NetworkImage(request.senderProfilePicUrl!) : null, child: request.senderProfilePicUrl == null ? const Icon(Icons.person_outline, size: 20) : null, ),
                           title: Text(request.senderName, style: const TextStyle(fontWeight: FontWeight.w500)),
                           subtitle: const Text("Sent you a friend request"),
                           trailing: isLoading
                             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                             : Row( mainAxisSize: MainAxisSize.min, children: [
                                  IconButton( icon: Icon(Icons.check_circle, color: AppColors.success), iconSize: 28, tooltip: 'Accept', onPressed: () => _acceptRequest(request), ),
                                  IconButton( icon: Icon(Icons.cancel, color: theme.colorScheme.error), iconSize: 28, tooltip: 'Decline', onPressed: () => _declineRequest(request.id), ),
                                ], ),
                       );
                    },
                 ),
                  const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding,),
             ]
           );
        },
     );
  }

  // Builder for Sent Friend Requests
  Widget _buildSentRequests(BuildContext context, ThemeData theme) {
     return StreamBuilder<List<FriendRequest>>(
        stream: _friendService.getSentFriendRequestsStream(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
           }
           final List<FriendRequest> requests = snapshot.data!;
           return ExpansionTile(
             key: const ValueKey('sent_requests_tile'),
             title: Text("Sent Requests (${requests.length})", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
             initiallyExpanded: false,
             childrenPadding: const EdgeInsets.only(bottom: AppDimens.kSmallPadding),
             children: [
               ListView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: requests.length,
                    itemBuilder: (context, index) {
                       final request = requests[index];
                       return FutureBuilder<UserProfile?>(
                          future: _userService.getUserProfile(request.receiverUid),
                          builder: (context, userSnapshot) {
                             String receiverName = 'Loading...'; String? receiverPicUrl;
                             if(userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData && userSnapshot.data != null) { receiverName = userSnapshot.data!.name; receiverPicUrl = userSnapshot.data!.profilePicUrl; }
                             else if (userSnapshot.connectionState == ConnectionState.done) { receiverName = 'Unknown User'; }

                            return ListTile(
                                leading: CircleAvatar( radius: 20, backgroundColor: theme.colorScheme.surfaceVariant, backgroundImage: receiverPicUrl != null ? NetworkImage(receiverPicUrl) : null, child: receiverPicUrl == null ? const Icon(Icons.person_outline, size: 20) : null, ),
                                title: Text(receiverName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: const Text("Request pending"),
                                trailing: TextButton( style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error), child: const Text('Cancel'), onPressed: () => _cancelRequest(request.id), ),
                            );
                          }
                       );
                    },
                 ),
                 const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding,),
             ]
           );
        },
     );
  }

}