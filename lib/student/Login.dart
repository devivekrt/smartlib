import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/librarian/librarian_home_page.dart';
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
              password: password
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
        String userId = "";
        bool foundInDatabase = false;

        // Check if user exists in student collection
        if (studentSnapshot.snapshot.exists) {
          Map<dynamic, dynamic>? users = studentSnapshot.snapshot.value as Map?;
          if (users != null) {
            userId = users.keys.first.toString();
            userRole = 'student';
            foundInDatabase = true;
          }
        }
        // Check if user exists in librarian collection
        else if (librarianSnapshot.snapshot.exists) {
          Map<dynamic, dynamic>? users = librarianSnapshot.snapshot.value as Map?;
          if (users != null) {
            userId = users.keys.first.toString();
            userRole = 'librarian';
            foundInDatabase = true;
          }
        }

        // If authenticated with Firebase but not found in our database, sign out
        if (!foundInDatabase) {
          await FirebaseAuth.instance.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Email not registered in our system')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        SmartLib.userId = userId;
        NotificationService().saveUserToken(userId);

        // Save session data
        await AuthService.saveUserSession(userId, userRole);

        // Navigate based on role
        final nextScreen = userRole == 'student' ? MainTabScreen() : LibrarianNavigationPage();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => nextScreen),
              (route) => false, // Remove all previous routes
        );

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
            errorMessage = 'Too many failed login attempts. Please try again later.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection.';
            break;
          default:
            errorMessage = 'Authentication failed. Please check your email and password.';
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

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? _buildLoadingOverlay()
        : _buildLoginScreen();
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
                      )
                    ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: const Color(0xff1940CC),
                    ),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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

  // Normal login screen
  Widget _buildLoginScreen() {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
            title: Text("Login"),
            centerTitle: true,
            elevation: 0
        ),
        body: Column(
          children: [

            // Main login form
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        "Welcome Back",
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
                            r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
                          ).hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      Gap(20),

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
                      SizedBox(height: 40),

                      // Login Button
                      SolidButton(
                        text: "Login",
                        width: double.infinity,
                        height: 50,
                        onPressed: _userLogin,
                      ),
                      Gap(20),

                      // Sign up option
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account? "),
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
                            child: Text("Sign Up"),
                          ),
                        ],
                      ),
                      Gap(20),
                    ],
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}