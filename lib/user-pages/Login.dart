import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartlib/logic/string.dart';
import 'package:smartlib/owner-pages/librarian_home_page.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/user-pages/home_page.dart';
import 'package:smartlib/user-pages/library_market_place.dart';
import 'package:smartlib/user-pages/market_place.dart';
import 'package:smartlib/user-pages/select_page.dart';
import 'package:smartlib/user-pages/student_home_page.dart';
import 'package:smartlib/widgets/solid_button.dart';

import '../function/users_function.dart';
import '../widgets/input_field.dart';

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

        // Start multiple operations in parallel:
        // 1. Begin Firebase Auth process
        // 2. Query student database
        // 3. Query librarian database
        final firebaseAuthFuture = FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        // Database queries already run in parallel with Future.wait
        final databaseQueriesFuture = Future.wait([
          databaseRef
              .child("${SmartLib.constPath}/students")
              .orderByChild(SmartLib.constEmail)
              .equalTo(email)
              .once(),
          databaseRef
              .child("${SmartLib.constPath}/librarians")
              .orderByChild(SmartLib.constEmail)
              .equalTo(email)
              .once(),
        ]);

        // Run Firebase Auth and database queries in parallel
        // This is a key optimization - we don't wait for DB queries to complete before starting auth
        final results = await Future.wait([
          firebaseAuthFuture.then((_) => true).catchError((_) => false),
          databaseQueriesFuture,
        ]);

        // Check Firebase Auth result
        final bool isFirebaseAuthSuccessful = results[0] as bool;
        if (!isFirebaseAuthSuccessful) {
          // If Firebase Auth failed, throw to be caught by exception handler
          throw FirebaseAuthException(code: 'auth-failed');
        }

        // Process database query results - these have already completed in parallel
        final dbResults = results[1] as List<dynamic>;
        final DatabaseEvent studentSnapshot = dbResults[0];
        final DatabaseEvent librarianSnapshot = dbResults[1];

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
          Map<dynamic, dynamic>? users =
              librarianSnapshot.snapshot.value as Map?;
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

        // Authentication successful and user found in database
        SmartLib.email = email;
        SmartLib.userId = userId;

        // Start saving session data and pre-loading the next screen in parallel
        final saveSessionFuture = AuthService.saveUserSession(userId, userRole);

        // Prepare the next screen widget in advance
        final nextScreen =
            userRole == 'student' ? HomePage() :HomePage();

        // Wait for session data to be saved
        await saveSessionFuture;

        // Navigate based on role
        // Use pushAndRemoveUntil to clear the entire navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => nextScreen),
              (route) => false, // Remove all previous routes
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login Successful!')));
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Invalid email or password';

        if (e.code == 'wrong-password') {
          errorMessage = 'Wrong password provided';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'This account has been disabled';
        } else if (e.code == 'user-not-found') {
          errorMessage = 'No user found with this email';
        } else if (e.code == 'auth-failed') {
          errorMessage =
              'Authentication failed. Please check your credentials.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login error: Please try again')),
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
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return SafeArea(
      child:

              Scaffold(
                appBar: AppBar(
                  title: Text("Login"),
                  centerTitle: true,
                  elevation: 0,
                ),
                body: // Main content - always present but may be obscured by loading overlay
                    Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        Text(
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
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
                            if (!RegExp(
                              r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
                            ).hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Password Field
                        InputField(
                          controller: _passwordController,
                          labelText: 'Password',
                          isPassword: !_isPasswordVisible,
                          // Corrected logic
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
                        // Login Button with integrated progress indicator
                        _isLoading
                            ? Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                "Logging in...",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                            : SolidButton(
                          text: "Login",
                          width: double.infinity,
                          height: 50,
                          onPressed: _userLogin,
                        ),
                        SizedBox(height: 20),

                        // Sign up option (corrected text)
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
                                    builder:
                                        (context) =>
                                            SelectPage(), // Replace with your actual sign up page
                                  ),
                                );
                              },
                              child: Text("Sign Up"),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
