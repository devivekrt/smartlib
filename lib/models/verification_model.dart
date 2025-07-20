// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'dart:io';

/// Verification status enumeration
enum VerificationStatus {
  pending,
  inReview,
  verified,
  rejected,
}

/// Verification step enumeration
enum VerificationStep {
  introduction,
  location,
  images,
  seatAndQr,
  qrValidation,
  finalReview,
}

/// Model for library verification data
class VerificationModel {
  String? id;
  String? libraryId;
  String? adminId;
  VerificationStatus status;
  VerificationStep currentStep;
  DateTime? submittedAt;
  DateTime? reviewStartedAt;
  DateTime? completedAt;
  
  // Location verification
  LocationVerification? locationVerification;
  
  // Image verification
  ImageVerification? imageVerification;
  
  // Seat and QR verification
  SeatVerification? seatVerification;
  
  // QR code verification
  QrVerification? qrVerification;
  
  // Admin decision
  String? rejectionReason;
  String? adminNotes;

  VerificationModel({
    this.id,
    this.libraryId,
    this.adminId,
    this.status = VerificationStatus.pending,
    this.currentStep = VerificationStep.introduction,
    this.submittedAt,
    this.reviewStartedAt,
    this.completedAt,
    this.locationVerification,
    this.imageVerification,
    this.seatVerification,
    this.qrVerification,
    this.rejectionReason,
    this.adminNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'libraryId': libraryId,
      'adminId': adminId,
      'status': status.toString().split('.').last,
      'currentStep': currentStep.toString().split('.').last,
      'submittedAt': submittedAt?.toIso8601String(),
      'reviewStartedAt': reviewStartedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'locationVerification': locationVerification?.toMap(),
      'imageVerification': imageVerification?.toMap(),
      'seatVerification': seatVerification?.toMap(),
      'qrVerification': qrVerification?.toMap(),
      'rejectionReason': rejectionReason,
      'adminNotes': adminNotes,
    };
  }

  factory VerificationModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return VerificationModel(
      id: docId ?? map['id'],
      libraryId: map['libraryId'],
      adminId: map['adminId'],
      status: VerificationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => VerificationStatus.pending,
      ),
      currentStep: VerificationStep.values.firstWhere(
        (e) => e.toString().split('.').last == map['currentStep'],
        orElse: () => VerificationStep.introduction,
      ),
      submittedAt: map['submittedAt'] != null ? DateTime.parse(map['submittedAt']) : null,
      reviewStartedAt: map['reviewStartedAt'] != null ? DateTime.parse(map['reviewStartedAt']) : null,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      locationVerification: map['locationVerification'] != null 
          ? LocationVerification.fromMap(map['locationVerification']) 
          : null,
      imageVerification: map['imageVerification'] != null 
          ? ImageVerification.fromMap(map['imageVerification']) 
          : null,
      seatVerification: map['seatVerification'] != null 
          ? SeatVerification.fromMap(map['seatVerification']) 
          : null,
      qrVerification: map['qrVerification'] != null 
          ? QrVerification.fromMap(map['qrVerification']) 
          : null,
      rejectionReason: map['rejectionReason'],
      adminNotes: map['adminNotes'],
    );
  }
}

/// Location verification model
class LocationVerification {
  double? submittedLatitude;
  double? submittedLongitude;
  double? verifiedLatitude;
  double? verifiedLongitude;
  double? distance; // Distance in meters
  bool isWithinRange; // Within 50 meters
  double accuracy; // GPS accuracy
  DateTime? verifiedAt;

  LocationVerification({
    this.submittedLatitude,
    this.submittedLongitude,
    this.verifiedLatitude,
    this.verifiedLongitude,
    this.distance,
    this.isWithinRange = false,
    this.accuracy = 0.0,
    this.verifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'submittedLatitude': submittedLatitude,
      'submittedLongitude': submittedLongitude,
      'verifiedLatitude': verifiedLatitude,
      'verifiedLongitude': verifiedLongitude,
      'distance': distance,
      'isWithinRange': isWithinRange,
      'accuracy': accuracy,
      'verifiedAt': verifiedAt?.toIso8601String(),
    };
  }

  factory LocationVerification.fromMap(Map<String, dynamic> map) {
    return LocationVerification(
      submittedLatitude: map['submittedLatitude']?.toDouble(),
      submittedLongitude: map['submittedLongitude']?.toDouble(),
      verifiedLatitude: map['verifiedLatitude']?.toDouble(),
      verifiedLongitude: map['verifiedLongitude']?.toDouble(),
      distance: map['distance']?.toDouble(),
      isWithinRange: map['isWithinRange'] ?? false,
      accuracy: map['accuracy']?.toDouble() ?? 0.0,
      verifiedAt: map['verifiedAt'] != null ? DateTime.parse(map['verifiedAt']) : null,
    );
  }
}

/// Image verification model
class ImageVerification {
  List<String> uploadedImageUrls;
  int requiredMinImages;
  int requiredMaxImages;
  bool isValidCount;
  List<ImageValidation> imageValidations;
  DateTime? uploadedAt;

