import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:smartlib/logic/string.dart';
import 'package:smartlib/user-pages/select_page.dart';
import 'package:smartlib/widgets/solid_button.dart';

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

  Future<bool> _userLogin() async {
    // Check if email and password fields are not empty
    if (_emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty) {
      try {
        // Query users by email
        final usersSnapshot =
            await databaseRef
                .child(SmartLib.constPath)
                .orderByChild(SmartLib.constEmail)
                .equalTo(_emailController.text.trim())
                .once();

        // Check if we found a user with this email
        if (usersSnapshot.snapshot.exists) {
          // Get the first user that matches (emails should be unique)
          final userMap = Map<String, dynamic>.from(
            usersSnapshot.snapshot.value as Map,
          );

          final userId = userMap.keys.first;
          final userData = userMap[userId];

          // Check if password matches
          if (userData['password'] == _passwordController.text.trim()) {
            // Login successful
            SmartLib.email = _emailController.text.trim();
            // You might want to store the userId as well
            // SmartLib.userId = userId;
            print('Login successful');
            return true;
          } else {
            // Password doesn't match
            print('Incorrect password');
            return false;
          }
        } else {
          // No user found with this email
          print('No account found with this email');
          return false;
        }
      } catch (e) {
        print('Error during login: $e');
        return false;
      }
    } else {
      // Email or password field is empty
      print('Please enter email and password');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Welcome back, LibTrack provides right place to Study and manage catalogs",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue),
                ),
                width: width,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      InputField(
                        controller: _emailController,
                        labelText: 'Email',
                        prefixIcon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
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
                    ],
                  ),
                ),
              ),
              SolidButton(text: "Login", onPressed: _userLogin,width: width,),

              Row(
                children: [
                  Text(
                    "Don't have a account ?",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SelectPage()),
                      );
                    },
                    child: Text("SignUp"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
