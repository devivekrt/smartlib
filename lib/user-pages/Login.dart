import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartlib/logic/string.dart';
import 'package:smartlib/user-pages/home_page.dart';
import 'package:smartlib/user-pages/market_place.dart';
import 'package:smartlib/user-pages/select_page.dart';
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
  bool _isPasswordVisible = true;
  bool _isLoading = false;

  Future<void> _userLogin() async {
    setState(() {
      _isLoading = true;
    });

    // Check if email and password fields are not empty
    if (_formKey.currentState!.validate()) {
      try {
        String email = _emailController.text.trim();

        // First, check which user type this email belongs to
        // This avoids attempting Firebase Auth if the email isn't in our database
        // It's also more efficient than checking after authentication

        String userRole = "";
        String userId = "";
        bool foundInDatabase = false;

        // Query the database once to determine user type before authentication
        // Check both collections with Promise.all equivalent (Future.wait)
        final results = await Future.wait([
          databaseRef
              .child("${SmartLib.constPath}/student")
              .orderByChild(SmartLib.constEmail)
              .equalTo(email)
              .once(),
          databaseRef
              .child("${SmartLib.constPath}/librarian")
              .orderByChild(SmartLib.constEmail)
              .equalTo(email)
              .once()
        ]);

        DatabaseEvent studentSnapshot = results[0];
        DatabaseEvent librarianSnapshot = results[1];

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

        // If email not found in our database, don't attempt Firebase Auth
        if (!foundInDatabase) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Email not registered in our system'))
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Now proceed with Firebase Authentication since we know the email exists
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );

        // Authentication successful, and we already have the user role
        SmartLib.email = email;
        SmartLib.userId = userId;

        // Save session data
        await AuthService.saveUserSession(userId, userRole);

        // Navigate based on role
        if (userRole == 'student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MarketPlace(isSignedUp: false)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Successful!'))
        );

      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Invalid email or password';

        if (e.code == 'wrong-password') {
          errorMessage = 'Wrong password provided';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'This account has been disabled';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );

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
    double width = MediaQuery
        .of(context)
        .size
        .width;
    double height = MediaQuery
        .of(context)
        .size
        .height;

    return SafeArea(
      child:_isLoading? Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
        ),
      ): Scaffold(
        appBar: AppBar(
          title: Text("Login"),
          centerTitle: true,
          elevation: 0,
        ),
        body:  // Main content - always present but may be obscured by loading overlay
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
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
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
                SolidButton(
                    text: "Login",
                    width: double.infinity,
                    height: 50,
                    onPressed: (){
                      if (_formKey.currentState!.validate()) {
                        _userLogin();
                      }
                    }
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
                            builder: (context) =>
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
  }}
