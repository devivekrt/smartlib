import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/student/library_market_place.dart';
import 'package:smartlib/student/success_page.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/next_button.dart';
import 'package:smartlib/widgets/linear_progress.dart';
import 'package:smartlib/widgets/solid_button.dart';
import '../function/student_function.dart';

// Add geolocator for continuous location tracking
import 'package:geolocator/geolocator.dart';

class StudentProfileSetupPage extends StatefulWidget {
  final String email;
  final String phone;

  const StudentProfileSetupPage({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  _StudentProfileSetupPageState createState() =>
      _StudentProfileSetupPageState();
}

class _StudentProfileSetupPageState extends State<StudentProfileSetupPage> {
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();

  // State variables
  String _selectedGender = "";
  bool _isLoading = false;
  int _currentStep = 0;
  File? _profileImage;
  DateTime _selectedDate = DateTime.now().subtract(
    const Duration(days: 365 * 20),
  );
  bool _locationPermissionGranted = false;

  // Location data
  String? _latitude;
  String? _longitude;
  String? _address;

  // For continuous location updates
  StreamSubscription<Position>? _positionSubscription;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _usernameController.dispose();
    _fullNameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  // Pick profile image
  Future<void> _pickImage() async {
    File? pickedImage = await AuthFunctions.pickImage(context);
    if (pickedImage != null) {
      setState(() {
        _profileImage = pickedImage;
      });
    }
  }

  // Date picker
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

  // Get current location (more accurate than just tracking)
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get precise location with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );

      // Try to get address from coordinates
      String? address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          List<String> addressParts = [];

          if (place.street != null && place.street!.isNotEmpty)
            addressParts.add(place.street!);
          if (place.locality != null && place.locality!.isNotEmpty)
            addressParts.add(place.locality!);
          if (place.postalCode != null && place.postalCode!.isNotEmpty)
            addressParts.add(place.postalCode!);

          address = addressParts.join(", ");
        }
      } catch (e) {
        print('Error getting address: $e');
      }

      // Update state with new location data
      setState(() {
        _latitude = position.latitude.toString();
        _longitude = position.longitude.toString();
        _address = address;
        _locationPermissionGranted = true;
        _isLoading = false;
      });

      // Save to shared preferences for persistence
      _saveLocationToPreferences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: ${e.toString()}')),
      );
    }
  }

// Helper function to save location data
  Future<void> _saveLocationToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_latitude', _latitude ?? '');
      await prefs.setString('user_longitude', _longitude ?? '');
      await prefs.setString('user_address', _address ?? '');
      await prefs.setString('location_updated', DateTime.now().toIso8601String());

      // Log for debugging
    } catch (e) {
    }
  }

  void _finishProfileSetup() {
    if (_locationPermissionGranted &&
        (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location permission granted but coordinates not obtained. Please try again.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProgressSuccessPage(
              title: "Setting Up Profile",
              loadingMessage: "Creating your account...",
              completedMessage: "Profile Created Successfully!",
              taskFunction: () async {
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
                );
                return true;
              },
              onComplete: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const LibraryMarketplace(isSignedUp: true),
                  ),
                );
              },
            ),
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a username")));
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

  Future<bool> _onWillPop() async {
    if (_currentStep > 0) {
      _previousStep();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Text(_getAppBarTitle()),
            centerTitle: true,
            leading:
                _currentStep > 0
                    ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _previousStep,
                    )
                    : null,
          ),
          body:
              _isLoading
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        Gap(20),
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
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 1, totalSteps: 4),
                  ),
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
                                      radius: 60,
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
                              Gap(20),
                              InputField(
                                controller: _usernameController,
                                labelText: 'Username',
                                hintText: 'Enter Username',
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.blue[200]!,
                                ),
                              ),
                              Gap(20),
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
                  Padding(
                    padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: NextButton(
                      isEnabled:
                          _usernameController.text.trim().isNotEmpty &&
                          _selectedGender.isNotEmpty,
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
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 2, totalSteps: 4),
                  ),
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
                              InputField(
                                controller: _fullNameController,
                                labelText: 'Full Name',
                                hintText: 'Enter your full name',
                                borderRadius: BorderRadius.circular(8),
                              ),
                              SizedBox(height: 30),
                              GestureDetector(
                                onTap: () {
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
                  Padding(
                    padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: NextButton(
                      isEnabled:
                          _fullNameController.text.trim().isNotEmpty &&
                          _departmentController.text.isNotEmpty,
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
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: w * 0.05,
                        vertical: h * 0.04,
                      ),
                      child: CustomProgressBar(currentStep: 3, totalSteps: 4),
                    ),
                    SizedBox(height: 30),
                    Column(
                      children: [
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
                                color: _locationPermissionGranted
                                    ? Colors.green
                                    : DarkColor.highlightColor,
                                size: 100,
                              ),
                            ),
                            if (_locationPermissionGranted)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: DarkColor.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: DarkColor.secondary,
                                    width: 3,
                                  ),
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
                        Text(
                          _locationPermissionGranted
                              ? "Location Captured!"
                              : "Your Location?",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _locationPermissionGranted
                                ? "Your location has been successfully recorded."
                                : "We need access to your location to provide you with nearby libraries and recommendations.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        // Display current location if available
                        if (_locationPermissionGranted && _latitude != null &&
                            _longitude != null) ...[
                          const SizedBox(height: 30),
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: DarkColor.cardColor.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.my_location, color: Colors.green,
                                        size: 18),
                                    SizedBox(width: 10),
                                    Text(
                                      'Current Location',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            'Latitude',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _latitude!,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      height: 30,
                                      width: 1,
                                      color: Colors.grey.withOpacity(0.3),
                                      margin: EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            'Longitude',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _longitude!,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_address != null &&
                                    _address!.isNotEmpty) ...[
                                  SizedBox(height: 12),
                                  Divider(color: Colors.grey.withOpacity(0.3),
                                      height: 1),
                                  SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Icon(Icons.place, color: Colors.white70,
                                          size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _address!,
                                          style: TextStyle(color: Colors.white,
                                              fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 30),

                        // Main location button
                        SolidButton(
                          text: _locationPermissionGranted
                              ? "Update Location"
                              : "Allow Location Access",
                          width: w * 0.8,
                          height: 50,
                          onPressed: _getCurrentLocation,
                          buttonColor: _locationPermissionGranted
                              ? Colors.green
                              : DarkColor.highlightColor,
                        ),

                        // Get Current Location button
                        if (_locationPermissionGranted)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextButton.icon(
                              onPressed: _getCurrentLocation,
                              icon: Icon(
                                Icons.my_location,
                                color: DarkColor.highlightColor,
                                size: 20,
                              ),
                              label: Text(
                                "Get Current Location",
                                style: TextStyle(
                                  color: DarkColor.highlightColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: BorderSide(
                                      color: DarkColor.highlightColor
                                          .withOpacity(0.5)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Spacer(),
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: SolidButton(
                        text: "Complete Profile",
                        onPressed: _finishProfileSetup,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
    );
  }}
