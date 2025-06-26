import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartlib/student/welcomescreen.dart';

import '../data/string.dart';
import '../models/student_model.dart';
import 'notification_service.dart';

class AuthFunctions {
  // Function to check if user exists in database
  static Future<bool> checkUserExists(
    String email,
    String phone,
    BuildContext context,
  ) async {
    final DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
    final String basePath = SmartLib.constPath;
    final String normalizedEmail = email.trim();
    final String normalizedPhone = phone.trim();

    // Define user types to check
    final List<String> userTypes = ['librarian', 'student'];

    // Create all queries to run in parallel
    List<Future<DataSnapshot>> queries = [];

    // Add email queries
    for (String userType in userTypes) {
      queries.add(
        databaseRef
            .child('$basePath/$userType')
            .orderByChild(SmartLib.constEmail)
            .equalTo(normalizedEmail)
            .once()
            .then((result) => result.snapshot),
      );
    }

    // Add phone queries
    for (String userType in userTypes) {
      queries.add(
        databaseRef
            .child('$basePath/$userType')
            .orderByChild(SmartLib.constPhone)
            .equalTo(normalizedPhone)
            .once()
            .then((result) => result.snapshot),
      );
    }

    // Execute all queries in parallel
    final List<DataSnapshot> results = await Future.wait(queries);

    // Check for email existence (first half of results)
    for (int i = 0; i < userTypes.length; i++) {
      if (results[i].exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email already in use by a ${userTypes[i]}. Please use a different email.',
            ),
          ),
        );
        return true;
      }
    }

    // Check for phone existence (second half of results)
    for (int i = 0; i < userTypes.length; i++) {
      final int resultIndex = i + userTypes.length;
      if (results[resultIndex].exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phone number already in use by a ${userTypes[i]}. Please use a different number.',
            ),
          ),
        );
        return true;
      }
    }

    return false; // User doesn't exist in either path
  }

  // Function to sign up with phone number
  static Future<Map<String, dynamic>> signUpWithPhone(
    String phoneNumber,
    BuildContext context,
    Function(bool) setLoading,
    Function(String, bool, int) onCodeSent,
  ) async {
    setLoading(true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: "+91$phoneNumber",
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval or instant verification
          await FirebaseAuth.instance.signInWithCredential(credential);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phone verification complete!')),
          );

          setLoading(false);
          onCodeSent("", true, 2); // Move directly to profile setup
        },

        verificationFailed: (FirebaseAuthException e) {
          setLoading(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phone verification failed: ${e.message}')),
          );
        },

        codeSent: (String verificationId, int? resendToken) {
          setLoading(false);
          onCodeSent(verificationId, true, 1); // Move to OTP step
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OTP sent to your phone.')));
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          setLoading(false);
        },
      );
      return {"success": true};
    } catch (e) {
      setLoading(false);
      return {"success": false, "error": e.toString()};
    }
  }

  // Function to verify OTP
  static Future<bool> verifyOtp(
    String verificationId,
    String otp,
    String email,
    String password,
    BuildContext context,
    Function(bool) setLoading,
    Function(bool, int) onSuccess,
  ) async {
    if (otp.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return false;
    }

    setLoading(true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OTP verification successful')));
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      setLoading(false);
      onSuccess(true, 2); // Move to profile setup step

      return true;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP verification failed: ${e.message}')),
      );
      return false;
    }
  }

  // Function to save user profile and return librarian ID
  static Future<String> finishLibrarianProfile(
    BuildContext context,
    Function(bool) setLoading,
    String email,
    String phone,
    String fullName,
    String gender,
    File? profileImage, {
    String? panId,
    String? gstNumber,
    String? experience,
  }) async {
    setLoading(true);
    String librarianId =
        ""; // Initialize userId here to ensure scope across all code paths

    try {
      // Check for authenticated user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("No authenticated user found");
      }

      // Generate unique librarian ID with "L" prefix
      librarianId = "L${DateTime.now().millisecondsSinceEpoch}";
      String authId = currentUser.uid;
      String? profileImageUrl;

      // Upload profile image if selected
      if (profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(
              '${librarianId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );

        await storageRef.putFile(profileImage);
        profileImageUrl = await storageRef.getDownloadURL();
      }

      // Save to Realtime Database - matching the required structure
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child(
        '${SmartLib.constPath}/librarians/$librarianId',
      );

      // Build user data map with required fields
      Map<String, dynamic> userData = {
        'authId': authId,
        'email': email.trim(),
        'phone': phone.trim(),
        'fullName': fullName.trim(),
        'gender': gender,
        'profileCompleted': true,
        //'managedLibraries': [],  // Initially empty array
      };

      // Add optional fields if provided
      if (profileImageUrl != null) {
        userData['profileImage'] = profileImageUrl;
      }

      if (panId != null) {
        userData['panId'] = panId;
      }

      if (gstNumber != null && gstNumber.isNotEmpty) {
        userData['gstNumber'] = gstNumber;
      }

      if (experience != null && experience.isNotEmpty) {
        userData['experience'] = experience;
      }

      // Save the complete user data to Firebase
      await userRef.set(userData);
      SmartLib.userId = librarianId;
      SmartLib.userType = "librarian";

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile setup successful!')),
      );

      setLoading(false);

      return librarianId; // Return the librarian ID
    } catch (e) {
      setLoading(false);

      // Log error for debugging
      print('Error in finishLibrarianProfile: $e');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));

      return ""; // Return empty string on error
    }
  }

  // Updated function to save user profile

  static Future<bool> finishStudentProfile(
    BuildContext context,
    Function(bool) setLoading,
    String email,
    String phone,
    String department,
    String username,
    String fullName,
    String gender,
    DateTime dateOfBirth,
    bool locationPermissionGranted,
    File? profileImage,
  ) async {
    setLoading(true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("No authenticated user found");
      }

      String authId = currentUser.uid;
      String studentId = "S${DateTime.now().millisecondsSinceEpoch}";
      String? profileImageUrl;

      // Upload profile image if selected
      if (profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${studentId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(profileImage);
        profileImageUrl = await storageRef.getDownloadURL();
      }

      final student = StudentModel(
        studentId: studentId,
        authId: authId,
        email: email.trim(),
        phone: phone.trim(),
        department: department.trim(),
        username: username.trim(),
        fullName: fullName.trim(),
        gender: gender,
        dateOfBirth:
            '${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}',
        hasLocationPermission: locationPermissionGranted,
        profileImageUrl: profileImageUrl,
        profileCompleted: true,
        bookingHistory: [],
      );

      DatabaseReference userRef = FirebaseDatabase.instance.ref().child(
        '${SmartLib.constPath}/students/$studentId',
      );

      await userRef.set(student.toJson());
      SmartLib.userId = studentId;
      SmartLib.userType = "student";

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile setup successful!')));
      setLoading(false);

      return true;
    } catch (e) {
      setLoading(false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      return false;
    }
  }

  static Future<List<String>> getCurrentLocation(
    BuildContext context,
    Function(bool) setLoading,
  ) async {
    setLoading(true);
    String locationLatitude = "";
    String locationLongitude = "";

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Consider opening location settings instead of just failing
        await Geolocator.openLocationSettings();
        throw 'Location services are disabled';
      }

      // Request permission with proper flow
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Consider opening app settings to let user enable permissions
        await Geolocator.openAppSettings();
        throw 'Location permissions are permanently denied';
      }

      // Get current position with improved accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Update library model with coordinates
      locationLatitude = position.latitude.toString();
      locationLongitude = position.longitude.toString();
      setLoading(false);

      /* setState(() {
        _locationObtained = true;
        _isLoading = false;
      });*/

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location successfully captured!"),
          duration: Duration(seconds: 2),
        ),
      );

      return [locationLatitude, locationLongitude];
    } catch (e) {
      setLoading(false);

      // More informative error message with action
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error accessing location: ${e.toString()}"),
          duration: Duration(seconds: 5),
        ),
      );

      return [locationLatitude, locationLongitude];
    }
  }

  // Function to pick image
  static Future<File?> pickImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      return null;
    }
  }

  Future<void> userLogout(BuildContext context) async {
    try {
      // Remove FCM token to stop receiving notifications

      // Clear session data
      await AuthService.clearUserSession();

      // Reset SmartLib userId
      SmartLib.userId = "";

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged out successfully'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // Handle any errors during logout
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during logout: ${e.toString()}'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // Reset loading state if still in this component
    }
  }
}

class AuthService {
  static const String USER_ID_KEY = 'userId';
  static const String USER_ROLE_KEY = 'userRole';

  // Save user session data
  static Future<void> saveUserSession(String userId, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(USER_ID_KEY, userId);
    await prefs.setString(USER_ROLE_KEY, role);
  }

  // Get current user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_ID_KEY);
  }

  // Get current user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_ROLE_KEY);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final userId = await getUserId();
    return userId != null;
  }

  // Add this method to your AuthService class
  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('userRole');
      await prefs.remove('isLoggedIn');

      // Clear any other session-related data you might be storing
      // For example:
      // await prefs.remove('userName');
      // await prefs.remove('userEmail');
    } catch (e) {
      print('Error clearing user session: $e');
      throw e;
    }
  }
}