  ImageVerification({
    this.uploadedImageUrls = const [],
    this.requiredMinImages = 3,
    this.requiredMaxImages = 5,
    this.isValidCount = false,
    this.imageValidations = const [],
    this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uploadedImageUrls': uploadedImageUrls,
      'requiredMinImages': requiredMinImages,
      'requiredMaxImages': requiredMaxImages,
      'isValidCount': isValidCount,
      'imageValidations': imageValidations.map((e) => e.toMap()).toList(),
      'uploadedAt': uploadedAt?.toIso8601String(),
    };
  }

  factory ImageVerification.fromMap(Map<String, dynamic> map) {
    return ImageVerification(
      uploadedImageUrls: List<String>.from(map['uploadedImageUrls'] ?? []),
      requiredMinImages: map['requiredMinImages'] ?? 3,
      requiredMaxImages: map['requiredMaxImages'] ?? 5,
      isValidCount: map['isValidCount'] ?? false,
      imageValidations: (map['imageValidations'] as List?)
          ?.map((e) => ImageValidation.fromMap(e))
          .toList() ?? [],
      uploadedAt: map['uploadedAt'] != null ? DateTime.parse(map['uploadedAt']) : null,
    );
  }
}

/// Individual image validation
class ImageValidation {
  String imageUrl;
  bool isIndoor;
  bool showsLibraryInterior;
  int sizeKb;
  String? rejectionReason;

  ImageValidation({
    required this.imageUrl,
    this.isIndoor = false,
    this.showsLibraryInterior = false,
    this.sizeKb = 0,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'isIndoor': isIndoor,
      'showsLibraryInterior': showsLibraryInterior,
      'sizeKb': sizeKb,
      'rejectionReason': rejectionReason,
    };
  }

  factory ImageValidation.fromMap(Map<String, dynamic> map) {
    return ImageValidation(
      imageUrl: map['imageUrl'],
      isIndoor: map['isIndoor'] ?? false,
      showsLibraryInterior: map['showsLibraryInterior'] ?? false,
      sizeKb: map['sizeKb'] ?? 0,
      rejectionReason: map['rejectionReason'],
    );
  }
}

/// Seat verification model
class SeatVerification {
  int submittedTotalSeats;
  int verifiedTotalSeats;
  List<String> seatNumbers;
  bool seatArrangementMatches;
  String? seatArrangementNotes;
  DateTime? verifiedAt;

  SeatVerification({
    required this.submittedTotalSeats,
    required this.verifiedTotalSeats,
    this.seatNumbers = const [],
    this.seatArrangementMatches = false,
    this.seatArrangementNotes,
    this.verifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'submittedTotalSeats': submittedTotalSeats,
      'verifiedTotalSeats': verifiedTotalSeats,
      'seatNumbers': seatNumbers,
      'seatArrangementMatches': seatArrangementMatches,
      'seatArrangementNotes': seatArrangementNotes,
      'verifiedAt': verifiedAt?.toIso8601String(),
    };
  }

  factory SeatVerification.fromMap(Map<String, dynamic> map) {
    return SeatVerification(
      submittedTotalSeats: map['submittedTotalSeats'],
      verifiedTotalSeats: map['verifiedTotalSeats'],
      seatNumbers: List<String>.from(map['seatNumbers'] ?? []),
      seatArrangementMatches: map['seatArrangementMatches'] ?? false,
      seatArrangementNotes: map['seatArrangementNotes'],
      verifiedAt: map['verifiedAt'] != null ? DateTime.parse(map['verifiedAt']) : null,
    );
  }
}

/// QR verification model
class QrVerification {
  String? qrCodeData;
  bool isValidQrCode;
  bool checkInWorks;
  bool checkOutWorks;
  List<QrTestResult> testResults;
  DateTime? testedAt;

  QrVerification({
    this.qrCodeData,
    this.isValidQrCode = false,
    this.checkInWorks = false,
    this.checkOutWorks = false,
    this.testResults = const [],
    this.testedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'qrCodeData': qrCodeData,
      'isValidQrCode': isValidQrCode,
      'checkInWorks': checkInWorks,
      'checkOutWorks': checkOutWorks,
      'testResults': testResults.map((e) => e.toMap()).toList(),
      'testedAt': testedAt?.toIso8601String(),
    };
  }

  factory QrVerification.fromMap(Map<String, dynamic> map) {
    return QrVerification(
      qrCodeData: map['qrCodeData'],
      isValidQrCode: map['isValidQrCode'] ?? false,
      checkInWorks: map['checkInWorks'] ?? false,
      checkOutWorks: map['checkOutWorks'] ?? false,
      testResults: (map['testResults'] as List?)
          ?.map((e) => QrTestResult.fromMap(e))
          .toList() ?? [],
      testedAt: map['testedAt'] != null ? DateTime.parse(map['testedAt']) : null,
    );
  }
}

/// QR test result model
class QrTestResult {
  String action; // 'check_in' or 'check_out'
  bool success;
  String? errorMessage;
  DateTime testedAt;

  QrTestResult({
    required this.action,
    required this.success,
    this.errorMessage,
    required this.testedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'success': success,
      'errorMessage': errorMessage,
      'testedAt': testedAt.toIso8601String(),
    };
  }

  factory QrTestResult.fromMap(Map<String, dynamic> map) {
    return QrTestResult(
      action: map['action'],
      success: map['success'],
      errorMessage: map['errorMessage'],
      testedAt: DateTime.parse(map['testedAt']),
    );
  }
}