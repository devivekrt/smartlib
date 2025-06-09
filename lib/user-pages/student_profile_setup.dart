import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/user-pages/library_market_place.dart';
import 'package:smartlib/user-pages/success_page.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/next_button.dart';
import 'package:smartlib/widgets/linear_progress.dart';
import 'package:smartlib/widgets/solid_button.dart';
import 'package:smartlib/user-pages/market_place.dart';
import '../function/users_function.dart';

class StudentProfileSetupPage extends StatefulWidget {
  final String email;
  final String phone;

  const StudentProfileSetupPage({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  _StudentProfileSetupPageState createState() => _StudentProfileSetupPageState();
}

class _StudentProfileSetupPageState extends State<StudentProfileSetupPage> {
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _universityIdController = TextEditingController(); // New field

  // State variables
  String _selectedGender = "";
  bool _isLoading = false;
  int _currentStep = 0;
  File? _profileImage;
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 365 * 20));
  bool _locationPermissionGranted = false;

  // Location data
  String? _latitude;
  String? _longitude;
  List<String> location = [];
  List<String> _favoriteLibraries = []; // New field for favorite libraries

  // Methods for profile setup
  Future<void> _pickImage() async {
    File? pickedImage = await AuthFunctions.pickImage(context);
    if (pickedImage != null) {
      setState(() {
        _profileImage = pickedImage;
      });
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

  Future<void> _getCurrentLocation() async {
    location = await AuthFunctions.getCurrentLocation(context, (isLoading) {
      setState(() {
        _isLoading = isLoading;
      });
    },);
    setState(() {
      _locationPermissionGranted = true;
    });
    _latitude = location[0];
    _longitude = location[1];
  }

  void _finishProfileSetup() {
    // Add validation if needed
    if (_locationPermissionGranted && (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission granted but coordinates not obtained. Please try again.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgressSuccessPage(
          title: "Setting Up Profile",
          loadingMessage: "Creating your account...",
          completedMessage: "Profile Created Successfully!",
          taskFunction: () async {
            // Your profile creation logic with updated parameters
            await AuthFunctions.finishStudentProfile(
              context,
                  (isLoading) {},
              widget.email,
              widget.phone,
              _departmentController.text,
              _usernameController.text,
              _fullNameController.text,
              _selectedGender,
              _selectedDate,
              _locationPermissionGranted,
              _profileImage,
              latitude: _latitude ?? '',
              longitude: _longitude ?? '',
            );
            return true;
          },
          onComplete: () {
            // Navigate to marketplace after completion
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LibraryMarketplace(isSignedUp: true)),
            );
          },
        ),
      ),
    );
  }

  // Previous/next step navigation
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _nextStep() {
    // Validate current step before proceeding
    if (_currentStep == 0 && _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a username")),
      );
      return;
    }

