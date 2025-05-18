import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinput/pinput.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/user-pages/market_place.dart';
import 'package:smartlib/user-pages/Login.dart';
import 'package:smartlib/user-pages/success_page.dart';
import 'package:smartlib/widgets/input_field.dart'; // Import InputField
import 'package:smartlib/widgets/solid_button.dart'; // Import SolidButton
import 'package:smartlib/widgets/next_button.dart'; // Import NextButton
import '../function/owner_function.dart';
import '../function/users_function.dart';
import '../widgets/linear_progress.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? verificationId;
  bool? optSent = false;
  bool? signUp = false;
  String selectedGender = "";
  bool _isLoading = false;
  bool _isPasswordVisible = true;
  int _currentStep = 0;

  // For profile image
  File? _profileImage;

  // For DOB
  DateTime _selectedDate = DateTime.now().subtract(
    const Duration(days: 365 * 20),
  ); // Default to 20 years ago

  // For location permission
  bool _locationPermissionGranted = false;

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
            dialogTheme: DialogThemeData(backgroundColor: Color(0xFF142E4F)),
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

  Future<void> _requestLocationPermission() async {
    bool granted = await AuthFunctions.requestLocationPermission(context);
    if (granted) {
      setState(() {
        _locationPermissionGranted = true;
      });
    }
  }

  Future<void> signUpWithPhone() async {
    // First check if user already exists
    bool userExists = await AuthFunctions.checkUserExists(
      _emailController.text,
      _phoneController.text,
      context,
    );

    if (userExists) {
      return;
    }

    await AuthFunctions.signUpWithPhone(
      _phoneController.text.trim(),
      context,
      (isLoading) {
        setState(() {
          _isLoading = isLoading;
        });
      },
      (String vid, bool sent, int step) {
        setState(() {
          verificationId = vid;
          optSent = sent;
          _currentStep = step;
        });
      },
    );
  }

  Future<void> verifyOtp() async {
    await AuthFunctions.verifyOtp(
      verificationId!,
      _otpController.text,
      context,
      (isLoading) {
        setState(() {
          _isLoading = isLoading;
        });
      },
      (bool success, int step) {
        setState(() {
          signUp = success;
          _currentStep = step;
        });
      },
    );
  }

  void _finishProfileSetup() async {
    bool success = await AuthFunctions.finishProfileSetup(
      context,
      (isLoading) {
        setState(() {
          _isLoading = isLoading;
        });
      },
      _emailController.text,
      _phoneController.text,
      _passwordController.text,
      _usernameController.text,
      selectedGender,
      _fullNameController.text,
      _selectedDate,
      _locationPermissionGranted,
      _profileImage,
    );

    if (success) {
      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MarketPlace(isSignedUp: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        // Add resizeToAvoidBottomInset to prevent overflow when keyboard appears
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(_getAppBarTitle()),
          centerTitle: true,
          elevation: 0,
        ),
        body:
            _isLoading
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        _getLoadingText(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                : _buildCurrentStep(),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0:
        return 'Sign Up';
      case 1:
        return 'OTP Verification';
      case 2:
        return 'Setup Account';
      case 3:
        return 'Personal Details';
      case 4:
        return 'Location Access';
      default:
        return 'Sign Up';
    }
  }

  String _getLoadingText() {
    switch (_currentStep) {
      case 0:
        return "Sending OTP...";
      case 1:
        return "Verifying OTP...";
      default:
        return "Setting up profile...";
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildRegistrationForm();
      case 1:
        return _buildOtpVerificationForm();
      case 2:
        return _buildUsernameGenderStep();
      case 3:
        return _buildPersonalDetailsStep();
      case 4:
        return _buildLocationPermissionStep();
      case 5:
        return SuccessPage();
      default:
        return _buildRegistrationForm();
    }
  }

  Widget _buildRegistrationForm() {
    // Use SingleChildScrollView with physics for better keyboard handling
    return SingleChildScrollView(
      physics: ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              "Create your account",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),

            // Email Field - Using InputField widget
            InputField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              labelText: 'Email Address',
              prefixIcon: Icons.email_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email address';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            // Phone Field - Using InputField widget
            InputField(
              controller: _phoneController,
              labelText: 'Phone Number',
              prefixText: '+91 ',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              prefixIcon: Icons.phone_android,
              maxLines: 1,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.length != 10) {
                  return 'Phone number must be 10 digits';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            // Password Field - Using InputField widget
            InputField(
              controller: _passwordController,
              labelText: 'Password',
              isPassword: _isPasswordVisible,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              maxLines: 1,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }

                String password = value.trim();

                if (password.length < 8) {
                  return 'Password should be at least 8 characters';
                }

                if (!RegExp(r'[a-z]').hasMatch(password)) {
                  return 'Password must contain at least one lowercase letter';
                }

                if (!RegExp(r'[A-Z]').hasMatch(password)) {
                  return 'Password must contain at least one uppercase letter';
                }

                if (!RegExp(r'\d').hasMatch(password)) {
                  return 'Password must contain at least one number';
                }

                if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
                  return 'Password must contain at least one special character';
                }

                return null;
              },
            ),
            SizedBox(height: 40),

            // Sign Up Button - Using SolidButton widget
            SolidButton(
              text: "SEND OTP",
              width: double.infinity,
              height: 50,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  signUpWithPhone(); // This will start the OTP verification process
                }
              },
            ),
            SizedBox(height: 20),

            // Already have an account option
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Already have an account? "),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Login()),
                    ); // Navigate to login page
                  },
                  child: Text("Login"),
                ),
              ],
            ),
            // Add extra padding to ensure content is visible above keyboard
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpVerificationForm() {
    // Define Pinput theme for OTP input
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(
        fontSize: 20,
        color: Color.fromRGBO(30, 60, 87, 1),
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Color.fromRGBO(234, 239, 243, 1)),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Color.fromRGBO(114, 178, 238, 1)),
      borderRadius: BorderRadius.circular(8),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: Color.fromRGBO(234, 239, 243, 1),
      ),
    );

    return SingleChildScrollView(
      physics: ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20),
          Icon(Icons.sms, size: 80, color: Colors.blue),
          SizedBox(height: 20),
          Text(
            "OTP Verification",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Text(
            "We've sent a verification code to\n+91 ${_phoneController.text.trim()}",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),

          // Use Pinput
          Center(
            child: Pinput(
              controller: _otpController,
              length: 6,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onCompleted: (pin) {
                // Dismiss keyboard when OTP is completely entered
                FocusScope.of(context).unfocus();
              },
            ),
          ),

          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't receive the code? "),
              TextButton(
                onPressed: () {
                  signUpWithPhone(); // Resend OTP
                },
                child: Text("Resend"),
              ),
            ],
          ),
          SizedBox(height: 40),

          // Using SolidButton widget
          SolidButton(
            text: "VERIFY & PROCEED",
            width: double.infinity,
            height: 50,
            onPressed: () {
              // Dismiss keyboard
              FocusScope.of(context).unfocus();
              verifyOtp(); // Verify OTP and proceed
            },
          ),
          SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 0; // Go back to registration form
                optSent = false;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back),
                SizedBox(width: 8),
                Text("Back to registration"),
              ],
            ),
          ),
          // Add extra space at bottom to avoid keyboard overlap
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUsernameGenderStep() {
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
                  // Progress bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 1, totalSteps: 3),
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
                                          selectedGender = "Female";
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
                                            selectedGender == "Female"
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
                                          selectedGender = "Male";
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
                                            selectedGender == "Male"
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
                      bottom: 20 + MediaQuery.of(context).viewInsets.bottom / 2,
                    ),
                    child: NextButton(
                      isEnabled: _usernameController.text.trim().isNotEmpty,
                      onPressed: () {
                        // Dismiss keyboard
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _currentStep = 3; // Move to personal details step
                        });
                      },
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
                  // Progress bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 2, totalSteps: 3),
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
                      bottom: 20 + MediaQuery.of(context).viewInsets.bottom / 2,
                    ),
                    child: NextButton(
                      isEnabled: _fullNameController.text.trim().isNotEmpty,
                      onPressed: () {
                        // Dismiss keyboard
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _currentStep = 4; // Move to location permissions step
                        });
                      },
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

  Widget _buildLocationPermissionStep() {
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
                  // Progress bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.04,
                    ),
                    child: CustomProgressBar(currentStep: 3, totalSteps: 3),
                  ),
                  SizedBox(height: 50),

                  // Location section
                  Column(
                    children: [
                      // Location Icon
                      Icon(
                        Icons.location_on,
                        color: DarkColor.highlightColor,
                        size: 70, // Reduced size for better fit
                      ),
                      const SizedBox(height: 20),

                      // Title
                      const Text(
                        "Your Location?",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Subtitle
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "We need access to your location to provide you with nearby services and recommendations.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Primary Button - Using SolidButton
                      // Primary Button
                      SizedBox(
                        width: w * 0.8,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              _locationPermissionGranted
                                  ? null
                                  : _requestLocationPermission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _locationPermissionGranted
                                    ? Colors.green
                                    : DarkColor.highlightColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _locationPermissionGranted
                                ? "Permission Granted"
                                : "Allow Location Access",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Manual address entry option
                      TextButton(
                        onPressed: () {},
                        child: Text("Enter Address Manually",style: TextStyle(color: DarkColor.highlightColor),),
                      ),
                    ],
                  ),

                  Spacer(),

                  // Complete button - Using SolidButton
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: SolidButton(
                      text: "Complete Profile",
                      width: double.infinity,
                      height: 50,
                      onPressed: _finishProfileSetup,
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
