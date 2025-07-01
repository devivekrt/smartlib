import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/librarian/librarian_home_page.dart';
import 'package:smartlib/library/library_details_upload.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/student/library_market_place.dart';
import 'package:smartlib/student/select_page.dart';
import 'package:smartlib/student/student_home_page.dart';
import 'package:smartlib/widgets/solid_button.dart';

import '../function/notification_service.dart';
import '../function/student_function.dart';
import '../librarian/bottom_navigation/librarain_navigation_page.dart';
import '../widgets/input_field.dart';
import 'main_tab_screen.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _userLogin() async {
    setState(() {
      _isLoading = true;
    });

    // Check if email and password fields are not empty
    if (_formKey.currentState!.validate()) {
      try {
        String email = _emailController.text.trim();
        String password = _passwordController.text.trim();

        // First, attempt Firebase authentication directly to get proper error codes
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (authError) {
          // Let the specific Firebase auth error bubble up to the main catch block
          throw authError;
        }

        // If authentication succeeds, proceed with database checks
        final databaseQueries = await Future.wait([
          databaseRef
              .child(SmartLib.constStudentPath)
              .orderByChild(SmartLib.constEmail)
              .equalTo(email)
              .once(),
          databaseRef
              .child(SmartLib.constLibrarianPath)
              .orderByChild(SmartLib.constEmail)
              .equalTo(email)
              .once(),
        ]);

        final DatabaseEvent studentSnapshot = databaseQueries[0];
        final DatabaseEvent librarianSnapshot = databaseQueries[1];

        // Initialize variables to track role information
        String userRole = "";
        String studentId = "";
        String librarianId = "";
        bool foundInDatabase = false;
        Map<dynamic, dynamic>? userData;

        // Check if user exists in student collection
        if (studentSnapshot.snapshot.exists) {
          Map<dynamic, dynamic>? users = studentSnapshot.snapshot.value as Map?;
          if (users != null) {
            studentId = users.keys.first.toString();
            userData = users[studentId] as Map<dynamic, dynamic>?;
            userRole = 'student';
            foundInDatabase = true;
          }
        }
        // Check if user exists in librarian collection
        else if (librarianSnapshot.snapshot.exists) {
          Map<dynamic, dynamic>? users =
              librarianSnapshot.snapshot.value as Map?;
          if (users != null) {
            librarianId = users.keys.first.toString();
            userData = users[librarianId] as Map<dynamic, dynamic>?;
            userRole = 'librarian';
            foundInDatabase = true;
          }
        }

        // If authenticated with Firebase but not found in our database, sign out
        if (!foundInDatabase) {
          await FirebaseAuth.instance.currentUser?.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Email not registered in our system')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        SmartLib.studentId = studentId;
        SmartLib.librarianId = librarianId;
        if (userRole == 'student') {
          SmartLib.userType = 'student';
          NotificationService().saveUserToken(studentId);
          // Save session data
          await AuthService.saveUserSession(studentId, 'student');
        } else if (userRole == 'librarian') {
          SmartLib.userType = 'librarian';
          NotificationService().saveUserToken(librarianId);
          // Save session data
          await AuthService.saveUserSession(librarianId, 'librarian');
        }

        // Navigate based on role
        if (userRole == 'student') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => MainTabScreen()),
            (route) => false,
          );
        } else {
          // Check if the librarian has an associated library
          if (userData != null && userData['libraryAdded'] == true) {
            // Librarian has a library, proceed to normal navigation
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => LibrarianNavigationPage(),
              ),
              (route) => false,
            );
          } else {
            // Librarian doesn't have a library, redirect to create library page
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (context) => LibraryDetailsUpload(librarianId: librarianId),
              ),
            );

            // Show a guiding message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please complete setting up your library to continue',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login Successful!')));
      } on FirebaseAuthException catch (e) {
        String errorMessage;

        // Provide detailed error messages based on Firebase error codes
        switch (e.code) {
          case 'invalid-email':
            errorMessage = 'The email address format is invalid.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled.';
            break;
          case 'user-not-found':
            errorMessage = 'No account found with this email.';
            break;
          case 'wrong-password':
            errorMessage = 'The password is incorrect. Please try again.';
            break;
          case 'too-many-requests':
            errorMessage =
                'Too many failed login attempts. Please try again later.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection.';
            break;
          default:
            errorMessage =
                'Authentication failed. Please check your email and password.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Rest of the class remains the same
  @override
  Widget build(BuildContext context) {
    return _isLoading ? _buildLoadingOverlay() : _buildLoginScreen();
  }

  // Full screen loading overlay without using Stack
  Widget _buildLoadingOverlay() {
    return Scaffold(
      body: Column(
        children: [
          // Expanded section with centered loading indicator
          Expanded(
            child: Center(
              child: Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: const Color(0xff1940CC)),
                    SizedBox(height: 16),
                    Text(
                      "Logging in...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Please wait while we verify your credentials",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

  // Updated Login Screen
  Widget _buildLoginScreen() {
    // Login screen implementation remains the same
    // ...
    // (Your existing _buildLoginScreen code here)
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Login"),
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  // Title
                  const Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    "Sign in to continue",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

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
                        r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
                      ).hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const Gap(20),

                  // Password Field
                  InputField(
                    controller: _passwordController,
                    labelText: 'Password',
                    isPassword: !_isPasswordVisible,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                      return null;
                    },
                  ),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showForgotPasswordDialog();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: DarkColor.highlightColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Login Button
                  SolidButton(
                    text: "Login",
                    width: double.infinity,
                    height: 50,
                    onPressed: _userLogin,
                  ),
                  const Gap(20),

                  // Sign up option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          // Navigate to sign up page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SelectPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            color: DarkColor.highlightColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    // Forgot password dialog implementation remains the same
    // ...
    // (Your existing _showForgotPasswordDialog code here)
    final TextEditingController emailController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: DarkColor.cardColor,
              title: const Text('Reset Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your email address. We\'ll send you a link to reset your password.',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    InputField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      labelText: 'Email Address',
                      prefixIcon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email address';
                        }
                        if (!RegExp(
                          r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
                        ).hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            if (formKey.currentState!.validate()) {
                              setState(() {
                                isLoading = true;
                              });

                              try {
                                await FirebaseAuth.instance
                                    .sendPasswordResetEmail(
                                      email: emailController.text.trim(),
                                    );

                                // Close dialog
                                Navigator.of(context).pop();

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password reset link has been sent to your email',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } on FirebaseAuthException catch (e) {
                                String errorMessage =
                                    'Failed to send password reset email';

                                switch (e.code) {
                                  case 'user-not-found':
                                    errorMessage =
                                        'No user found with this email address';
                                    break;
                                  case 'invalid-email':
                                    errorMessage = 'Email address is invalid';
                                    break;
                                  case 'too-many-requests':
                                    errorMessage =
                                        'Too many requests. Please try again later';
                                    break;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                }
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarkColor.highlightColor,
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          )
                          : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
