import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:flutter/material.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final GroupService _groupService = GroupService();

  final List<String> _groupTypes = ['Travel', 'Rent', 'Food', 'Shopping', 'Car Pool', 'Other'];
  String? _selectedGroupType;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Create Group Logic
  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final String? newGroupId = await _groupService.createGroup(
        _nameController.text,
        _selectedGroupType!,
      );

      if (newGroupId != null && mounted) {
        print("CreateGroupScreen: Group created successfully with ID: $newGroupId");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!'), duration: Duration(seconds: 2)),
        );
        Navigator.pop(context);
      } else if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Failed to create group. User might be logged out.')),
         );
         setState(() => _isLoading = false);
      }
    } catch (e) {
       print("CreateGroupScreen: Error creating group: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('An error occurred: ${e.toString()}')),
           );
           setState(() { _isLoading = false; });
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
        title: const Text('Create New Group'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.kSpacingMedium),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'E.g., Office Lunch Club, Goa Trip...',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a group name';
                    }
                    if (value.trim().length < 3) {
                       return 'Group name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.kSpacingLarge),

                DropdownButtonFormField<String>(
                  value: _selectedGroupType,
                  decoration: const InputDecoration(
                    labelText: 'Group Type',
                  ),
                  hint: const Text('Select group type'),
                  items: _groupTypes.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() { _selectedGroupType = newValue; });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a group type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.kSpacingVLarge),

                ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.secondary,
                     foregroundColor: buttonFgColor,
                     padding: AppDimens.kContinueButtonPadding,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),
                  ),
                  child: _isLoading
                     ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: buttonFgColor))
                     : const Text('Create Group'),
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