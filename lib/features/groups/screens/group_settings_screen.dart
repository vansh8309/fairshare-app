import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/groups/models/group_model.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:flutter/material.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Group group;

  const GroupSettingsScreen({super.key, required this.group});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final GroupService _groupService = GroupService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isDeleting = false;
  String? _errorMessage;
  late bool _isCreator;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.groupName);
    _isCreator = _authService.getCurrentUser()?.uid == widget.group.createdBy;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Update Group Name Logic
  Future<void> _updateGroupName() async {
     setState(() { _errorMessage = null; });
     if (!_formKey.currentState!.validate()) return;

     final newName = _nameController.text.trim();
     if (newName == widget.group.groupName) {
         Navigator.pop(context);
         return;
     }

     setState(() => _isLoading = true);
     bool success = await _groupService.updateGroupName(widget.group.id, newName);
     if (mounted) {
         setState(() => _isLoading = false);
         if (success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name updated!')));
            Navigator.pop(context);
         } else {
            setState(() => _errorMessage = "Failed to update group name.");
         }
     }
  }

  // Delete Group Logic
  Future<void> _deleteGroup() async {
     final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text("Delete Group"), content: Text("Are you sure you want to permanently delete '${widget.group.groupName}'? All associated expenses will remain but may be inaccessible."), actions: <Widget>[ TextButton( child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false)), TextButton( style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text("DELETE"), onPressed: () => Navigator.of(context).pop(true)), ], ); }, );

     if (confirm == true && mounted) {
        setState(() => _isDeleting = true);
        bool success = await _groupService.deleteGroup(widget.group.id);
         if (mounted) {
           if (success) {
              ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Group deleted.")));
              Navigator.of(context).popUntil((route) => route.isFirst);
           } else {
               ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Failed to delete group."), backgroundColor: Colors.red));
               setState(() => _isDeleting = false);
           }
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.primary);

    return Scaffold(
      appBar: AppBar(title: const Text('Group Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 Text("Group Name", style: theme.textTheme.labelLarge),
                 const SizedBox(height: AppDimens.kSmallPadding),
                 TextFormField(
                   controller: _nameController,
                   decoration: const InputDecoration( hintText: 'Enter group name',),
                   validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a name';
                      if (value.trim().length < 3) return 'Name must be at least 3 characters';
                      return null;
                   },
                 ),
                 const SizedBox(height: AppDimens.kSpacingLarge),

                 ElevatedButton(
                   onPressed: _isLoading ? null : _updateGroupName,
                   style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.getButtonForegroundColor(AppColors.secondary),
                      padding: AppDimens.kContinueButtonPadding,
                   ),
                   child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes'),
                 ),

                 const SizedBox(height: AppDimens.kSpacingVLarge),
                 const Divider(),
                 const SizedBox(height: AppDimens.kSpacingMedium),

                 Visibility(
                    visible: _isCreator,
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                          Text("Danger Zone", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                          const SizedBox(height: AppDimens.kSmallPadding),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Delete This Group'),
                            onPressed: _isDeleting ? null : _deleteGroup,
                            style: ElevatedButton.styleFrom(
                               backgroundColor: theme.colorScheme.errorContainer,
                               foregroundColor: theme.colorScheme.onErrorContainer,
                                padding: AppDimens.kContinueButtonPadding,
                            ),
                          ),
                           const SizedBox(height: AppDimens.kSmallPadding),
                          Text(
                             "Deleting a group is permanent and cannot be undone. Associated expenses will remain but may become inaccessible.",
                             style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          ),
                       ],
                    ),
                 ),

                if (_errorMessage != null)
                   Padding(
                     padding: const EdgeInsets.only(top: AppDimens.kSpacingMedium),
                     child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
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