// models/review_model.dart
class ReviewModel {
  final String id;
  final String libraryId;
  final String userId;
  final String userName;
  final double rating;
  final String feedback;
  final DateTime createdAt;
  final String? userPhotoUrl;

  ReviewModel({
    required this.id,
    required this.libraryId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.feedback,
    required this.createdAt,
    this.userPhotoUrl,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'libraryId': libraryId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'feedback': feedback,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Map (from Firebase)
  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      libraryId: map['libraryId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous User',
      rating: (map['rating'] ?? 0.0).toDouble(),
      feedback: map['feedback'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      userPhotoUrl: map['userPhotoUrl'],
    );
  }
}