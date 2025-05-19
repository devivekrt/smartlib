import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/string.dart';

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
    File? profileImage,
  ) async {
    setLoading(true);
    String userId =
        ""; // Initialize userId here to ensure scope across all code paths

    try {
      // Check for authenticated user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("No authenticated user found");
      }

      // Generate unique librarian ID with "L" prefix
      userId = "L${DateTime.now().millisecondsSinceEpoch}";
      String authId = currentUser.uid;
      String? profileImageUrl;

      // Upload profile image if selected
      if (profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(profileImage);
        profileImageUrl = await storageRef.getDownloadURL();
      }

      // Save all user data to Firebase Database
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child(
        '${SmartLib.constPath}/librarian/$userId',
      );

      // Save all user data in a single map
      Map<String, dynamic> userData = {
        'authId': authId,
        'email': email.trim(),
        'phone': phone.trim(),
        'fullName': fullName.trim(),
        'gender': gender,
        'profileCompleted': true,
      };

      if (profileImageUrl != null) {
        userData['profileImageUrl'] = profileImageUrl;
      }

      // Save the complete user data to Firebase
      await userRef.set(userData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile setup successful!')),
      );

      setLoading(false);

      return userId; // Return the librarian ID
    } catch (e) {
      setLoading(false);

      // Log error for debugging
      print('Error in finishLibrarianProfile: $e');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));

      return userId; // Return whatever userId we have, even if empty
    }
  }

  // Function to save user profile
  static Future<bool> finishStudentProfile(
    BuildContext context,
    Function(bool) setLoading,
    String email,
    String phone,
      String department,
    String username,
    String gender,
    String fullName,
    DateTime dateOfBirth,
    bool locationPermissionGranted,
    File? profileImage, {
    String? manualAddress, // Add this optional parameter
  }) async {
    setLoading(true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("No authenticated user found");
      }

      String authId = currentUser.uid;
      String userId = "S${DateTime.now().millisecondsSinceEpoch}";
      String? profileImageUrl;

      // Upload profile image if selected
      if (profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(profileImage);
        profileImageUrl = await storageRef.getDownloadURL();
      }

      // Save all user data to Firebase Database
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child(
        '${SmartLib.constPath}/student/$userId',
      );

      // Save all user data in a single map
      Map<String, dynamic> userData = {
        'authId': authId,
        'email': email.trim(),
        'phone': phone.trim(),
        'username': username.trim(),
        'gender': gender,
        'fullName': fullName.trim(),
        'department': department.trim(),
        'dateOfBirth':
            '${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}',
        'hasLocationPermission': locationPermissionGranted,
        'profileCompleted': true,
      };

      // Add manual address if provided
      if (manualAddress != null && manualAddress.isNotEmpty) {
        userData['manualAddress'] = manualAddress;
      }

      if (profileImageUrl != null) {
        userData['profileImageUrl'] = profileImageUrl;
      }

      // Save the complete user data to Firebase
      await userRef.set(userData);

      // Show success message
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

  // Function to request location permission
  static Future<bool> requestLocationPermission(BuildContext context) async {
    LocationPermission permission;

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location services are disabled. Please enable them in settings.',
          ),
        ),
      );
      return false;
    }

    // Check for current permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location permission denied.')));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location permissions are permanently denied. Please enable them in app settings.',
          ),
        ),
      );
      return false;
    }
   /* // Get current position
    Position position = await Geolocator.getCurrentPosition();

    // Update library model with coordinates
    widget.libraryModel.locationLatitude = position.latitude.toString();
    widget.libraryModel.locationLongitude = position.longitude.toString();*/

    // If permission is granted
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Location permission granted!')));
    return true;
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
}
