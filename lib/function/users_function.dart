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
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
    final snapshot =
        await databaseRef
            .child(SmartLib.constPath)
            .orderByChild(SmartLib.constEmail)
            .equalTo(email.trim())
            .once();

    if (snapshot.snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email already in use. Please try a different email.'),
        ),
      );
      return true;
    }

    // Also check if the phone number already exists
    final phoneSnapshot =
        await databaseRef
            .child(SmartLib.constPath)
            .orderByChild(SmartLib.constPhone)
            .equalTo(phone.trim())
            .once();

    if (phoneSnapshot.snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number already in use. Please try a different number.',
          ),
        ),
      );
      return true;
    }

    return false; // User doesn't exist
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

  // Function to save user profile
  static Future<bool> finishProfileSetup(
    BuildContext context,
    Function(bool) setLoading,
    String email,
    String phone,
    String password,
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
        'password': password.trim(),
        'username': username.trim(),
        'gender': gender,
        'fullName': fullName.trim(),
        'dateOfBirth':
            '${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}',
        'hasLocationPermission': locationPermissionGranted,
        'profileCompleted': true,
        'profileCreatedAt': DateTime.now().toIso8601String(),
        'profileUpdatedAt': DateTime.now().toIso8601String(),
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

      // Update display name in Firebase Auth
      await currentUser.updateDisplayName(
        fullName.isNotEmpty ? fullName.trim() : username.trim(),
      );

      if (profileImageUrl != null) {
        await currentUser.updatePhotoURL(profileImageUrl);
      }

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
