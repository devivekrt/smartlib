import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/solid_button.dart';
import '../data/string.dart';
import '../models/library_model.dart';

class LibraryEditScreen extends StatefulWidget {
  final String librarianId;
  final String libraryId;

  const LibraryEditScreen({
    super.key,
    required this.librarianId,
    required this.libraryId,
  });

  @override
  State<LibraryEditScreen> createState() => _LibraryEditScreenState();
}

class _LibraryEditScreenState extends State<LibraryEditScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  LibraryModel? _library;
  File? _selectedImageFile;
  bool _isUploadingImage = false;
  // Image picker and processing
  final ImagePicker _imagePicker = ImagePicker();
  int? _selectedImageSize; // To track image size in bytes

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _libraryNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _seatsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _landMarkController = TextEditingController();

  // Opening hours controllers
  final _weekdaysOpenController = TextEditingController();
  final _weekdaysCloseController = TextEditingController();
  final _weekendOpenController = TextEditingController();
  final _weekendCloseController = TextEditingController();

  // For shifts
  // Predefined shift keys and shift names
  final List<String> _shiftKeys = ['morning'];
  final List<Map<String, String>> _availableShifts = [
    {'id': 'morning', 'name': 'Morning'},
    {'id': 'afternoon', 'name': 'Afternoon'},
    {'id': 'evening', 'name': 'Evening'},
    {'id': 'night', 'name': 'Night'},
    {'id': 'full_day', 'name': 'Full Day'},
  ];

  // For managing shifts
  List<String> _selectedShiftNames = ['Morning'];
  List<TextEditingController> _shiftStartTimeControllers = [TextEditingController()];
  List<TextEditingController> _shiftEndTimeControllers = [TextEditingController()];
  List<TextEditingController> _shiftFeeControllers = [TextEditingController()];

  late List<ShiftModel> _shifts;
  late List<TextEditingController> _rulesControllers;

  // Predefined utilities list
  final List<LibraryUtility> _utilities = [
    LibraryUtility(id: 'wifi', name: 'WiFi', icon: Icons.wifi),
    LibraryUtility(id: 'cctv', name: 'CCTV', icon: Icons.videocam),
    LibraryUtility(id: 'water', name: 'RO Water', icon: Icons.water_drop),
    LibraryUtility(id: 'ac', name: 'Air Conditioning', icon: Icons.ac_unit),
    LibraryUtility(id: 'printer', name: 'Printer', icon: Icons.print),
    LibraryUtility(id: 'scanner', name: 'Scanner', icon: Icons.scanner),
    LibraryUtility(id: 'locker', name: 'Lockers', icon: Icons.lock),
    LibraryUtility(id: 'cafe', name: 'Cafeteria', icon: Icons.local_cafe),
    LibraryUtility(id: 'parking', name: 'Parking', icon: Icons.local_parking),
    LibraryUtility(id: 'charging', name: 'Charging Points', icon: Icons.power),
  ];

  // Custom utilities
  late List<LibraryUtility> _customUtilities;
  final _customUtilityController = TextEditingController();

  late DateTime _selectedDate;

  // Current tab for editing
  int _currentTab = 0;
  final _tabTitles = [
    'Basic Info',
    'Contact & Address',
    'Utilities & Features',
    'Shifts & Rules'
  ];

  @override
  void initState() {
    super.initState();
    _shifts = [];
    _rulesControllers = [];
    _customUtilities = [];
    _selectedDate = DateTime.now().subtract(const Duration(days: 365 * 20));
    _fetchLibraryData();
  }

  Future<void> _fetchLibraryData() async {
    try {
      // METHOD 1: Verify this library belongs to the librarian
      final managedLibrariesRef = FirebaseDatabase.instance
          .ref('${SmartLib.constPath}/librarians/${widget.librarianId}/managedLibraries')
          .child(widget.libraryId);

      final snapshot = await managedLibrariesRef.get();

      if (!snapshot.exists || snapshot.value != true) {
        _showError("You don't have permission to edit this library");
        Navigator.pop(context);
        return;
      }

      // Permission verified, get library data
      final libraryDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .get();

      if (!libraryDoc.exists) {
        _showError("Library not found");
        Navigator.pop(context);
        return;
      }

      // Create library model from document
      _library = LibraryModel.fromMap(libraryDoc.data()!, libraryDoc.id);

      // Populate form controllers and state
      _populateFormFields();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading library: $e');
      _showError("Error loading library data: $e");
      Navigator.pop(context);
    }
  }

  void _populateFormFields() {
    // Basic info
    _libraryNameController.text = _library!.libraryName ?? '';
    _ownerNameController.text = _library!.ownerName ?? '';
    _seatsController.text = _library!.totalSeats?.toString() ?? '';
    _descriptionController.text = _library!.description ?? '';

    // Parse established date
    if (_library!.establishedDate != null) {
      final dateParts = _library!.establishedDate!.split('/');
      if (dateParts.length == 3) {
        try {
          final day = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final year = int.parse(dateParts[2]);
          _selectedDate = DateTime(year, month, day);
        } catch (e) {
          print('Error parsing date: $e');
        }
      }
    }

    // Contact & address
    if (_library!.contactInfo != null) {
      _phoneController.text = _library!.contactInfo!['phone'] ?? '';
      _emailController.text = _library!.contactInfo!['email'] ?? '';
    }

    if (_library!.address != null) {
      _streetController.text = _library!.address!['street'] ?? '';
      _cityController.text = _library!.address!['city'] ?? '';
      _stateController.text = _library!.address!['state'] ?? '';
      _zipController.text = _library!.address!['zipCode'] ?? '';
      _landMarkController.text = _library!.address!['landMark'] ?? '';
    }

    // Opening hours
    if (_library!.openingHours != null) {
      final weekdayHours = _library!.openingHours!['mon-fri'];
      final weekendHours = _library!.openingHours!['sat-sun'];

      if (weekdayHours != null) {
        _weekdaysOpenController.text = weekdayHours['openTime'] ?? '09:00';
        _weekdaysCloseController.text = weekdayHours['closeTime'] ?? '18:00';
      } else {
        _weekdaysOpenController.text = '09:00';
        _weekdaysCloseController.text = '18:00';
      }

      if (weekendHours != null) {
        _weekendOpenController.text = weekendHours['openTime'] ?? '10:00';
        _weekendCloseController.text = weekendHours['closeTime'] ?? '16:00';
      } else {
        _weekendOpenController.text = '10:00';
        _weekendCloseController.text = '16:00';
      }
    } else {
      _weekdaysOpenController.text = '09:00';
      _weekdaysCloseController.text = '18:00';
      _weekendOpenController.text = '10:00';
      _weekendCloseController.text = '16:00';
    }

    // Rules
    _rulesControllers.clear();
    if (_library!.rules.isNotEmpty) {
      for (String rule in _library!.rules) {
        _rulesControllers.add(TextEditingController(text: rule));
      }
    }
    if (_rulesControllers.isEmpty) {
      _rulesControllers.add(TextEditingController());
    }

    // Clear existing shifts
    _shifts.clear();
    _shiftKeys.clear();
    _selectedShiftNames.clear();
    _shiftStartTimeControllers.clear();
    _shiftEndTimeControllers.clear();
    _shiftFeeControllers.clear();

    // Check if library.shifts is a Map
    Map<String, dynamic> shiftsMap = _library!.shifts;

    // Convert each shift from the map to a ShiftModel and setup shift controllers
    shiftsMap.forEach((key, value) {
      if (value is Map) {
        Map<String, dynamic> shiftData = Map<String, dynamic>.from(value);

        // Add to shifts for compatibility with existing code
        _shifts.add(ShiftModel(
          shiftName: shiftData['shiftName'],
          startTime: shiftData['shiftStartTime'],
          endTime: shiftData['shiftEndTime'],
          fee: shiftData['shiftFee'] is int ? shiftData['shiftFee'] : int.tryParse(shiftData['shiftFee'].toString()),
        ));

        // Add to the new UI controls
        _shiftKeys.add(key);
        _selectedShiftNames.add(shiftData['shiftName'] ?? 'Unknown Shift');

        final startController = TextEditingController(text: shiftData['shiftStartTime'] ?? '');
        _shiftStartTimeControllers.add(startController);

        final endController = TextEditingController(text: shiftData['shiftEndTime'] ?? '');
        _shiftEndTimeControllers.add(endController);

        final feeValue = shiftData['shiftFee'] is int
            ? shiftData['shiftFee'].toString()
            : int.tryParse(shiftData['shiftFee'].toString())?.toString() ?? '';
        final feeController = TextEditingController(text: feeValue);
        _shiftFeeControllers.add(feeController);
      }
    });

    // Ensure there's at least one shift
    if (_shiftKeys.isEmpty) {
      _shiftKeys.add('morning');
      _selectedShiftNames.add('Morning');
      _shiftStartTimeControllers.add(TextEditingController(text: '09:00'));
      _shiftEndTimeControllers.add(TextEditingController(text: '13:00'));
      _shiftFeeControllers.add(TextEditingController(text: '50'));
      _shifts.add(ShiftModel(
        shiftName: 'Morning',
        startTime: '09:00',
        endTime: '13:00',
        fee: 50,
      ));
    }

    // Utilities
    if (_library!.utilities.isNotEmpty) {
      // First reset all to not selected
      for (var utility in _utilities) {
        utility.isSelected = false;
      }

      // Mark selected utilities
      for (String utilityId in _library!.utilities) {
        // Check predefined utilities
        bool foundInPredefined = false;
        for (var utility in _utilities) {
          if (utility.id == utilityId) {
            utility.isSelected = true;
            foundInPredefined = true;
            break;
          }
        }

        // If not found in predefined, might be a custom utility
        if (!foundInPredefined) {
          _customUtilities.add(LibraryUtility(
            id: utilityId,
            name: _capitalizeUtilityName(utilityId),
            icon: Icons.star,
            isSelected: true,
          ));
        }
      }
    }
  }

  String _capitalizeUtilityName(String id) {
    // Convert 'custom_utility' to 'Custom Utility'
    return id.split('_').map((word) =>
    word.isNotEmpty ?
    word[0].toUpperCase() + word.substring(1) : ''
    ).join(' ');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Image selection and processing functions
  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: DarkColor.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Update Library Image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white70),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white70),
                title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_library!.libraryImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Current Image', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmRemoveImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800, // Reduce initial dimensions for better processing
        maxHeight: 450, // 16:9 aspect ratio
        imageQuality: 80,
      );

      if (pickedFile != null) {
        // Crop the image for better user control
        final File imageFile = File(pickedFile.path);


        if (imageFile != null) {
          //if imageFile is less than 100KB, then no need to compress
          final fileSize = await imageFile.length();
          if (fileSize <= 100 * 1024) {
            setState(() {
              _selectedImageFile = imageFile;
              _selectedImageSize = fileSize;
            });

            // Show size confirmation
            final sizeInKB = (fileSize / 1024).toStringAsFixed(2);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image size: $sizeInKB KB'),
                duration: Duration(seconds: 2),
              ),
            );

            // Confirm before uploading
            _confirmImageUpload(imageFile);
          }
          // Compress the image to ensure it's under 100KB
          final compressedFile = await _compressImage(imageFile);

          if (compressedFile != null) {
            setState(() {
              _selectedImageFile = compressedFile;
              _selectedImageSize = compressedFile.lengthSync();
            });

            // Show size confirmation
            final sizeInKB = (_selectedImageSize! / 1024).toStringAsFixed(2);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image size: $sizeInKB KB'),
                duration: Duration(seconds: 2),
              ),
            );

            // Confirm before uploading
            _confirmImageUpload(compressedFile);
          }
        }
      }
    } catch (e) {
      _showError('Error processing image: $e');
    }
  }


  Future<File?> _compressImage(File file) async {
    try {
      // Create a temp file for compressed output
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Initial compression quality
      int quality = 85;
      File? result;

      // Try progressive compression until file size is under 100KB or quality gets too low
      while (quality >= 20) {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          quality: quality,
          minWidth: 800,
          minHeight: 450,
        );

        if (compressedBytes != null) {
          // Write compressed bytes to file
          result = File(targetPath);
          await result.writeAsBytes(compressedBytes);

          final fileSize = await result.length();

          // If under 100KB, we're good
          if (fileSize <= 100 * 1024) {
            print('Compressed image to $quality% quality, size: ${fileSize / 1024} KB');
            return result;
          }

          // If still too large, reduce quality and try again
          quality -= 15;
        } else {
          break; // Compression failed
        }
      }

      // If we couldn't get it under 100KB, use the smallest version we got
      if (result != null && await result.exists()) {
        final fileSize = await result.length();
        if (fileSize > 100 * 1024) {
          _showError('Could not compress image below 100KB. Current size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
        }
        return result;
      }

      _showError('Failed to compress image');
      return null;
    } catch (e) {
      _showError('Error compressing image: $e');
      return null;
    }
  }

  Future<void> _confirmImageUpload(File imageFile) async {
    final fileSize = await imageFile.length();
    final sizeInKB = (fileSize / 1024).toStringAsFixed(2);

    if (fileSize > 100 * 1024) {
      final bool proceed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DarkColor.cardColor,
          title: const Text('Image Size Warning', style: TextStyle(color: Colors.white)),
          content: Text(
            'The image is $sizeInKB KB, which exceeds the 100KB limit. '
                'It may be rejected by the server.\n\nWould you like to try again with a smaller image?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Upload Anyway', style: TextStyle(color: DarkColor.highlightColor)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Try Again', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );

      if (proceed == true) {
        return; // User chose to try again
      }
    }

    // Proceed with upload
    await _uploadLibraryImage();
  }

  Future<void> _uploadLibraryImage() async {
    if (_selectedImageFile == null) return;

    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Reference to Firebase Storage
      final storage = FirebaseStorage.instance;

      // Create a reference to the new image file
      final fileName = 'library_images/${widget.libraryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = storage.ref().child(fileName);

      // Upload the file with metadata to specify content type
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
      );
      await storageRef.putFile(_selectedImageFile!, metadata);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Delete old image if exists
      if (_library!.libraryImageUrl != null) {
        try {
          // Extract the path from the URL
          final oldImageRef = storage.refFromURL(_library!.libraryImageUrl!);
          await oldImageRef.delete();
        } catch (e) {
          print('Error deleting old image: $e');
          // Continue even if old image deletion fails
        }
      }

      // Update Firestore with new image URL
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .update({
        'libraryImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the local model
      _library!.libraryImageUrl = downloadUrl;

      setState(() {
        _isUploadingImage = false;
      });

      _showError('Library image updated successfully');
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      _showError('Error uploading image: $e');
    }
  }

  Future<void> _confirmRemoveImage() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DarkColor.cardColor,
        title: const Text('Remove Image?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove the current library image?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm) {
      await _removeLibraryImage();
    }
  }

  Future<void> _removeLibraryImage() async {
    if (_library!.libraryImageUrl == null) return;

    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Reference to Firebase Storage
      final storage = FirebaseStorage.instance;

      // Delete image from storage
      try {
        final imageRef = storage.refFromURL(_library!.libraryImageUrl!);
        await imageRef.delete();
      } catch (e) {
        print('Error deleting image from storage: $e');
        // Continue even if storage deletion fails
      }

      // Remove image URL from Firestore
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .update({
        'libraryImageUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local model
      _library!.libraryImageUrl = null;
      _selectedImageFile = null;
      _selectedImageSize = null;

      setState(() {
        _isUploadingImage = false;
      });

      _showError('Library image removed successfully');
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      _showError('Error removing image: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2196F3),
              onPrimary: Colors.white,
              surface: Color(0xFF1E3A5F),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogTheme(backgroundColor: Color(0xFF142E4F)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Time picker for opening hours
  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    // Parse the current time from controller
    String currentTime = controller.text;
    int hour = 9;  // Default hour
    int minute = 0; // Default minute

    if (currentTime.isNotEmpty) {
      try {
        final parts = currentTime.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      } catch (e) {
        print('Error parsing time: $e');
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2196F3),
              onPrimary: Colors.white,
              surface: Color(0xFF1E3A5F),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogTheme(backgroundColor: Color(0xFF142E4F)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Format the time as 'HH:MM'
      final String hour = picked.hour.toString().padLeft(2, '0');
      final String minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
    }
  }

  // Choose a shift from available shifts
  void _selectShiftFromChips(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Shift Type',
          style: TextStyle(color: Colors.white),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a shift type from options or enter a custom name',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: _availableShifts.map((shift) {
                  final isSelected = _selectedShiftNames[index] == shift['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedShiftNames[index] = shift['name']!;
                        _shiftKeys[index] = shift['id']!;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DarkColor.highlightColor
                            : DarkColor.cardColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected
                              ? DarkColor.highlightColor
                              : Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        shift['name']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
        backgroundColor: DarkColor.cardColor,
      ),
    );
  }

  void _addShift() {
    setState(() {
      _shiftKeys.add('shift_${_shiftKeys.length + 1}');
      _selectedShiftNames.add('Shift ${_selectedShiftNames.length + 1}');
      _shiftStartTimeControllers.add(TextEditingController());
      _shiftEndTimeControllers.add(TextEditingController());
      _shiftFeeControllers.add(TextEditingController());

      // Also add to the old shifts array for compatibility
      _shifts.add(ShiftModel());
    });
  }

  void _removeShift(int index) {
    setState(() {
      if (_shiftKeys.length > 1) {
        _shiftKeys.removeAt(index);
        _selectedShiftNames.removeAt(index);
        _shiftStartTimeControllers.removeAt(index);
        _shiftEndTimeControllers.removeAt(index);
        _shiftFeeControllers.removeAt(index);

        // Also remove from old shifts array for compatibility
        if (_shifts.length > index) {
          _shifts.removeAt(index);
        }
      }
    });
  }

  void _toggleUtility(LibraryUtility utility) {
    setState(() {
      utility.isSelected = !utility.isSelected;
    });
  }

  int? _calculateLowestFee() {
    int? lowest;

    for (var controller in _shiftFeeControllers) {
      if (controller.text.isNotEmpty) {
        int? fee = int.tryParse(controller.text);
        if (fee != null) {
          if (lowest == null || fee < lowest) {
            lowest = fee;
          }
        }
      }
    }

    return lowest;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get selected utilities
      List<String> selectedUtilities = [];
      for (var utility in _utilities) {
        if (utility.isSelected) {
          selectedUtilities.add(utility.id);
        }
      }

      // Add custom utilities
      for (var utility in _customUtilities) {
        if (utility.isSelected) {
          selectedUtilities.add(utility.id);
        }
      }

      // Create contact info map
      final contactInfo = {
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      };

      // Create address map
      final address = {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zipCode': _zipController.text.trim(),
        'landMark': _landMarkController.text.trim(),
      };

      // Create opening hours map
      final openingHours = {
        'mon-fri': {
          'openTime': _weekdaysOpenController.text.trim(),
          'closeTime': _weekdaysCloseController.text.trim(),
        },
        'sat-sun': {
          'openTime': _weekendOpenController.text.trim(),
          'closeTime': _weekendCloseController.text.trim(),
        },
      };

      // Get rules from controllers (filtering out empty ones)
      final rules = _rulesControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Create shifts map from the new UI controllers
      Map<String, Map<String, dynamic>> shiftsMap = {};

      for (int i = 0; i < _shiftKeys.length; i++) {
        final key = _shiftKeys[i];
        final shiftName = _selectedShiftNames[i];
        final startTime = _shiftStartTimeControllers[i].text.isEmpty ?
        '09:00' : _shiftStartTimeControllers[i].text;
        final endTime = _shiftEndTimeControllers[i].text.isEmpty ?
        '13:00' : _shiftEndTimeControllers[i].text;
        final fee = int.tryParse(_shiftFeeControllers[i].text) ?? 0;

        shiftsMap[key] = {
          'shiftName': shiftName,
          'shiftStartTime': startTime,
          'shiftEndTime': endTime,
          'shiftFee': fee,
        };
      }

      // Calculate lowest fee
      final lowFee = _calculateLowestFee();

      // Format the established date as day/month/year
      final formattedDate = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';

      // Parse the new seat count and handle validation
      int? newSeatCount = int.tryParse(_seatsController.text.trim());
      int oldSeatCount = _library!.totalSeats ?? 0;

      if (newSeatCount == null || newSeatCount <= 0) {
        _showError("Please enter a valid number of seats");
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Check if reducing seats would cause conflicts with current bookings
      if (newSeatCount < oldSeatCount) {
        // Show confirmation dialog before reducing seats
        bool confirmReduce = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: DarkColor.cardColor,
            title: Text('Reduce Seats?', style: TextStyle(color: Colors.white)),
            content: Text(
              'Reducing seats from $oldSeatCount to $newSeatCount may affect existing bookings. '
                  'Are you sure you want to continue?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Continue', style: TextStyle(color: DarkColor.highlightColor)),
              ),
            ],
          ),
        );

        if (!confirmReduce) {
          setState(() {
            _isSubmitting = false;
            _seatsController.text = oldSeatCount.toString();
          });
          return;
        }
      }

      // Update the library in Firestore
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .update({
        'libraryName': _libraryNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'establishedDate': formattedDate,
        'totalSeats': newSeatCount,
        'description': _descriptionController.text.trim(),
        'contactInfo': contactInfo,
        'address': address,
        'rules': rules,
        'shifts': shiftsMap, // Using the new shifts map structure
        'utilities': selectedUtilities,
        'lowFee': lowFee,
        'openingHours': openingHours, // Add opening hours here
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update realtime DB seat info if total seats changed
      if (newSeatCount != oldSeatCount) {
        // Update the total seats count in realtime database
        await FirebaseDatabase.instance
            .ref('${SmartLib.constPath}/libraries/${widget.libraryId}/seats')
            .update({
          'total': newSeatCount,
          // Handle available seats count based on whether seats were added or removed
          'available': _library!.availableSeats != null ?
          (_library!.availableSeats! + (newSeatCount - oldSeatCount)) :
          newSeatCount,
          'lastUpdated': ServerValue.timestamp,
        });

        // If seats increased, we need to create new seat entries
        if (newSeatCount > oldSeatCount) {
          // Generate and add the additional seats
          final additionalSeats = newSeatCount - oldSeatCount;
          await _generateAdditionalSeats(widget.libraryId, additionalSeats, shiftsMap);
        } else if (newSeatCount < oldSeatCount) {
          // If seats decreased, we need to remove the excess seats
          await _removeExcessSeats(widget.libraryId, oldSeatCount, newSeatCount);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Library updated successfully")),
      );

      Navigator.pop(context, true); // Return true to indicate successful update
    } catch (e) {
      print("Error updating library: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating library: ${e.toString()}")),
      );

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Helper method to generate additional seats when total seats are increased
  Future<void> _generateAdditionalSeats(String libraryId, int additionalSeats, Map<String, Map<String, dynamic>> shiftsMap) async {
    try {
      // First get the current seats document
      final libraryDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .get();

      if (!libraryDoc.exists) return;

      // Get existing seats data
      Map<String, dynamic>? existingSeatsData = libraryDoc.data()?['seats'];
      Map<String, dynamic> seatsData = existingSeatsData != null
          ? Map<String, dynamic>.from(existingSeatsData)
          : {};

      // Calculate how many seats we already have
      int existingSeatsCount = seatsData.length;

      // Determine how many rows we need
      int seatCounter = 0;
      int totalRows = (existingSeatsCount / 10).ceil(); // Assume 10 seats per row
      int rowIndex = totalRows > 0 ? totalRows - 1 : 0;
      int colIndex = existingSeatsCount % 10;  // Current column in the last row

      final int maxSeatsPerRow = 10; // Adjust as needed

      while (seatCounter < additionalSeats) {
        if (colIndex >= maxSeatsPerRow) {
          // Move to next row
          rowIndex++;
          colIndex = 0;
        }

        String rowName;
        if (rowIndex >= 26) { // A-Z (26 letters)
          // If we run out of letters, use double letters (AA, AB, etc.)
          rowName = String.fromCharCode(65 + (rowIndex ~/ 26) - 1) +
              String.fromCharCode(65 + (rowIndex % 26));
        } else {
          // Use single letter (A-Z)
          rowName = String.fromCharCode(65 + rowIndex);
        }

        // Create seat ID
        colIndex++;
        String seatId = "$rowName$colIndex";

        // Create initial seat data with all shifts available
        Map<String, dynamic> shiftsStatus = {};
        shiftsMap.forEach((shiftKey, shiftData) {
          shiftsStatus[shiftKey] = {'status': 'available'};
        });

        seatsData[seatId] = {
          'shifts': shiftsStatus
        };

        seatCounter++;
      }

      // Update Firestore with the new seats
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .update({'seats': seatsData});

      print("Successfully added $additionalSeats new seats to library $libraryId");
    } catch (e) {
      print("Error generating additional seats: $e");
      // Don't rethrow to avoid interrupting the main update process
    }
  }

  // Helper method to remove excess seats when total seats are decreased
  Future<void> _removeExcessSeats(String libraryId, int oldSeatCount, int newSeatCount) async {
    try {
      // First get the current seats document
      final libraryDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .get();

      if (!libraryDoc.exists) return;

      // Get existing seats data
      Map<String, dynamic>? existingSeatsData = libraryDoc.data()?['seats'];
      if (existingSeatsData == null) return;

      Map<String, dynamic> seatsData = Map<String, dynamic>.from(existingSeatsData);

      // Sort seats by ID to remove the highest numbered ones first
      List<String> sortedSeatIds = seatsData.keys.toList()
        ..sort((a, b) => b.compareTo(a)); // Sort in descending order

      // Calculate how many to remove
      int seatsToRemove = oldSeatCount - newSeatCount;

      // Remove the seats, but first check if they're booked
      int removed = 0;
      List<String> bookedSeats = [];

      for (String seatId in sortedSeatIds) {
        if (removed >= seatsToRemove) break;

        // Check if any shift is booked for this seat
        bool isBooked = false;
        Map<String, dynamic> seatData = Map<String, dynamic>.from(seatsData[seatId]);
        if (seatData.containsKey('shifts')) {
          Map<String, dynamic> shiftsData = Map<String, dynamic>.from(seatData['shifts']);

          for (var shift in shiftsData.values) {
            if (shift is Map && shift['status'] != 'available') {
              isBooked = true;
              bookedSeats.add(seatId);
              break;
            }
          }
        }

        // Remove if not booked
        if (!isBooked) {
          seatsData.remove(seatId);
          removed++;
        }
      }

      // Update Firestore with the modified seats
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .update({'seats': seatsData});

      // If we couldn't remove all seats due to bookings, show a warning
      if (removed < seatsToRemove) {
        _showError("Could not remove all seats as some are currently booked. Library now has ${seatsData.length} seats.");
      } else {
        print("Successfully removed $removed excess seats from library $libraryId");
      }
    } catch (e) {
      print("Error removing excess seats: $e");
      // Don't rethrow to avoid interrupting the main update process
    }
  }

  void _changeTab(int index) {
    setState(() {
      _currentTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Library', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Library image display with upload functionality
          Stack(
            children: [
              if (_selectedImageFile != null)
                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(_selectedImageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (_library!.libraryImageUrl != null)
                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(_library!.libraryImageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 160,
                  color: DarkColor.cardColor,
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 64,
                      color: Colors.grey[700],
                    ),
                  ),
                ),

              // Image size display if available
              if (_selectedImageFile != null && _selectedImageSize != null)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(_selectedImageSize! / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                        color: _selectedImageSize! > 100 * 1024 ? Colors.red : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Upload indicator or edit button
              Positioned(
                bottom: 8,
                right: 8,
                child: _isUploadingImage
                    ? Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(DarkColor.highlightColor),
                      strokeWidth: 2,
                    ),
                  ),
                )
                    : FloatingActionButton.small(
                  onPressed: _showImagePickerOptions,
                  backgroundColor: DarkColor.highlightColor,
                  child: Icon(Icons.edit, size: 16),
                ),
              ),
            ],
          ),

          // Tab selector
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabTitles.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _changeTab(index),
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _currentTab == index
                          ? DarkColor.highlightColor
                          : DarkColor.cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _tabTitles[index],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: _currentTab == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Tab content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: _buildTabContent(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isLoading
          ? null
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SolidButton(
          text: _isSubmitting ? "Saving..." : "Save Changes",
          onPressed: _saveChanges,
          width: double.infinity,
          height: 48,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildBasicInfoTab();
      case 1:
        return _buildContactAddressTab();
      case 2:
        return _buildUtilitiesTab();
      case 3:
        return _buildShiftsRulesTab();
      default:
        return Container();
    }
  }

  Widget _buildBasicInfoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          "Basic Information",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputField(
                controller: _libraryNameController,
                labelText: 'Library Name',
                prefixIcon: Icons.local_library,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter library name';
                  }
                  return null;
                },
              ),
              const Gap(12),

              InputField(
                controller: _ownerNameController,
                labelText: 'Library Owner Full Name',
                prefixIcon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter owner name';
                  }
                  return null;
                },
              ),

              const Gap(12),

              // Established Date
              const Text(
                "Established Date",
                style: TextStyle(color: Colors.white70),
              ),
              const Gap(8),

              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      Icon(Icons.calendar_today, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const Gap(12),

              InputField(
                controller: _seatsController,
                labelText: 'Total Available Seats',
                prefixIcon: Icons.event_seat,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of seats';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          "Description",
          InputField(
            controller: _descriptionController,
            labelText: 'Library Description',
            prefixIcon: Icons.description,
            hintText: 'Max 120 words',
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter library description';
              }
              if (value.split(' ').length > 120) {
                return 'Description cannot exceed 120 words';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactAddressTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          "Contact Information",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputField(
                controller: _phoneController,
                labelText: 'Phone Number',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const Gap(12),

              InputField(
                controller: _emailController,
                labelText: 'Email (Optional)',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Add opening hours section
        _buildSectionCard(
          "Opening Hours",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Set your library's opening hours",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Gap(12),

              // Weekdays row
              _buildOpeningHoursRow(
                "Weekdays (Mon-Fri)",
                _weekdaysOpenController,
                _weekdaysCloseController,
              ),
              const Gap(12),

              // Weekend row
              _buildOpeningHoursRow(
                "Weekend (Sat-Sun)",
                _weekendOpenController,
                _weekendCloseController,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          "Library Address",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputField(
                controller: _streetController,
                labelText: 'Street Address',
                prefixIcon: Icons.home,
              ),
              const Gap(12),

              InputField(
                controller: _cityController,
                labelText: 'City',
                prefixIcon: Icons.location_city,
              ),
              const Gap(12),

              Row(
                children: [
                  Expanded(
                    child: InputField(
                      controller: _stateController,
                      labelText: 'State',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputField(
                      controller: _zipController,
                      labelText: 'ZIP Code',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const Gap(12),

              InputField(
                controller: _landMarkController,
                labelText: 'Location Description',
                prefixIcon: Icons.location_on,
                hintText: 'Near landmark, etc.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build opening hours row
  Widget _buildOpeningHoursRow(
      String title,
      TextEditingController openController,
      TextEditingController closeController,
      ) {
    return Row(
      children: [
        // Day label
        Expanded(
          flex: 3,
          child: Text(
            title,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),

        // Time range with time pickers
        Expanded(
          flex: 7,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context, openController),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: DarkColor.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          openController.text,
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text("to", style: TextStyle(color: Colors.grey[400])),
              ),

              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context, closeController),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: DarkColor.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          closeController.text,
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUtilitiesTab() {
    return _buildSectionCard(
      "Library Amenities",
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Select the amenities available at your library:",
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 16),

          // Utilities grid
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _utilities.length,
            itemBuilder: (context, index) {
              return _buildUtilityTile(_utilities[index]);
            },
          ),

          // Custom utilities section
          if (_customUtilities.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              "Custom Amenities:",
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_customUtilities.length, (index) {
                return GestureDetector(
                  onTap: () => _toggleUtility(_customUtilities[index]),
                  child: _buildCustomUtilityChip(_customUtilities[index], index),
                );
              }),
            ),
          ],

        ],
      ),
    );
  }

  Widget _buildShiftsRulesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          "Operating Shifts",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._selectedShiftNames.asMap().entries.map((entry) {
                final index = entry.key;
                final shiftName = entry.value;
                final startTimeController = _shiftStartTimeControllers[index];
                final endTimeController = _shiftEndTimeControllers[index];
                final feeController = _shiftFeeControllers[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Shift ${index + 1}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_selectedShiftNames.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeShift(index),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      const Gap(8),

                      // Shift name selection
                      InkWell(
                        onTap: () => _selectShiftFromChips(index),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: DarkColor.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade600),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                shiftName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(8),

                      Row(
                        children: [
                          // Start time field with time picker
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectTime(context, startTimeController),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: startTimeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Time',
                                    hintText: '08:00',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: Icon(Icons.access_time),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Gap(8),
                          // End time field with time picker
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectTime(context, endTimeController),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: endTimeController,
                                  decoration: const InputDecoration(
                                    labelText: 'End Time',
                                    hintText: '12:00',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: Icon(Icons.access_time),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      // Fee field
                      TextField(
                        controller: feeController,
                        decoration: const InputDecoration(
                          labelText: 'Fee (₹)',
                          hintText: '50',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                );
              }).toList(),

              // Add shift button
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: _addShift,
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    "Add Shift",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarkColor.highlightColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          "Library Rules & Information",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._rulesControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                final hasText = controller.text.trim().isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: hasText ? Colors.green : Colors.grey,
                      ),
                      const Gap(8),
                      Expanded(
                        child: InputField(
                          controller: controller,
                          labelText: '',
                          hintText: 'Enter rule/information',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                if (_rulesControllers.length > 1) {
                                  _rulesControllers.removeAt(index);
                                } else {
                                  controller.clear();
                                }
                              });
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _rulesControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    "Add Rule",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarkColor.highlightColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUtilityTile(LibraryUtility utility) {
    return GestureDetector(
      onTap: () => _toggleUtility(utility),
      child: Container(
        decoration: BoxDecoration(
          color: utility.isSelected
              ? DarkColor.highlightColor.withOpacity(0.2)
              : DarkColor.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: utility.isSelected
                ? DarkColor.highlightColor
                : Colors.grey[700]!,
            width: utility.isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              utility.icon,
              size: 28,
              color: utility.isSelected
                  ? DarkColor.highlightColor
                  : Colors.white70,
            ),
            Gap(8),
            Text(
              utility.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: utility.isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: utility.isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 5),
            if (utility.isSelected)
              Icon(
                Icons.check_circle,
                size: 16,
                color: DarkColor.highlightColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomUtilityChip(LibraryUtility utility, int index) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: utility.isSelected
            ? DarkColor.highlightColor.withOpacity(0.2)
            : DarkColor.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: utility.isSelected
              ? DarkColor.highlightColor
              : Colors.grey[700]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            utility.icon,
            size: 16,
            color: utility.isSelected ? DarkColor.highlightColor : Colors.white70,
          ),
          SizedBox(width: 6),
          Text(
            utility.name,
            style: TextStyle(
              color: utility.isSelected ? Colors.white : Colors.white70,
            ),
          ),
          SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: DarkColor.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          content,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _libraryNameController.dispose();
    _ownerNameController.dispose();
    _landMarkController.dispose();
    _seatsController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _customUtilityController.dispose();
    _weekdaysOpenController.dispose();
    _weekdaysCloseController.dispose();
    _weekendOpenController.dispose();
    _weekendCloseController.dispose();

    // Dispose shift controllers
    for (var controller in _shiftStartTimeControllers) {
      controller.dispose();
    }
    for (var controller in _shiftEndTimeControllers) {
      controller.dispose();
    }
    for (var controller in _shiftFeeControllers) {
      controller.dispose();
    }

    // Dispose rule controllers
    for (var controller in _rulesControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}