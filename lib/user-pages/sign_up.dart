import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:smartlib/user-pages/student_profile_setup.dart'; // Import student profile page
import 'package:smartlib/user-pages/Login.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/solid_button.dart';
import '../function/users_function.dart';
import '../owner-pages/librarian_profile_setup.dart';

// Define user types
enum UserType { student, librarian }

class SignUp extends StatefulWidget {
  final UserType userType;

  const SignUp({Key? key, required this.userType}) : super(key: key);

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? verificationId;
  bool? optSent = false;
  bool _isLoading = false;
  bool _isPasswordVisible = true;
  int _currentStep = 0;

  Future<void> signUpWithPhone() async {
    setState(() {
      _isLoading = true;
    });
    // First check if user already exists
    bool userExists = await AuthFunctions.checkUserExists(
      _emailController.text,
      _phoneController.text,
      context,
    );

    if (userExists) {
      setState(() {
        _isLoading = false;
      });
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
          _currentStep = 1; // Move to OTP verification step
        });
      },
    );
  }

  Future<void> verifyOtp() async {
    await AuthFunctions.verifyOtp(
      verificationId!,
      _otpController.text,
      _emailController.text.trim(),
      _passwordController.text.trim(),
      context,
      (isLoading) {
        setState(() {
          _isLoading = isLoading;
        });
      },
      (bool success, int step) {
        if (success) {
          // Navigate based on user type
          _navigateToProfileSetup();
        }
      },
    );
  }

  // Function to navigate to the appropriate profile setup page
  void _navigateToProfileSetup() {
    if (widget.userType == UserType.student) {
      // Navigate to student profile setup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => StudentProfileSetupPage(
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
              ),
        ),
      );
    } else {
      // Navigate to librarian profile setup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => LibrarianProfileSetupPage(
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(_currentStep == 0 ? 'Sign Up' : 'OTP Verification'),
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
                        _currentStep == 0
                            ? "Sending OTP..."
                            : "Verifying OTP...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                : _currentStep == 0
                ? _buildRegistrationForm()
                : _buildOtpVerificationForm(),
      ),
    );
  }

  Widget _buildRegistrationForm() {
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
            // Title with user type
            Text(
              "Create your ${widget.userType == UserType.student ? 'Student' : 'Librarian'} account",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
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

            // Sign Up Button
            SolidButton(
              text: "SEND OTP",
              width: double.infinity,
              height: 50,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  signUpWithPhone(); // Start the OTP verification process
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
                    );
                  },
                  child: Text("Login"),
                ),
              ],
            ),
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
    super.dispose();
  }
}
