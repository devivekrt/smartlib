import 'dart:async';
import 'dart:core';
import 'dart:core';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartlib/data/string.dart';
import 'package:smartlib/student/select_page.dart';
import 'package:smartlib/student/welcomescreen.dart';
import '../function/listen_data.dart';
import '../function/review_service.dart';
import '../function/student_function.dart';
import '../librarian/bottom_navigation/librarain_navigation_page.dart';
import 'main_tab_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
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
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_logoAnimationController);

    // Logo opacity animation
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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

      // Initialize SmartLib data based on role
      if (userId != null && userRole != null) {
        if (userRole == 'student') {
          SmartLib.userId = userId;
          SmartLib.studentId = userId;
          SmartLib.userType = 'student';
        } else if (userRole == 'librarian') {
          SmartLib.userId = userId;
          SmartLib.librarianId = userId;
          SmartLib.userType = 'librarian';
        } else {
          SmartLib.userId = userId;
        }

        // Try to preload some user data if we have network connection
        try {


          // Initialize the data listener service
          final listenData = ListenData();

          // Pre-load user data
          await listenData.getUserData();
        } catch (e) {
          // Non-critical error - we can continue even if data preload fails
        }

        // Verify user still exists in the database
        try {
          // Set appropriate database path based on user role
          String userPath;
          if (userRole == 'student') {
            userPath = "${SmartLib.constPath}/students/$userId";
          } else if (userRole == 'librarian') {
            userPath = "${SmartLib.constPath}/librarians/$userId";
          } else {
            throw Exception("Invalid user role: $userRole");
          }

          // Check if user exists in database
          DatabaseEvent userSnapshot = await FirebaseDatabase.instance
              .ref()
              .child(userPath)
              .once()
              .timeout(const Duration(seconds: 5));

          if (!userSnapshot.snapshot.exists) {
            await AuthService.clearUserSession();
            _navigateToWelcomeScreen();
            return;
          }

          // User exists and is active, navigate to appropriate screen
          if (userRole == 'student') {
            _navigateToStudentHome();
          } else if (userRole == 'librarian') {
            _navigateToLibrarianHome();
          }

          return;
        } catch (e) {
          // If it's specifically a timeout error, we might want to proceed anyway
          // but show a connectivity warning
          if (e is TimeoutException) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Network is slow. Some features may be limited."),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.orange,
              ),
            );

            return;
          }
        }
      }

      // If we get here, either:
      // - User is not logged in
      // - Session is invalid
      // - Role is unknown
      // - Other authentication error occurred
      _navigateToWelcomeScreen();
    } catch (e) {
      _navigateToWelcomeScreen();
    } finally {}
  }

  // Helper method for welcome screen navigation
  void _navigateToWelcomeScreen() async {
    await _backgroundAnimationController.forward();

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

  // Helper method for student home navigation
  void _navigateToStudentHome() async {
    await _backgroundAnimationController.forward();

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
  }

  // Helper method for librarian home navigation
  void _navigateToLibrarianHome() async {
    await _backgroundAnimationController.forward();

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
