// services/review_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review_model.dart';
import '../data/string.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Check if user can review a library (joined > 15 days ago & hasn't reviewed yet)
  Future<bool> canReviewLibrary(String libraryId) async {
    try {
      final userId = SmartLib.userId;

      // Check when user joined this library
      final joinedSnapshot = await _database
          .ref('${SmartLib.constPath}/students/$userId/joinedLibraries/$libraryId')
          .get();

      if (!joinedSnapshot.exists) return false;

      // Parse join date
      String? joinedAtString;
      if (joinedSnapshot.value is Map) {
        final data = joinedSnapshot.value as Map<dynamic, dynamic>;
        joinedAtString = data['joinedAt']?.toString();
      } else if (joinedSnapshot.value is String) {
        joinedAtString = joinedSnapshot.value.toString();
      }

      if (joinedAtString == null) return false;

      DateTime joinedAt;
      try {
        joinedAt = DateTime.parse(joinedAtString);
      } catch (e) {
        // If can't parse date, use current time minus 16 days (to allow review)
        joinedAt = DateTime.now().subtract(Duration(days: 16));
      }

      // Check if 15 days have passed since joining
      final fifteenDaysAgo = DateTime.now().subtract(Duration(days: 15));
      if (joinedAt.isAfter(fifteenDaysAgo)) {
        return false; // Not eligible yet
      }

      // Check if user has already reviewed this library
      final reviewQuery = await _firestore
          .collection('reviews')
          .where('libraryId', isEqualTo: libraryId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      return reviewQuery.docs.isEmpty; // Can review if no existing review
    } catch (e) {
      print('Error checking review eligibility: $e');
      return false;
    }
  }

  // Submit a new review
  Future<bool> submitReview({
    required String libraryId,
    required double rating,
    required String feedback,
  }) async {
    try {
      final userId = SmartLib.userId;
      final userName = SmartLib.studentName;

      // Get user photo URL if available
      String? photoUrl;
      try {
        final userSnapshot = await _database
            .ref('${SmartLib.constPath}/students/$userId')
            .get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          photoUrl = userData['profileImageUrl']?.toString() ??
              userData['photoURL']?.toString();
        }
      } catch (e) {
        print('Error fetching user photo: $e');
      }

      // Create review
      final review = ReviewModel(
        id: '', // Firestore will generate
        libraryId: libraryId,
        userId: userId,
        userName: userName,
        rating: rating,
        feedback: feedback,
        createdAt: DateTime.now(),
        userPhotoUrl: photoUrl,
      );

      // Start a batch to update both review and library stats
      final batch = _firestore.batch();

      // Add review document
      final reviewRef = _firestore.collection('reviews').doc();
      batch.set(reviewRef, review.toMap());

      // Update library stats (rating and review count)
      final libraryRef = _firestore.collection('libraries').doc(libraryId);
      final libraryDoc = await libraryRef.get();

      if (libraryDoc.exists) {
        final data = libraryDoc.data()!;
        final currentRating = data['rating'] as double? ?? 0.0;
        final currentReviews = data['reviews'] as int? ?? 0;

        // Calculate new average rating
        final newRating = (currentRating * currentReviews + rating) / (currentReviews + 1);

        batch.update(libraryRef, {
          'rating': newRating,
          'reviews': FieldValue.increment(1),
          'lastReviewAt': DateTime.now().toIso8601String(),
        });
      }

      // Execute batch
      await batch.commit();

      // Mark that user has reviewed this library (to prevent multiple reviews)
      await _database
          .ref('${SmartLib.constPath}/students/$userId/reviewedLibraries/$libraryId')
          .set(DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }

  // Fetch reviews for a library
  Future<List<ReviewModel>> getLibraryReviews(String libraryId, {int limit = 10}) async {
    try {
      final reviewsQuery = await _firestore
          .collection('reviews')
          .where('libraryId', isEqualTo: libraryId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return reviewsQuery.docs
          .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching library reviews: $e');
      return [];
    }
  }

  // Check for libraries eligible for review
  Future<List<Map<String, dynamic>>> getLibrariesEligibleForReview() async {
    try {
      final userId = SmartLib.userId;
      final eligibleLibraries = <Map<String, dynamic>>[];

      // Get joined libraries
      final joinedSnapshot = await _database
          .ref('${SmartLib.constPath}/students/$userId/joinedLibraries')
          .get();

      if (!joinedSnapshot.exists) return [];

      final joinedMap = joinedSnapshot.value as Map<dynamic, dynamic>;

      // Check each library
      for (var entry in joinedMap.entries) {
        final libraryId = entry.key.toString();

        // Parse join date
        String? joinedAtString;
        if (entry.value is Map) {
          final data = entry.value as Map<dynamic, dynamic>;
          joinedAtString = data['joinedAt']?.toString();
        } else if (entry.value is String) {
          joinedAtString = entry.value.toString();
        }

        if (joinedAtString == null) continue;

        DateTime joinedAt;
        try {
          joinedAt = DateTime.parse(joinedAtString);
        } catch (e) {
          continue;
        }

        // Check if 15 days have passed
        final fifteenDaysAgo = DateTime.now().subtract(Duration(days: 15));
        if (joinedAt.isAfter(fifteenDaysAgo)) {
          continue; // Not eligible yet
        }

        // Check if already reviewed
        final alreadyReviewedSnapshot = await _database
            .ref('${SmartLib.constPath}/students/$userId/reviewedLibraries/$libraryId')
            .get();

        if (alreadyReviewedSnapshot.exists) continue;

        // Get library details
        try {
          final libraryDoc = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .get();

          if (libraryDoc.exists) {
            final libraryData = libraryDoc.data()!;
            eligibleLibraries.add({
              'id': libraryId,
              'name': libraryData['libraryName'] ?? 'Unknown Library',
              'imageUrl': libraryData['libraryImageUrl'],
              'joinedAt': joinedAt,
            });
          }
        } catch (e) {
          print('Error fetching library details: $e');
        }
      }

      return eligibleLibraries;
    } catch (e) {
      print('Error checking for reviewable libraries: $e');
      return [];
    }
  }

}