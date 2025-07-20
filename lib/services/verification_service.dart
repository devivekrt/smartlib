// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/library_model.dart';
import '../models/verification_model.dart';

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get all pending libraries for verification
  Stream<List<LibraryModel>> getPendingLibraries() {
    return _firestore
        .collection('libraries')
        .where('verificationStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LibraryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get libraries in review by admin
  Stream<List<LibraryModel>> getLibrariesInReview(String adminId) {
    return _firestore
        .collection('libraries')
        .where('verificationStatus', isEqualTo: 'in_review')
        .where('verificationAdminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LibraryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Start verification process for a library
  Future<VerificationModel> startVerification(String libraryId, String adminId) async {
    final verificationId = "VER_${DateTime.now().millisecondsSinceEpoch}";
    
    final verification = VerificationModel(
      id: verificationId,
      libraryId: libraryId,
      adminId: adminId,
      status: VerificationStatus.inReview,
      currentStep: VerificationStep.introduction,
      submittedAt: DateTime.now(),
      reviewStartedAt: DateTime.now(),
    );

    // Update library status to in_review
    await _firestore.collection('libraries').doc(libraryId).update({
      'verificationStatus': 'in_review',
      'verificationAdminId': adminId,
    });

    // Create verification document
    await _firestore
        .collection('library_verifications')
        .doc(verificationId)
        .set(verification.toMap());

    return verification;
  }

  /// Get verification data for a library
  Future<VerificationModel?> getVerification(String libraryId) async {
    final snapshot = await _firestore
        .collection('library_verifications')
        .where('libraryId', isEqualTo: libraryId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return VerificationModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    return null;
  }

  /// Update verification step
  Future<void> updateVerificationStep(String verificationId, VerificationStep step) async {
    await _firestore.collection('library_verifications').doc(verificationId).update({
      'currentStep': step.toString().split('.').last,
    });
  }

  /// Verify location within 50 meters
  Future<LocationVerification> verifyLocation(
    double submittedLat,
    double submittedLon,
  ) async {
    // Get current location
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Calculate distance between submitted and current location
    double distance = Geolocator.distanceBetween(
      submittedLat,
      submittedLon,
      position.latitude,
      position.longitude,
    );

    return LocationVerification(
      submittedLatitude: submittedLat,
      submittedLongitude: submittedLon,
      verifiedLatitude: position.latitude,
      verifiedLongitude: position.longitude,
      distance: distance,
      isWithinRange: distance <= 50.0, // Within 50 meters
      accuracy: position.accuracy,
      verifiedAt: DateTime.now(),
    );
  }

  /// Save location verification
  Future<void> saveLocationVerification(
    String verificationId,
    LocationVerification locationVerification,
  ) async {
    await _firestore.collection('library_verifications').doc(verificationId).update({
      'locationVerification': locationVerification.toMap(),
    });
  }

  /// Upload and compress verification images
  Future<List<String>> uploadVerificationImages(
    String libraryId,
    List<File> imageFiles,
  ) async {
    List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      File imageFile = imageFiles[i];
      
      // Compress image to under 100KB (using existing logic)
      final imageSize = await imageFile.length();
      if (imageSize > 100 * 1024) {
        final compressedImage = await _compressImage(imageFile);
        if (compressedImage != null) {
          imageFile = compressedImage;
        } else {
          throw Exception('Failed to compress image ${i + 1} to under 100KB');
        }
      }

      // Upload to Firebase Storage
      final fileName = 'verification_images/${libraryId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final storageRef = _storage.ref().child(fileName);
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();
      uploadedUrls.add(downloadUrl);
    }

    return uploadedUrls;
  }

  /// Compress image (using existing logic from LibrarySubmissionService)
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 800,
        minHeight: 600,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        final compressedSize = await compressedFile.length();
        
        if (compressedSize <= 100 * 1024) {
          return compressedFile;
        } else {
          // Try with lower quality
          result = await FlutterImageCompress.compressAndGetFile(
            file.absolute.path,
            targetPath,
            quality: 60,
            minWidth: 600,
            minHeight: 400,
          );
          
          if (result != null) {
            return File(result.path);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save image verification
  Future<void> saveImageVerification(
    String verificationId,
    ImageVerification imageVerification,
  ) async {
    await _firestore.collection('library_verifications').doc(verificationId).update({
      'imageVerification': imageVerification.toMap(),
    });
  }

  /// Save seat verification
  Future<void> saveSeatVerification(
    String verificationId,
    SeatVerification seatVerification,
  ) async {
    await _firestore.collection('library_verifications').doc(verificationId).update({
      'seatVerification': seatVerification.toMap(),
    });
  }

  /// Test QR code functionality
  Future<QrVerification> testQrCode(String qrCodeData, String libraryId) async {
    List<QrTestResult> testResults = [];
    
    try {
      // Test check-in functionality
      bool checkInSuccess = await _testQrAction(qrCodeData, libraryId, 'check_in');
      testResults.add(QrTestResult(
        action: 'check_in',
        success: checkInSuccess,
        errorMessage: checkInSuccess ? null : 'Check-in test failed',
        testedAt: DateTime.now(),
      ));

      // Test check-out functionality
      bool checkOutSuccess = await _testQrAction(qrCodeData, libraryId, 'check_out');
      testResults.add(QrTestResult(
        action: 'check_out',
        success: checkOutSuccess,
        errorMessage: checkOutSuccess ? null : 'Check-out test failed',
        testedAt: DateTime.now(),
      ));

      return QrVerification(
        qrCodeData: qrCodeData,
        isValidQrCode: qrCodeData.isNotEmpty && qrCodeData.contains(libraryId),
        checkInWorks: checkInSuccess,
        checkOutWorks: checkOutSuccess,
        testResults: testResults,
        testedAt: DateTime.now(),
      );
    } catch (e) {
      testResults.add(QrTestResult(
        action: 'test_error',
        success: false,
        errorMessage: e.toString(),
        testedAt: DateTime.now(),
      ));

      return QrVerification(
        qrCodeData: qrCodeData,
        isValidQrCode: false,
        checkInWorks: false,
        checkOutWorks: false,
        testResults: testResults,
        testedAt: DateTime.now(),
      );
    }
  }

  /// Test QR code action (mock implementation)
  Future<bool> _testQrAction(String qrCodeData, String libraryId, String action) async {
    // Mock QR code validation logic
    // In real implementation, this would test actual QR code functionality
    try {
      // Basic validation: QR code should contain library ID
      if (!qrCodeData.contains(libraryId)) {
        return false;
      }

      // Mock API call delay
      await Future.delayed(Duration(milliseconds: 500));
      
      // Mock success (in real implementation, test actual check-in/out)
      return qrCodeData.isNotEmpty && qrCodeData.length > 10;
    } catch (e) {
      return false;
    }
  }

  /// Save QR verification
  Future<void> saveQrVerification(
    String verificationId,
    QrVerification qrVerification,
  ) async {
    await _firestore.collection('library_verifications').doc(verificationId).update({
      'qrVerification': qrVerification.toMap(),
    });
  }

  /// Approve library verification
  Future<void> approveLibrary(String libraryId, String verificationId, String adminNotes) async {
    final batch = _firestore.batch();

    // Update library status to verified (active)
    final libraryRef = _firestore.collection('libraries').doc(libraryId);
    batch.update(libraryRef, {
      'verificationStatus': 'verified',
      'status': 'active',
      'verificationCompletedAt': DateTime.now().toIso8601String(),
    });

    // Update verification status
    final verificationRef = _firestore.collection('library_verifications').doc(verificationId);
    batch.update(verificationRef, {
      'status': VerificationStatus.verified.toString().split('.').last,
      'completedAt': DateTime.now().toIso8601String(),
      'adminNotes': adminNotes,
    });

    await batch.commit();
  }

  /// Reject library verification
  Future<void> rejectLibrary(
    String libraryId,
    String verificationId,
    String rejectionReason,
    String adminNotes,
  ) async {
    final batch = _firestore.batch();

    // Update library status to rejected
    final libraryRef = _firestore.collection('libraries').doc(libraryId);
    batch.update(libraryRef, {
      'verificationStatus': 'rejected',
      'status': 'rejected',
      'rejectionReason': rejectionReason,
      'verificationCompletedAt': DateTime.now().toIso8601String(),
    });

    // Update verification status
    final verificationRef = _firestore.collection('library_verifications').doc(verificationId);
    batch.update(verificationRef, {
      'status': VerificationStatus.rejected.toString().split('.').last,
      'completedAt': DateTime.now().toIso8601String(),
      'rejectionReason': rejectionReason,
      'adminNotes': adminNotes,
    });

    await batch.commit();
  }

  /// Search libraries by name, location, or status
  Future<List<LibraryModel>> searchLibraries(String query, String? status) async {
    Query baseQuery = _firestore.collection('libraries');
    
    if (status != null && status.isNotEmpty) {
      baseQuery = baseQuery.where('verificationStatus', isEqualTo: status);
    }

    // For simple text search, we'll get all and filter in memory
    // In production, consider using Algolia or ElasticSearch for better search
    final snapshot = await baseQuery.get();
    
    final libraries = snapshot.docs
        .map((doc) => LibraryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    if (query.isEmpty) {
      return libraries;
    }

    // Filter by query
    return libraries.where((library) {
      final searchTerm = query.toLowerCase();
      return (library.libraryName?.toLowerCase().contains(searchTerm) ?? false) ||
             (library.location?.toLowerCase().contains(searchTerm) ?? false) ||
             (library.ownerName?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();
  }

  /// Get verification statistics
  Future<Map<String, int>> getVerificationStats() async {
    final pendingSnapshot = await _firestore
        .collection('libraries')
        .where('verificationStatus', isEqualTo: 'pending')
        .get();

    final inReviewSnapshot = await _firestore
        .collection('libraries')
        .where('verificationStatus', isEqualTo: 'in_review')
        .get();

    final verifiedSnapshot = await _firestore
        .collection('libraries')
        .where('verificationStatus', isEqualTo: 'verified')
        .get();

    final rejectedSnapshot = await _firestore
        .collection('libraries')
        .where('verificationStatus', isEqualTo: 'rejected')
        .get();

    return {
      'pending': pendingSnapshot.docs.length,
      'in_review': inReviewSnapshot.docs.length,
      'verified': verifiedSnapshot.docs.length,
      'rejected': rejectedSnapshot.docs.length,
    };
  }
}