    if (_currentStep == 1 && _fullNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (_currentStep > 0) {
      _previousStep();
      return false;
    }
    return true; // Allow app to exit if on first step
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return WillPopScope(
      onWillPop: _onWillPop, // Handle device back button
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Text(_getAppBarTitle()),
            centerTitle: true,
            leading: _currentStep > 0
                ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _previousStep,
            )
                : null,
          ),
          body: _isLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Fetching Location..."),
              ],
            ),
          )
              : _buildCurrentStep(),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0:
        return "Basic Info";
      case 1:
        return "Personal Details";
      default:
        return "Location";
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildPersonalDetailsStep();
      default:
        return _buildLocationStep();
    }
  }

  Widget _buildBasicInfoStep() {
    // Same implementation as before
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Progress bar - Updated total steps
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 1, totalSteps: 4),
                  ),

                  // Content area
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: SizedBox(
                      width: w / 1.1,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(15),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: 14),
                              GestureDetector(
                                onTap: _pickImage,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: DarkColor.highlightColor,
                                      radius: 60, // Reduced size for better fit
                                      backgroundImage:
                                      _profileImage != null
                                          ? FileImage(_profileImage!)
                                          : null,
                                      child:
                                      _profileImage == null
                                          ? Icon(
                                        Icons.person,
                                        size: 70,
                                        color: Colors.white,
                                      )
                                          : null,
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black,
                                      ),
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.edit,
                                        size: 25,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),

                              // Using InputField widget
                              InputField(
                                controller: _usernameController,
                                labelText: 'Username',
                                hintText: 'Enter Username',
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.blue[200]!,
                                ),
                              ),
                              SizedBox(height: 20),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Select Gender"),
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedGender = "Female";
                                        });
                                      },
                                      icon: Icon(
                                        Icons.female,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        "Female",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        _selectedGender == "Female"
                                            ? DarkColor.highlightColor
                                            : Colors.grey[800],
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedGender = "Male";
                                        });
                                      },
                                      icon: Icon(
                                        Icons.male,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        "Male",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        _selectedGender == "Male"
                                            ? DarkColor.highlightColor
                                            : Colors.grey[800],
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Spacer(),

                  // Next button - Using NextButton widget
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20 ,
                    ),
                    child: NextButton(
                      isEnabled: _usernameController.text.trim().isNotEmpty && _selectedGender.isNotEmpty,
                      onPressed: _nextStep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonalDetailsStep() {
    // Same implementation as before
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Progress bar - Updated total steps
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 2, totalSteps: 4),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: SizedBox(
                      width: w / 1.1,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Tell us more about yourself",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 30),

                              // Full Name - Using InputField widget
                              InputField(
                                controller: _fullNameController,
                                labelText: 'Full Name',
                                hintText: 'Enter your full name',
                                borderRadius: BorderRadius.circular(8),
                              ),

                              SizedBox(height: 30),

                              // Date of Birth with date picker
                              GestureDetector(
                                onTap: () {
                                  // Dismiss keyboard before showing date picker
                                  FocusScope.of(context).unfocus();
                                  _selectDate(context);
                                },
                                child: Container(
                                  width: w / 1.2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: DarkColor.borderColor,
                                    ),
                                  ),
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'DOB: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: 30),

                              // Department field
                              InputField(
                                controller: _departmentController,
                                labelText: 'Department/Faculty',
                                hintText: 'E.g., Computer Science, Arts',
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Spacer(),

                  // Next button
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    child: NextButton(
                      isEnabled: _fullNameController.text.trim().isNotEmpty && _departmentController.text.isNotEmpty,
                      onPressed: _nextStep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationStep() {
    // Same implementation with updated progress bar
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Progress bar - Updated total steps
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 3, totalSteps: 4),
                  ),
                  SizedBox(height: 30),

                  // Location section with enhanced UI
                  Column(
                    children: [
                      // Location Icon with status indicator
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: DarkColor.cardColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(30),
                            child: Icon(
                              Icons.location_on,
                              color: _locationPermissionGranted ? Colors.green : DarkColor.highlightColor,
                              size: 100,
                            ),
                          ),
                          if (_locationPermissionGranted)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: DarkColor.cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: DarkColor.secondary, width: 3),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 30,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Title - Enhanced with dynamic text
                      Text(
                        _locationPermissionGranted ? "Location Captured!" : "Your Location?",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Subtitle - Enhanced with dynamic text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _locationPermissionGranted
                              ? "Your location has been successfully recorded."
                              : "We need access to your location to provide you with nearby libraries and recommendations.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Button - Using SolidButton for consistent styling
                      SolidButton(
                        text: _locationPermissionGranted ? "Update Location" : "Allow Location Access",
                        width: w * 0.8,
                        height: 50,
                        onPressed: _getCurrentLocation,
                        buttonColor: _locationPermissionGranted ? Colors.green : DarkColor.highlightColor,
                      ),

                      const SizedBox(height: 20),

                      // Manual entry option
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: DarkColor.cardColor,
                              title: const Text("Manual Entry", style: TextStyle(color: Colors.white)),
                              content: const Text("This feature is coming soon!", style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("OK", style: TextStyle(color: DarkColor.highlightColor)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          "Enter Address Manually",
                          style: TextStyle(
                            color: DarkColor.highlightColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  Spacer(),

                  // Next button - Changed to progress to university details
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: SolidButton(text: "Complete Profile", onPressed: _finishProfileSetup,width: double.infinity,)
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }
}