import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartlib/user-pages/home_page.dart';
import 'package:smartlib/user-pages/select_page.dart';

import '../function/users_function.dart';
import '../owner-pages/librarian_home_page.dart';
import 'Login.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Add a timeout to the database check to avoid getting stuck
      String? userId = await AuthService.getUserId();
      String? userRole = await AuthService.getUserRole();

      if (userId != null && userRole != null) {
        // Verify the user still exists in database with a timeout
        DatabaseEvent userSnapshot = await FirebaseDatabase.instance
            .ref()
            .child("users/$userRole/$userId")
            .once()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          // If timeout occurs, assume database issue and go to selection page
          throw TimeoutException('Database query timed out');
        });

        if (userSnapshot.snapshot.exists) {
          // User exists, navigate to appropriate home page
          if (mounted) {  // Check if widget is still in the tree before navigation
            if (userRole == 'student') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            } else if (userRole == 'librarian') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LibrarianHomePage()),
              );
            }
          }
          return;
        }
      }

      // If we get here, user is not logged in or session is invalid
      if (mounted) {  // Check if widget is still in the tree
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SelectPage()),
        );
      }
    } catch (e) {
      print("Error during login check: $e");
      // Navigate to selection page on any error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SelectPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Library App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}