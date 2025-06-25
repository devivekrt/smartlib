import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartlib/library/library_details_upload.dart';
import 'dart:io';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/solid_button.dart';
import '../../function/student_function.dart';

class LibrarianProfileSetupPage extends StatefulWidget {
  final String email;
  final String phone;

  const LibrarianProfileSetupPage({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  State<LibrarianProfileSetupPage> createState() =>
      _LibrarianProfileSetupPageState();
}

class _LibrarianProfileSetupPageState extends State<LibrarianProfileSetupPage> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _panIdController = TextEditingController();
  final _gstinController = TextEditingController();

  String? _selectedGender = "";
  File? _profileImage;
  bool _isLoading = false;

  // Optional fields - added based on the data structure
  final _experienceController = TextEditingController();

  // Methods for profile setup
  Future<void> _pickImage() async {
    File? pickedImage = await AuthFunctions.pickImage(context);
    if (pickedImage != null) {
      setState(() {
        _profileImage = pickedImage;
      });
    }
  }

  void _finishProfileSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Here we call the updated function to save the librarian profile
      final librarianId = await AuthFunctions.finishLibrarianProfile(
        context,
        (isLoading) {
          setState(() {
            _isLoading = isLoading;
          });
        },
        widget.email,
        widget.phone,
        _fullNameController.text,
        _selectedGender ?? '',
        _profileImage,
        panId: _panIdController.text,
        gstNumber:
            _gstinController.text.isNotEmpty ? _gstinController.text : null,
        experience:
            _experienceController.text.isNotEmpty
                ? _experienceController.text
                : null,
      );

      // Navigate to library details page
      if (librarianId.isNotEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (context) => LibraryDetailsUpload(librarianId: librarianId),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving profile: ${e.toString()}")),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: DarkColor.secondary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: DarkColor.secondary,
        elevation: 0,

        centerTitle: true,
        title: const Text(
          'Librarian Profile',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    Gap(20),
                    Text(
                      "Setting up your profile...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  children: [
                    // Profile Information Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: DarkColor.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Profile Image Selector
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: DarkColor.highlightColor,
                                  backgroundImage:
                                      _profileImage != null
                                          ? FileImage(_profileImage!)
                                          : null,
                                  child:
                                      _profileImage == null
                                          ? const Icon(
                                            Icons.person,
                                            size: 90,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: DarkColor.secondary,
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Basic Information
                            InputField(
                              controller: _fullNameController,
                              labelText: 'Full Name',
                              hintText: 'Enter your full name',
                              prefixIcon: Icons.person,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),

                            // Gender Selection
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Select Gender",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _genderButton("Female", Icons.female),
                                const SizedBox(width: 12),
                                _genderButton("Male", Icons.male),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ID Information
                            InputField(
                              controller: _panIdController,
                              labelText: 'PAN Card',
                              hintText: 'Enter your PAN card number',
                              prefixIcon: Icons.badge,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your PAN card number';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),

                            InputField(
                              controller: _gstinController,
                              labelText: 'GST No (Optional)',
                              hintText: 'Enter your GST Number',
                              prefixIcon: Icons.numbers,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Gap(20),

                    // Additional Information Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: DarkColor.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Additional Information",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Gap(20),

                          // Experience field - Optional
                          InputField(
                            controller: _experienceController,
                            labelText: 'Experience (Optional)',
                            hintText: 'Years of experience',
                            prefixIcon: Icons.work,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),

                    Gap(20),

                    // Library Information Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: DarkColor.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Library Information",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 15),
                          Text(
                            "You'll be able to add details about your library collection, operating hours, and location in the next step.",
                            style: TextStyle(color: Colors.white70),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "This information will help students find your library and its resources.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      bottomNavigationBar:
          _isLoading
              ? null
              : AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.only(
                  bottom:
                      keyboardVisible
                          ? MediaQuery.of(context).viewInsets.bottom + 10
                          : 20,
                  left: 20,
                  right: 20,
                ),
                child: SolidButton(
                  text: "Complete Profile",
                  onPressed: _finishProfileSetup,
                  height: 50,
                  width: double.infinity,
                ),
              ),
    );
  }

  Widget _genderButton(String label, IconData icon) {
    final isSelected = _selectedGender == label;
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _selectedGender = label),
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected
                  ? DarkColor.highlightColor
                  : DarkColor.borderColor.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _panIdController.dispose();
    _gstinController.dispose();
    _experienceController.dispose();
    super.dispose();
  }
}
