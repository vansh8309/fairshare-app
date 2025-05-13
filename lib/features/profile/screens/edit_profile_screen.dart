import 'dart:io';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;

  const EditProfileScreen({super.key, required this.initialProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImageFile;
  String? _currentImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _currentImageUrl = widget.initialProfile.profilePicUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Image Picking Logic
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
      if (pickedFile != null) {
        // TODO: Optional Cropping
        setState(() { _selectedImageFile = File(pickedFile.path); });
      }
    } catch (e) {
         print("Error picking image: $e"); if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e'))); }
    }
  }

  void _showImageSourceActionSheet() { 
      showModalBottomSheet( context: context, builder: (context) => SafeArea( child: Wrap( children: <Widget>[ ListTile( leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () { Navigator.of(context).pop(); _pickImage(ImageSource.gallery); }), ListTile( leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () { Navigator.of(context).pop(); _pickImage(ImageSource.camera); }, ), ], ), ));
  }


  // Update Profile Logic
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final String? myUid = _authService.getCurrentUser()?.uid;
    if (myUid == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not found.')));
       return;
    }

    if (mounted) setState(() => _isLoading = true);

    String? newImageUrl = _currentImageUrl;

    try {
      if (_selectedImageFile != null) {
        print("Uploading new profile picture...");
        final String filePath = 'profile_pictures/$myUid/profile.jpg';
        final Reference storageRef = FirebaseStorage.instance.ref().child(filePath);
        final UploadTask uploadTask = storageRef.putFile(_selectedImageFile!);
        final TaskSnapshot snapshot = await uploadTask;
        newImageUrl = await snapshot.ref.getDownloadURL();
        print("New image uploaded: $newImageUrl");
      }

      final String newName = _nameController.text.trim();
      Map<String, dynamic> updateData = {
        'name': newName,
        if (newImageUrl != _currentImageUrl || (_currentImageUrl == null && newImageUrl != null))
           'profilePicUrl': newImageUrl,
      };

      bool nameChanged = newName != widget.initialProfile.name;
      bool picChanged = newImageUrl != widget.initialProfile.profilePicUrl;

      if (!nameChanged && !picChanged) {
          print("No changes detected.");
          if(mounted) Navigator.pop(context);
          return; 
      }

      bool success = await _userService.updateUserProfile(myUid, updateData);

      if (success && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
         Navigator.pop(context, true);
      } else if (mounted) {
         throw Exception("Failed to update profile in Firestore.");
      }

    } catch (e) {
       print("EditProfileScreen: Error updating profile: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: ${e.toString()}'), backgroundColor: Colors.red));
       }
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saveButtonFgColor = AppColors.getButtonForegroundColor(AppColors.primary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isLoading
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)))
              : TextButton(
                  onPressed: _updateProfile,
                  child: Text('SAVE', style: TextStyle(color: theme.appBarTheme.foregroundColor ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black), fontWeight: FontWeight.bold)),
                ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppDimens.kSpacingMedium),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      backgroundImage: _selectedImageFile != null
                          ? FileImage(_selectedImageFile!) as ImageProvider
                          : (_currentImageUrl != null
                              ? NetworkImage(_currentImageUrl!)
                              : null),
                      child: (_selectedImageFile == null && _currentImageUrl == null)
                          ? Icon(Icons.person_outline, size: 60, color: theme.colorScheme.onSurfaceVariant)
                          : null,
                    ),
                    Container(
                       decoration: BoxDecoration( color: theme.colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: theme.scaffoldBackgroundColor, width: 2)), margin: const EdgeInsets.all(4), child: IconButton( icon: const Icon(Icons.edit, size: 20), color: theme.colorScheme.onPrimary, onPressed: _showImageSourceActionSheet, tooltip: 'Change Profile Picture',),
                    )
                  ],
                ),
                const SizedBox(height: AppDimens.kSpacingVLarge),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration( labelText: 'Display Name', hintText: 'Enter your full name',),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { return 'Please enter your name'; }
                    if (value.trim().length < 2) { return 'Name must be at least 2 characters'; }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _updateProfile(),
                ),
                const SizedBox(height: AppDimens.kSpacingLarge * 2),

                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}