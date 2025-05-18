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
        bool isAuthenticated = false;
        String userRole = "";

        // Try to authenticate as student
        DatabaseEvent studentSnapshot =
            await databaseRef
                .child("${SmartLib.constPath}/student")
                .orderByChild(SmartLib.constEmail)
                .equalTo(_emailController.text.trim())
                .once();

        if (studentSnapshot.snapshot.exists) {
          // Get the user data
          Map<dynamic, dynamic>? users = studentSnapshot.snapshot.value as Map?;
          if (users != null) {
            // Find the user with matching email
            String userId = users.keys.first.toString();
            Map<dynamic, dynamic> userData = users[userId] as Map;

            // Check password
            if (userData[SmartLib.constPassword] ==
                _passwordController.text.trim()) {
              isAuthenticated = true;
              userRole = 'student';
              SmartLib.email = _emailController.text.trim();
              // You might want to store user ID too
              SmartLib.userId = userId;
            }
          }
        }

        // If not authenticated as student, try librarian
        if (!isAuthenticated) {
          DatabaseEvent librarianSnapshot =
              await databaseRef
                  .child("${SmartLib.constPath}/librarian")
                  .orderByChild(SmartLib.constEmail)
                  .equalTo(_emailController.text.trim())
                  .once();

          if (librarianSnapshot.snapshot.exists) {
            // Get the user data
            Map<dynamic, dynamic>? users =
                librarianSnapshot.snapshot.value as Map?;
            if (users != null) {
              // Find the user with matching email
              String userId = users.keys.first.toString();
              Map<dynamic, dynamic> userData = users[userId] as Map;

              // Check password
              if (userData[SmartLib.constPassword] ==
                  _passwordController.text.trim()) {
                isAuthenticated = true;
                userRole = 'librarian';
                SmartLib.email = _emailController.text.trim();
                // You might want to store user ID too
                SmartLib.userId = userId;
              }
            }
          }
        }

        // Handle authentication result
        if (isAuthenticated) {
          // Save session data
          await AuthService.saveUserSession(SmartLib.userId, userRole);

          // Navigate to appropriate screen based on role
          if (userRole == 'student') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MarketPlace(isSignedUp: false),
              ),
            );
          } else if (userRole == 'librarian') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Login Successfully!')));
          setState(() {
            _isLoading = false;
          });
        } else {
          // No match found or password incorrect
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Invalid email or password')));
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login error: Please try again.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return SafeArea(
      child:
          _isLoading == true
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      "Logging User...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
              : Scaffold(
                appBar: AppBar(
                  title: Text("Login"),
                  centerTitle: true,
                  elevation: 0,
                ),
                body: Padding(
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

                        // Password Field - Using InputField widget
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
                        ),
                        SizedBox(height: 40),

                        // Sign Up Button - Using SolidButton widget
                        SolidButton(
                          text: "Login",
                          width: double.infinity,
                          height: 50,
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _userLogin(); // This will start the OTP verification process
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
                                  MaterialPageRoute(
                                    builder: (context) => Login(),
                                  ),
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
                ),
              ),
    );
  }
}
