import 'package:flutter/material.dart';
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
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = true;
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
              SolidButton(text: "Login", onPressed: () {}),

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
