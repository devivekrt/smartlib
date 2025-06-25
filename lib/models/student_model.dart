class StudentModel {
  final String studentId;
  final String authId;
  final String email;
  final String phone;
  final String department;
  final String username;
  final String fullName;
  final String gender;
  final String dateOfBirth; // formatted as 'dd/MM/yyyy'
  final bool hasLocationPermission;
  final String? latitude;
  final String? longitude;
  final String? profileImageUrl;
  final bool profileCompleted;
  final List bookingHistory;

  StudentModel({
    required this.studentId,
    required this.authId,
    required this.email,
    required this.phone,
    required this.department,
    required this.username,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    required this.hasLocationPermission,
    this.latitude,
    this.longitude,
    this.profileImageUrl,
    this.profileCompleted = true,
    this.bookingHistory = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'authId': authId,
      'email': email,
      'phone': phone,
      'username': username,
      'gender': gender,
      'longitude': longitude,
      'latitude': latitude,
      'fullName': fullName,
      'department': department,
      'dateOfBirth': dateOfBirth,
      'hasLocationPermission': hasLocationPermission,
      'profileCompleted': profileCompleted,
      'bookingHistory': bookingHistory,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    };
  }
}

class LibraryMembership {
  final String libraryId;
  final DateTime joinedAt;
  final String membershipType; // basic, premium
  final DateTime expiresAt;
  final int totalVisits;

  bool get isActive => DateTime.now().isBefore(expiresAt);
  LibraryMembership({
    required this.libraryId,
    required this.joinedAt,
    required this.membershipType,
    required this.expiresAt,
    this.totalVisits = 0,
  });
  Map<String, dynamic> toJson() {
    return {
      'libraryId': libraryId,
      'joinedAt': joinedAt.toIso8601String(),
      'membershipType': membershipType,
      'expiresAt': expiresAt.toIso8601String(),
      'totalVisits': totalVisits,
    };
  }

}
class BookingReference {
  final String bookingId;
  final String libraryId;
  final String seatNo;
  final String date;
  final String shiftId;
  final String status;

  BookingReference({
    required this.bookingId,
    required this.libraryId,
    required this.seatNo,
    required this.date,
    required this.shiftId,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'libraryId': libraryId,
      'seatNo': seatNo,
      'date': date,
      'shiftId': shiftId,
      'status': status,
    };
  }
}
class StudentStatus {
  final bool isCheckedIn;
  final String? currentLibraryId;
  final String? currentSeatId;
  final DateTime? checkInTime;
  final DateTime? expectedCheckOutTime;

  int get remainingMinutes => expectedCheckOutTime?.difference(DateTime.now()).inMinutes ?? 0;
  StudentStatus({
    this.isCheckedIn = false,
    this.currentLibraryId,
    this.currentSeatId,
    this.checkInTime,
    this.expectedCheckOutTime,
  });
  Map<String, dynamic> toJson() {
    return {
      'isCheckedIn': isCheckedIn,
      'currentLibraryId': currentLibraryId,
      'currentSeatId': currentSeatId,
      'checkInTime': checkInTime?.toIso8601String(),
      'expectedCheckOutTime': expectedCheckOutTime?.toIso8601String(),
    };
  }
}

// Booking Model
class BookingModel {
  final String bookingId;
  final String libraryId;
  final String studentId;
  final String seatNo;
  final String shiftId;
  final DateTime date;
  final String status;
  final DateTime bookedAt;
  final DateTime dueDate;
  final String paymentStatus;
  final String? paymentId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? studyHours;

  bool get isActive => status == 'confirmed' && date.isAfter(DateTime.now());
  bool get isCheckedIn => checkInTime != null && checkOutTime == null;
  BookingModel({
    required this.bookingId,
    required this.libraryId,
    required this.studentId,
    required this.seatNo,
    required this.shiftId,
    required this.date,
    required this.status,
    required this.bookedAt,
    required this.dueDate,
    required this.paymentStatus,
    this.paymentId,
    this.checkInTime,
    this.checkOutTime,
    this.studyHours,
  });
  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'libraryId': libraryId,
      'studentId': studentId,
      'seatNo': seatNo,
      'shiftId': shiftId,
      'date': date.toIso8601String(),
      'status': status,
      'bookedAt': bookedAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'paymentStatus': paymentStatus,
      if (paymentId != null) 'paymentId': paymentId,
      if (checkInTime != null) 'checkInTime': checkInTime!.toIso8601String(),
      if (checkOutTime != null) 'checkOutTime': checkOutTime!.toIso8601String(),
      if (studyHours != null) 'duration': studyHours,
    };
  }
}
