import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../models/company_model.dart';
import '../providers/company_provider.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../theme.dart';
import '../widgets/gradient_background.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final Company company;

  const CompanyDetailsScreen({super.key, required this.company});

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;
  late TextEditingController _logoUrlController;
  late TextEditingController _bannerUrlController;

  bool _isEditing = false;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final CompanyService _companyService = CompanyService();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.company.name);
    _descriptionController = TextEditingController(
      text: widget.company.description,
    );
    _tagsController = TextEditingController(
      text: widget.company.tags.join(', '),
    );
    _logoUrlController = TextEditingController(text: widget.company.iconUrl);
    _bannerUrlController = TextEditingController(
      text: widget.company.bannerUrl,
    );
  }

  @override
  void didUpdateWidget(covariant CompanyDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.company != oldWidget.company) {
      _initControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _logoUrlController.dispose();
    _bannerUrlController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        // Cancel edit: revert controllers
        _initControllers();
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _pickImage(bool isLogo) async {
    // Show modal bottom sheet to choose between camera and gallery
    await showModalBottomSheet(
      context: context,
      builder: (BottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _processPickedImage(ImageSource.gallery, isLogo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _processPickedImage(ImageSource.camera, isLogo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processPickedImage(ImageSource source, bool isLogo) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
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
          _isLoading = true;
        });

        final String? downloadUrl = await _companyService.uploadCompanyAsset(
          File(croppedFile.path),
          isLogo ? 'logo' : 'banner',
        );

        if (downloadUrl != null) {
          setState(() {
            if (isLogo) {
              _logoUrlController.text = downloadUrl;
            } else {
              _bannerUrlController.text = downloadUrl;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${isLogo ? 'Logo' : 'Banner'} uploaded successfully!',
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
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
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await Provider.of<CompanyProvider>(context, listen: false).updateCompany(
        companyId: widget.company.id,
        name: name,
        iconUrl: _logoUrlController.text.trim(),
        bannerUrl: _bannerUrlController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: tags,
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating company: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: const Text('Delete Server', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this server? This action is permanent and will remove all channels and messages.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await Provider.of<CompanyProvider>(context, listen: false)
            .deleteCompany(widget.company.id);
        
        if (mounted) {
          Navigator.of(context).pop(); // Back to Home
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting server: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isOwner = user?.id == widget.company.ownerId;
    // Don't allow editing the mock 'null-corp'
    final canEdit = isOwner && widget.company.id != 'null-corp';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (canEdit && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEdit,
              tooltip: 'Edit Company',
            ),
          if (canEdit && _isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleEdit,
              tooltip: 'Cancel Edit',
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Banner & Logo Stack
                    _buildHeader(canEdit),
                    const SizedBox(height: 16),
                    // Form Content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Created Year
                          Center(
                            child: Text(
                              'Since ${widget.company.createdAt.year}',
                              style: TextStyle(
                                color: AppColors.accentBlue.withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          if (_isEditing) ...[
                            _buildTextField(
                              controller: _nameController,
                              label: "Company Name *",
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _descriptionController,
                              label: "Description",
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _tagsController,
                              label: "Tags (Comma separated)",
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentBlue,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _saveChanges,
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else ...[
                            // View Mode
                            _buildInfoSection(
                              'Description',
                              widget.company.description.isEmpty
                                  ? 'No description provided.'
                                  : widget.company.description,
                            ),
                            const SizedBox(height: 24),
                            _buildInfoSection(
                              'Tags',
                              widget.company.tags.isEmpty
                                  ? 'None'
                                  : widget.company.tags.join(', '),
                            ),
                            const SizedBox(height: 32),
                            if (canEdit && !_isEditing) ...[
                              Divider(color: Colors.white.withValues(alpha: 0.1), height: 48),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _deleteCompany,
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  label: const Text(
                                    'Delete Server',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool canEdit) {
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Banner Image
          GestureDetector(
            onTap: (canEdit && _isEditing) ? () => _pickImage(false) : null,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                image: _bannerUrlController.text.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_bannerUrlController.text),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_bannerUrlController.text.isEmpty)
                    Icon(
                      Icons.landscape,
                      size: 64,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  if (canEdit && _isEditing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Gradient Overlay
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Avatar
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: (canEdit && _isEditing) ? () => _pickImage(true) : null,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                      backgroundImage: _logoUrlController.text.isNotEmpty
                          ? NetworkImage(_logoUrlController.text)
                          : null,
                      child: _logoUrlController.text.isEmpty
                          ? Text(
                              widget.company.name.isNotEmpty
                                  ? widget.company.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    if (canEdit && _isEditing)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
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
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
