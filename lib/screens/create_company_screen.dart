import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/company_provider.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/gradient_background.dart';

class CreateCompanyScreen extends StatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  State<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends State<CreateCompanyScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isLoading = false;
  File? _logoFile;
  File? _bannerFile;

  Future<void> _pickImage(bool isLogo) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: isLogo
          ? const CropAspectRatio(ratioX: 1, ratioY: 1)
          : const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isLogo ? 'Crop Company Logo' : 'Crop Company Banner',
          toolbarColor: AppColors.darkBlue,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.accentBlue,
          initAspectRatio: isLogo
              ? CropAspectRatioPreset.square
              : CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: true,
          cropStyle: isLogo ? CropStyle.circle : CropStyle.rectangle,
        ),
        IOSUiSettings(
          title: isLogo ? 'Crop Company Logo' : 'Crop Company Banner',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        if (isLogo) {
          _logoFile = File(croppedFile.path);
        } else {
          _bannerFile = File(croppedFile.path);
        }
      });
    }
  }

  void _createCompany() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company name is required.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) throw Exception("User not logged in");

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await Provider.of<CompanyProvider>(context, listen: false).createCompany(
        name,
        user.id,
        '', // iconUrl
        '', // bannerUrl
        _descriptionController.text.trim(),
        tags,
        logoFile: _logoFile,
        bannerFile: _bannerFile,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating company: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Create Company',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Image Header Section (Banner + Logo)
            SizedBox(
              height: 220, // 160 for banner + 60 for avatar overlap
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Banner Area
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: _bannerFile != null
                          ? DecorationImage(
                              image: FileImage(_bannerFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.02)],
                      ),
                    ),
                    child: _bannerFile == null
                        ? Center(
                            child: Icon(
                              Icons.landscape,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          )
                        : null,
                  ),
                  // Banner Gradient Overlay
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                      ),
                    ),
                  ),
                  // Banner Edit Button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => _pickImage(false),
                      ),
                    ),
                  ),

                  // Overlapping Logo Avatar
                  Positioned(
                    bottom: 0,
                    left: 24, // LinkedIn typically aligns left
                    child: Container(
                      padding: const EdgeInsets.all(4), // White border effect
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        backgroundImage:
                            _logoFile != null ? FileImage(_logoFile!) : null,
                        child: _logoFile == null
                            ? Icon(
                                Icons.business,
                                size: 40,
                                color: Colors.white.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Logo Edit Button
                  Positioned(
                    bottom: 0,
                    left: 84, // Slightly offset from the avatar's right edge
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accentBlue,
                      child: IconButton(
                        iconSize: 16,
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: () => _pickImage(true),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Form Fields Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Company Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: _nameController,
                    label: "Company Name *",
                    hint: "e.g., Acme Corp",
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _descriptionController,
                    label: "Description",
                    hint: "What does your company do?",
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _tagsController,
                    label: "Tags / Industries",
                    hint: "e.g., Technology, Gaming (Comma separated)",
                  ),
                  const SizedBox(height: 32),

                  // Create Button
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [AppColors.lightBlue, AppColors.accentBlue],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentBlue.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _createCompany,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Create Company",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.accentBlue,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
