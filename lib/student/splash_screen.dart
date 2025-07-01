// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-29 15:10:55
// Current User's Login: devivekrti

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartlib/data/string.dart';
import 'package:smartlib/student/select_page.dart';
import 'package:smartlib/student/welcomescreen.dart';
import '../function/review_service.dart';
import '../function/student_function.dart';
import '../librarian/bottom_navigation/librarain_navigation_page.dart';
import 'main_tab_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _logoAnimationController;
  late AnimationController _backgroundAnimationController;

  // Animations
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _backgroundOpacityAnimation;

  // Timer for auto navigation
  Timer? _navigationTimer;
  bool _isNavigating = false;


  @override
  void initState() {
    super.initState();
    // Initialize animations
    _initializeAnimations();

    // Start animations
    _startAnimations();

    // Check authentication after splash animation
    _navigationTimer = Timer(Duration(milliseconds: 2500), () {
      if (mounted && !_isNavigating) {
        _checkLoginStatus();
      }
    });
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    // Logo scale animation
    _logoScaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 30,
      ),
    ]).animate(_logoAnimationController);

    // Logo opacity animation
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Background animation controller
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    // Background opacity animation
    _backgroundOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_backgroundAnimationController);
  }

  void _startAnimations() {
    // Start logo animation
    _logoAnimationController.forward();
  }


  Future<void> _checkLoginStatus() async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {

      // Check for existing user authentication
      String? userId = await AuthService.getUserId();
      String? userRole = await AuthService.getUserRole();
      if (userId != null) {
        SmartLib.userId = userId;
      }
      print("User ID: $userId, User Role: $userRole");

      // If user is authenticated, verify they still exist in database
      if (userId != null && userRole != null) {
        try {
          DatabaseEvent userSnapshot = await FirebaseDatabase.instance
              .ref()
              .child("${SmartLib.constStudentPath}/$userId")
              .once()
              .timeout(const Duration(seconds: 5));

          if (userSnapshot.snapshot.exists) {
            // User exists, navigate to appropriate home page
            // Start exit animation
            await _backgroundAnimationController.forward();

            if (userRole == 'student') {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => MainTabScreen(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: Duration(milliseconds: 500),
                ),
              );
            } else if (userRole == 'librarian') {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => LibrarianNavigationPage(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: Duration(milliseconds: 500),
                ),
              );
            }

            return;
          }
        } catch (e) {
          // Handle database timeout or other errors
          print("Database error: $e");
        }
      }

      // Start exit animation
      await _backgroundAnimationController.forward();

      // If we get here, user is not logged in or session is invalid
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => WelcomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      print("Error during login check: $e");

      // Start exit animation
      await _backgroundAnimationController.forward();

      // Navigate to selection page on any error
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => WelcomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _logoAnimationController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF010E20), // Dark blue background
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoAnimationController,
          _backgroundAnimationController,
        ]),
        builder: (context, child) {
          return FadeTransition(
            opacity: _backgroundOpacityAnimation,
            child: Center(
              child: FadeTransition(
                opacity: _logoOpacityAnimation,
                child: ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo image
                      Image.asset(
                        'assets/libtrack_logo.webp', // Make sure this is the path to your logo
                        width: double.infinity,
                      ),


                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}