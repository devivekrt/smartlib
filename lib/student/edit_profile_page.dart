import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/models/student_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Add this package

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    Key? key,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();

  // Form values
  String _gender = 'Male'; // Default value
  DateTime _dateOfBirth = DateTime.now().subtract(Duration(days: 365 * 20)); // Default 20 years ago
  bool _locationPermissionGranted = false;
  double _latitude = 0.0;
  double _longitude = 0.0;

  // Profile image
  File? _imageFile;
  String _profileImageUrl = '';
  bool _isUploading = false;

  // Loading states
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkLocationPermission();
  }

  // Load user data from Firebase
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final studentId = SmartLib.userId;
      final studentRef = FirebaseDatabase.instance
          .ref()
          .child('${SmartLib.constPath}/students/$studentId');

      final snapshot = await studentRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _fullNameController.text = data['fullName'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _departmentController.text = data['department'] ?? '';
          _profileImageUrl = data['profileImageUrl'] ?? '';

          // Parse gender if available
          if (data.containsKey('gender')) {
            _gender = data['gender'];
          }

          // Parse date of birth if available
          if (data.containsKey('dateOfBirth')) {
            try {
              _dateOfBirth = DateTime.parse(data['dateOfBirth']);
            } catch (e) {
              print('Error parsing date of birth: $e');
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Dispose controllers
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  // Check location permission
  Future<void> _checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      setState(() {
        _locationPermissionGranted =
            permission == LocationPermission.always ||
                permission == LocationPermission.whileInUse;
      });

      if (_locationPermissionGranted) {
        // Get current location
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      print('Error checking location permission: $e');
    }
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();

      setState(() {
        _locationPermissionGranted =
            permission == LocationPermission.always ||
                permission == LocationPermission.whileInUse;
      });

      if (_locationPermissionGranted) {
        // Get current location
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission granted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied')),
        );
      }
    } catch (e) {
      print('Error requesting location permission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting permission: $e')),
      );
    }
  }

  // Pick image from gallery/camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        setState(() {
          _imageFile = File(pickedImage.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Compress image to target size
  Future<File?> _compressImage(File file) async {
    try {
      // Check file size first
      final fileSize = await file.length();
      final targetSize = 50 * 1024; // 50kb in bytes

      // If already under target size, return original file
      if (fileSize <= targetSize) {
        return file;
      }

      // Calculate quality (start with 85% quality)
      int quality = 85;

      // If file is very large, reduce quality more aggressively
      if (fileSize > 1000 * 1024) { // If over 1MB
        quality = 50;
      } else if (fileSize > 500 * 1024) { // If over 500KB
        quality = 65;
      }

      // Create a temp file path
      final tempDir = Directory.systemTemp;
      final targetPath = tempDir.path + '/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        return file;
      }

      // Check if it meets our target size
      final resultSize = await result.length();

      // If still too large, compress again with lower quality
      if (resultSize > targetSize) {
        final lowerQuality = (quality * targetSize / resultSize).round();
        final secondPath = tempDir.path + '/compressed2_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final secondResult = await FlutterImageCompress.compressAndGetFile(
          secondPath,
          secondPath,
          quality: lowerQuality,
          format: CompressFormat.jpeg,
        );

        return secondResult != null ? File(secondResult.path) : File(result.path);
      }

      return File(result.path);
    } catch (e) {
      print('Error compressing image: $e');
      // Return original file if compression fails
      return file;
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _profileImageUrl; // Return existing URL if no new image

    setState(() {
      _isUploading = true;
    });

    try {
      // Create a unique file name
      String fileName = 'profile_${SmartLib.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress image to target size
      File? compressedFile = await _compressImage(_imageFile!);

      // Get storage reference
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);

      // Upload file
      await storageRef.putFile(compressedFile!);

      // Get download URL
      String downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _isUploading = false;
        _profileImageUrl = downloadUrl;
      });

      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );

      return _profileImageUrl; // Return existing URL on error
    }
  }

  // Save profile changes
  Future<void> _saveProfile() async {
    // Validate form
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }

    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.trim().contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload image if selected
      String profileImageUrl = await _uploadImage() ?? _profileImageUrl;

      // Create data to update
      final studentId = SmartLib.userId;
      final data = {
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'profileImageUrl': profileImageUrl,
        'gender': _gender,
        'dateOfBirth': _dateOfBirth.toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };



      // Update the database
      await FirebaseDatabase.instance
          .ref()
          .child('${SmartLib.constPath}/students/$studentId')
          .update(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Return to previous screen
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Color(0xff1940CC),
        ),
      )
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            // Show image options
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Change Profile Picture',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    ListTile(
                                      leading: Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Color(0xff1940CC).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          color: Color(0xff1940CC),
                                        ),
                                      ),
                                      title: Text('Take a photo'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.camera);
                                      },
                                    ),
                                    ListTile(
                                      leading: Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Color(0xff1940CC).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.photo_library,
                                          color: Color(0xff1940CC),
                                        ),
                                      ),
                                      title: Text('Choose from gallery'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.gallery);
                                      },
                                    ),
                                    if (_profileImageUrl.isNotEmpty || _imageFile != null)
                                      ListTile(
                                        leading: Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                        ),
                                        title: Text('Remove photo'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          setState(() {
                                            _imageFile = null;
                                            _profileImageUrl = '';
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xff6C63FF), Color(0xff1940CC)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: _isUploading
                                    ? Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                                    : _imageFile != null
                                    ? ClipOval(
                                  child: Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                  ),
                                )
                                    : _profileImageUrl.isNotEmpty
                                    ? ClipOval(
                                  child: Image.network(
                                    _profileImageUrl,
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        _fullNameController.text.isNotEmpty
                                            ? _fullNameController.text[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                    : Center(
                                  child: Text(
                                    _fullNameController.text.isNotEmpty
                                        ? _fullNameController.text[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Color(0xff1940CC),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cardColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Change Profile Picture',
                          style: TextStyle(
                            color: Color(0xff1940CC),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Gap(30),

                  // Personal Information
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Gap(16),

                  // Form fields
                  // Full Name
                  _buildInputField(
                    label: 'Full Name',
                    controller: _fullNameController,
                    icon: Icons.person_outline,
                    isRequired: true,
                  ),
                  Gap(16),

                  // Username
                  _buildInputField(
                    label: 'Username',
                    controller: _usernameController,
                    icon: CupertinoIcons.at,
                    isRequired: true,
                  ),
                  Gap(16),

                  // Email
                  _buildInputField(
                    label: 'Email',
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    isRequired: true,
                  ),
                  Gap(16),

                  // Phone
                  _buildInputField(
                    label: 'Phone',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  Gap(16),

                  // Department
                  _buildInputField(
                    label: 'Department',
                    controller: _departmentController,
                    icon: CupertinoIcons.book,
                  ),
                  Gap(24),

                  // Date of Birth
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _dateOfBirth,
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );

                      if (picked != null && picked != _dateOfBirth) {
                        setState(() {
                          _dateOfBirth = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today),
                          SizedBox(width: 16),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_dateOfBirth),
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Gap(24),

                  // Gender
                  Text(
                    'Gender',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _gender,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _gender = newValue;
                            });
                          }
                        },
                        items: <String>['Male', 'Female', 'Other']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Gap(24),

                  // Location Permission
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _locationPermissionGranted
                            ? Colors.green.withOpacity(0.5)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: _locationPermissionGranted
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Location Permission',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Switch(
                              value: _locationPermissionGranted,
                              activeColor: Color(0xff1940CC),
                              onChanged: (value) async {
                                if (value && !_locationPermissionGranted) {
                                  await _requestLocationPermission();
                                } else if (!value && _locationPermissionGranted) {
                                  setState(() {
                                    _locationPermissionGranted = false;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Allow SmartLib to access your location for a better library experience.',
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                        if (_locationPermissionGranted && _latitude != 0) ...[
                          SizedBox(height: 10),
                          Text(
                            'Current Location: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Gap(40),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff1940CC),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build input field
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 4),
            if (isRequired)
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}