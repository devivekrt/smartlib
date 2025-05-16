import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartlib/user-pages/test.dart';
import 'package:smartlib/widgets/solid_button.dart';
import 'dart:io';
import '../logic/string.dart';
import '../widgets/input_field.dart';
import '../widgets/next_button.dart';

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

  String? verificationId;
  bool? optSent = false;
  bool? signUp = false;
  String selectedGender = "Male";
  bool _isLoading = false;
  bool _isPasswordVisible = true;
  int _currentStep = 0;

  // For profile image
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // For DOB
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 365 * 20)); // Default to 20 years ago

  // For location permission
  bool _locationPermissionGranted = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
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
            ), dialogTheme: DialogThemeData(backgroundColor: Color(0xFF142E4F)),
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
    // This would typically use a plugin like geolocator
    // For this example, we'll simulate permission being granted


    setState(() {
      _locationPermissionGranted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location permission granted!')),
    );
  }

  Future<void> signUpWithPhone() async {
    setState(() {
      _isLoading = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification
        await FirebaseAuth.instance.signInWithCredential(credential);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Phone verification complete!')));

        setState(() {
          _isLoading = false;
          signUp = true;
          _currentStep = 2; // Move directly to profile setup
        });
      },

      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone verification failed: ${e.message}')),
        );
      },

      codeSent: (String verification, int? resendToken) {
        setState(() {
          verificationId = verification;
          optSent = true;
          _isLoading = false;
          _currentStep = 1; // Move to OTP step
        });

       /* // Auto-populate username from email
        if (_usernameController.text.isEmpty) {
          _usernameController.text = _emailController.text.split('@')[0];
        }*/

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to your phone.')),
        );
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Timeout: Please try again')));
      },
    );
  }

  Future<void> verifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId!,
      smsCode: _otpController.text.trim(),
    );

    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OTP verification successful')));

      setState(() {
        signUp = true;
        _isLoading = false;
        _currentStep = 2; // Move to profile setup step 1
      });

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP verification failed: ${e.message}')),
      );
    }
  }

  void _finishProfileSetup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("No authenticated user found");
      }

      String authId = currentUser.uid;
      String userId = DateTime.now().millisecondsSinceEpoch.toString();
      /*String? profileImageUrl;

      // Upload profile image if selected
      if (_profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(_profileImage!);
        profileImageUrl = await storageRef.getDownloadURL();
      }*/

      // Save all user data to Firebase Database
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users/$userId');

      // Save all user data in a single map
      Map<String, dynamic> userData = {
        'authId': authId,
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
        'username': _usernameController.text.trim(),
        'gender': selectedGender,
        'fullName': _fullNameController.text.trim(),
        'dateOfBirth': _selectedDate.toIso8601String(),
        'hasLocationPermission': _locationPermissionGranted,
        'profileCompleted': true,
        'profileCreatedAt': DateTime.now().toIso8601String(),
        'profileUpdatedAt': DateTime.now().toIso8601String(),
      };

      // Save the complete user data to Firebase
      await userRef.set(userData);

      // Update display name in Firebase Auth
      await currentUser.updateDisplayName(_fullNameController.text.isNotEmpty
          ? _fullNameController.text.trim()
          : _usernameController.text.trim());

      /*if (profileImageUrl != null) {
        await currentUser.updatePhotoURL(profileImageUrl);
      }*/

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile setup successful!')),
      );

      // Navigate to home screen

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
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
      default:
        return _buildRegistrationForm();
    }
  }

  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              "Create your account",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),

            // Email Field
            InputField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              labelText: 'Email Address',
              prefixIcon: Icons.email_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            // Phone Field
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

            // Password Field
            InputField(
              controller: _passwordController,
              labelText: 'Password',
              isPassword: _isPasswordVisible,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
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

                if (!RegExp(
                  r'[!@#$%^&*(),.?":{}|<>]',
                ).hasMatch(password)) {
                  return 'Password must contain at least one special character';
                }

                return null;
              },
            ),

            SizedBox(height: 40),

            // Sign Up Button
            SolidButton(
              text: "SEND OTP",
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // signUpWithPhone(); // This will start the OTP verification process
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
                    // Navigator.pop(context); // Navigate to login page
                  },
                  child: Text("Login"),
                ),
              ],
            ),
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
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20),
          Icon(
            Icons.sms,
            size: 80,
            color: Colors.blue,
          ),
          SizedBox(height: 20),
          Text(
            "OTP Verification",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Text(
            "We've sent a verification code to\n+91 ${_phoneController.text.trim()}",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
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
                // You can auto-verify when the user completes typing
                // Or you can keep the button for manual verification
                // verifyOtp();
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
          ElevatedButton(
            onPressed: () {
              verifyOtp(); // Verify OTP and proceed
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.blue,
            ),
            child: Text(
              "VERIFY & PROCEED",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        ],
      ),
    );
  }

  Widget _buildUsernameGenderStep() {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    var count = 1;
    var total = 3;

    return Container(
      child: Column(
        children: [
          // Progress bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.07),
            child: CustomProgressBar(currentStep: 2, totalSteps: 3),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  SizedBox(
                    width: w / 1.1,
                    height: h/2.3,
                    child: Card(
                      color: Color(0xFF142E4F),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Column(
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
                                    radius: 60,
                                    backgroundColor: Colors.lightBlue.shade900,
                                    backgroundImage: _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : null,
                                    child: _profileImage == null
                                        ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black,
                                    ),
                                    padding: EdgeInsets.all(7),
                                    child: Icon(Icons.edit,
                                        size: 28, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 25),
                            Container(
                              width: w/1.2,
                              decoration: BoxDecoration(
                                color: Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 12.0),
                              child: TextFormField(
                                controller: _usernameController,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(color: Colors.white),
                                  border: InputBorder.none,
                                  hintText: 'Enter Username',
                                  hintStyle: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                            SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      selectedGender = "Female";
                                    });
                                  },
                                  icon: Icon(Icons.female, color: Colors.white),
                                  label: Text("Female", style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedGender == "Female" ? Color(0xFF2196F3): Colors.grey[800],
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 40),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      selectedGender = "Male";
                                    });
                                  },
                                  icon: Icon(Icons.male, color: Colors.white),
                                  label: Text("Male", style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedGender == "Male" ? Colors.blue : Colors.grey[800],
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Spacer(),

          // Next button
          NextButton(
            isEnabled: _usernameController.text.trim().isNotEmpty,
            onPressed: () {
              setState(() {
                _currentStep = 3; // Move to personal details step
              });
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsStep() {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    var count = 2;
    var total = 3;

    return Container(
      child: Column(
        children: [
          // Progress bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.07),
            child: CustomProgressBar(currentStep: 2, totalSteps: 3),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: w / 1.1,
                height: h / 2.3,
                child: Card(
                  color: Color(0xFF142E4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
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

                        // Full Name
                        Container(
                          width: w / 1.2,
                          decoration: BoxDecoration(
                            color: Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: TextFormField(
                            controller: _fullNameController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: TextStyle(color: Colors.white),
                              border: InputBorder.none,
                              hintText: 'Enter your full name',
                              hintStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),

                        SizedBox(height: 30),

                        // Date of Birth with date picker
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: Container(
                            width: w / 1.2,
                            decoration: BoxDecoration(
                              color: Color(0xFF1E3A5F),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            ],
          ),

          Spacer(),

          // Next button
          NextButton(
            isEnabled: _fullNameController.text.trim().isNotEmpty,
            onPressed: () {
              setState(() {
                _currentStep = 4; // Move to location permissions step
              });
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLocationPermissionStep() {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    var count = 3;
    var total = 3;

    return Container(
      child: Column(
        children: [
          // Progress bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.07),
            child: CustomProgressBar(currentStep: 1, totalSteps: 3),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: w / 1.1,
                height: h / 2.3,
                child: Card(
                  color: Color(0xFF142E4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 80,
                          color: Colors.white,
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Location Access",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 15),
                        Text(
                          "We need access to your location to provide you with nearby services and recommendations.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _locationPermissionGranted ? null : _requestLocationPermission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _locationPermissionGranted ? Colors.green : Color(0xFF2196F3),
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          Spacer(),

          // Complete button
          NextButton(
            isEnabled: true, // Location permission is optional
            onPressed: () {
              _finishProfileSetup();
            },
          ),
          SizedBox(height: 20),
        ],
      ),
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
    super.dispose();
  }
}


