import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fair_share/features/home/screens/home_screen.dart';
import 'package:image_picker/image_picker.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker(); 

  File? _selectedImageFile;
  bool _isLoading = false;

  // Image Picking Logic
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      } else {
         print("Image picking cancelled.");
      }
    } catch (e) {
       print("Error picking image: $e");
       if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error picking image: $e')),
           );
       }
    }
  }

  void _showImageSourceActionSheet() {
     showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  }),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                   Navigator.of(context).pop(); 
                   _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ));
  }


  // Upload Image and Save Profile Logic
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _authService.getCurrentUser();
    if (user == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Error: No authenticated user found.')),);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    String? profilePicDownloadUrl;

    try {
      // Upload Image if selected
      if (_selectedImageFile != null) {
        print("Uploading profile picture...");
        final String filePath = 'profile_pictures/${user.uid}/profile.jpg';
        final Reference storageRef = FirebaseStorage.instance.ref().child(filePath);

        final UploadTask uploadTask = storageRef.putFile(_selectedImageFile!);

        final TaskSnapshot snapshot = await uploadTask;

        profilePicDownloadUrl = await snapshot.ref.getDownloadURL();
        print("Profile picture uploaded successfully: $profilePicDownloadUrl");
      } else {
         print("No new profile picture selected.");
      }

      final name = _nameController.text.trim();
      print("Saving profile to Firestore for UID: ${user.uid} with name: $name");

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
         'uid': user.uid,
         'name': name,
         'email': user.email,
         'phone': user.phoneNumber,
         'profilePicUrl': profilePicDownloadUrl,
         'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("Profile saved successfully to Firestore.");

      if (mounted) {
         Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
         );
      }

    } catch (e) {
       print("!!!! Error saving profile !!!!: $e");
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
          );
          setState(() { _isLoading = false; });
       }
    }
  }

   @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.primary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.kLargePadding),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'One last step! Tell us your name.',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimens.kSpacingLarge),

                  // Profile Picture Area
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        backgroundImage: _selectedImageFile != null
                             ? FileImage(_selectedImageFile!)
                             : null,
                        child: _selectedImageFile == null
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      Container(
                         decoration: BoxDecoration(
                             color: theme.colorScheme.primary,
                             shape: BoxShape.circle,
                             border: Border.all(color: theme.scaffoldBackgroundColor, width: 2)
                         ),
                         margin: const EdgeInsets.all(4),
                         child: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: Colors.white,
                            onPressed: _showImageSourceActionSheet,
                            tooltip: 'Change Profile Picture',
                         ),
                      )
                    ],
                  ),
                  const SizedBox(height: AppDimens.kSpacingVLarge),

                  // Name Input Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Display Name',
                      hintText: 'Enter your full name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.trim().length < 2) {
                         return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onFieldSubmitted: (_) => _saveProfile(),
                  ),
                  const SizedBox(height: AppDimens.kSpacingVLarge),

                  // Save Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                       backgroundColor: AppColors.primary,
                       foregroundColor: buttonFgColor,
                       padding: const EdgeInsets.symmetric(vertical: 15),
                       minimumSize: const Size(double.infinity, 50)
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Save & Continue'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}