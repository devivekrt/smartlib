// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-29 10:10:32
// Current User's Login: devivekrt

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/widgets/solid_button.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../function/student_location.dart';

// Import the StudentLocationService

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final MobileScannerController _scannerController = MobileScannerController();

  // Use the location service singleton
  final _locationService = StudentLocationService();

  // Firebase instances
  final _firestore = FirebaseFirestore.instance;
  final _database = FirebaseDatabase.instance;

  bool _isProcessingQR = false;
  String _scanMessage = "";
  bool _showSuccess = false;
  bool _showError = false;
  bool _isCheckedIn = false;
  bool _isLoading = true;
  bool _isLocationChecking = false;
  bool _isWithinRange = false;

  // Library location data
  double? _libraryLatitude;
  double? _libraryLongitude;
  String? _libraryName;
  final double _locationCheckRadius = 50.0; // 50 meters radius for check-in

  // Current student details
  final String _studentId = SmartLib.userId;
  final String _studentName = SmartLib.studentName;

  // Variables to store all currentStatus data
  String _currentLibraryId = '';
  String _currentSeatNo = '';
  String _currentBookingId = '';
  String _shiftId = '';
  String _seatNo = '';
  String _shiftStartTime = '';
  String _shiftEndTime = '';
  String _dueDate = '';
  double _fee = 0.0;
  String _paymentStatus = '';
  int _shiftCount = 0;
  String _checkInTime = '';
  String _checkOutTime = '';
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    // Initialize location service and fetch status data
    _initializeAndFetchData();
  }

  // Initialize location service and fetch data
  Future<void> _initializeAndFetchData() async {
    try {
      // Initialize the location service
      await _locationService.initialize();

      // Fetch current status from Firebase
      await _fetchCurrentStatus();

      // Update the UI
      setState(() {
        _isLoading = false;
      });

      print('[2025-06-29 10:10:32] devivekrt: QRScannerScreen initialized successfully');
    } catch (e) {
      print('[2025-06-29 10:10:32] devivekrt: Error initializing QRScannerScreen: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show location error message
  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        )
    );
  }

  // Fetch user's complete current status from Firebase Realtime Database
  Future<void> _fetchCurrentStatus() async {
    try {
      final statusRef = _database.ref().child(
        'users/students/$_studentId/currentStatus',
      );

      final snapshot = await statusRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          // Base check-in status
          _isCheckedIn = data['isCheckedIn'] == true;

          // Library and seat info
          _currentLibraryId = data['currentLibraryId']?.toString() ?? '';
          _seatNo = data['currentSeatNo']?.toString() ?? '';
          _currentBookingId = data['bookingId']?.toString() ?? '';

          // Shift info
          _shiftId = data['shiftId']?.toString() ?? '';
          _shiftStartTime = data['shiftStartTime']?.toString() ?? '';
          _shiftEndTime = data['shiftEndTime']?.toString() ?? '';

          // Payment info
          _dueDate = data['dueDate']?.toString() ?? '';
          _paymentStatus = data['paymentStatus']?.toString() ?? '';

          _streak = (data['streak'] != null)
              ? int.tryParse(data['streak'].toString()) ?? 0
              : 0;

          _checkInTime = data['checkInTime']?.toString() ?? '';
        });

        // If user is checked in or has a current library, fetch the library location
        if (_isCheckedIn || _currentLibraryId.isNotEmpty) {
          await _fetchLibraryLocation(_currentLibraryId);
        }

        print('[2025-06-29 10:10:32] devivekrt: Fetched current status successfully');
      } else {
        print('[2025-06-29 10:10:32] devivekrt: No current status data found');
      }
    } catch (e) {
      print('[2025-06-29 10:10:32] devivekrt: Error fetching current status: $e');
      setState(() {
        _isCheckedIn = false;
      });
    }
  }

  // Fetch library location from Firestore
  Future<void> _fetchLibraryLocation(String libraryId) async {
    try {
      if (libraryId.isEmpty) {
        print('[2025-06-29 10:10:32] devivekrt: Library ID is empty');
        return;
      }

      final libraryDoc = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .get();

      if (libraryDoc.exists) {
        final data = libraryDoc.data();
        if (data != null) {
          // Store library coordinates as doubles for easier calculation
          final latStr = data['locationLatitude']?.toString() ?? '';
          final lngStr = data['locationLongitude']?.toString() ?? '';

          _libraryLatitude = double.tryParse(latStr);
          _libraryLongitude = double.tryParse(lngStr);
          _libraryName = data['libraryName']?.toString() ?? 'Library';

          print('[2025-06-29 10:10:32] devivekrt: Fetched library location: $_libraryLatitude, $_libraryLongitude');

          // Check if student is within range of the library
          await _checkLocationDistance();
        }
      } else {
        print('[2025-06-29 10:10:32] devivekrt: Library document not found');
      }
    } catch (e) {
      print('[2025-06-29 10:10:32] devivekrt: Error fetching library location: $e');
    }
  }

  // Check if student is within range of the library using the location service
  Future<void> _checkLocationDistance() async {
    setState(() {
      _isLocationChecking = true;
    });

    if (_libraryLatitude == null || _libraryLongitude == null) {
      print('[2025-06-29 10:10:32] devivekrt: Library coordinates not available');
      setState(() {
        _isWithinRange = false;
        _isLocationChecking = false;
      });
      return;
    }

    // Use the location service to check if within range
    final isNearby = await _locationService.isWithinRange(
      targetLatitude: _libraryLatitude!,
      targetLongitude: _libraryLongitude!,
      radiusMeters: _locationCheckRadius,
      updateLocationIfStale: true, // Update location if stale
    );

    setState(() {
      _isWithinRange = isNearby;
      _isLocationChecking = false;
    });

    print('[2025-06-29 10:10:32] devivekrt: Location check result: within range = $_isWithinRange');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-29 10:31:19
// Current User's Login: devivekrt

// Handle QR scan result
  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessingQR) return; // Prevent multiple scans

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    // Get the first barcode
    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _isProcessingQR = true;
      _scanMessage = "Processing...";
    });

    // Pause scanner
    _scannerController.stop();

    try {
      // Process the scanned QR code
      String result;

      // For CHECK-IN: First check location before any further processing
      if (!_isCheckedIn) {
        // Parse library ID from QR code
        String? libraryId;

        if (code.contains('_SMARTLIB')) {
          final part = code.split('_')[1];
          libraryId = 'LIB_$part';
        } else if (code.contains('_CHECKIN') || code.contains('_CHECKOUT')) {
          final parts = code.split('_');
          libraryId = "LIB_${parts[1]}"; // Extract library ID
        } else {
          throw Exception('Invalid QR code format. Please scan a valid SmartLib QR code.');
        }

        print("[2025-06-29 10:31:19] devivekrt: Scanned library ID: $libraryId");

        // Fetch library location first
        await _fetchLibraryLocation(libraryId);

        // Get a fresh location update
        await _locationService.requestSingleLocationUpdate(highAccuracy: true);

        // Check if user is within range
        await _checkLocationDistance();

        // STRICT CHECK: If not within range, show error and abort
        if (!_isWithinRange) {
          setState(() {
            _showError = true;
            _scanMessage = "You must be within ${_locationCheckRadius.toStringAsFixed(0)} meters of ${_libraryName ?? 'the library'} to check in.";
          });

          // Reset after error
          Future.delayed(Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isProcessingQR = false;
                _showError = false;
                _scanMessage = "";
                _scannerController.start();
              });
            }
          });

          return; // Exit early, do not proceed with check-in
        }
      }

      // Now that location is verified (for check-ins), proceed with QR code processing
      if (code.contains('_SMARTLIB')) {
        // Smart format QR code - auto-detects check-in/check-out
        final part = code.split('_')[1];
        final libraryId = 'LIB_$part';
        print("[2025-06-29 10:31:19] devivekrt: Processing libraryId: $libraryId, Current library ID: $_currentLibraryId");

        // Determine action based on current state
        final action = _isCheckedIn ? "CHECKOUT" : "CHECKIN";

        // Process using the handler with attendance tracking
        result = await _processQRScan(libraryId: libraryId, action: action);
      } else if (code.contains('_CHECKIN') || code.contains('_CHECKOUT')) {
        // Legacy format - explicit check-in/check-out QR codes
        final parts = code.split('_');
        final libraryId = "LIB_${parts[1]}"; // Extract library ID
        final action = parts[2]; // Either CHECKIN or CHECKOUT

        // Process using the handler
        result = await _processQRScan(libraryId: libraryId, action: action);
      } else {
        // Invalid QR code format
        throw Exception('Invalid QR code format. Please scan a valid SmartLib QR code.');
      }

      // Show success or error based on result
      if (result.toLowerCase().contains('error') ||
          result.toLowerCase().contains('invalid') ||
          result.toLowerCase().contains('no active')) {
        setState(() {
          _showError = true;
          _scanMessage = result;
        });

        // Reset after error
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isProcessingQR = false;
              _showError = false;
              _scanMessage = "";
              _scannerController.start();
            });
          }
        });
      } else {
        // Success - update local state to reflect the change
        setState(() {
          _showSuccess = true;
          _scanMessage = result;
          _isCheckedIn = !_isCheckedIn; // Toggle check-in status
        });

        // Navigate back after success
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        });
      }
    } catch (e) {
      setState(() {
        _showError = true;
        _scanMessage = "Error: ${e.toString()}";
      });

      // Reset after error
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isProcessingQR = false;
            _showError = false;
            _scanMessage = "";
            _scannerController.start();
          });
        }
      });
    }
  }

// Enhanced QR scan processing with proper attendance tracking
  Future<String> _processQRScan({
    required String libraryId,
    required String action,
  }) async {
    try {
      // Use local timestamp instead of UTC
      final now = DateTime.now();
      // Format time as HH:mm
      final timeString = DateFormat('HH:mm').format(now);
      // Format date as YYYY-MM-DD for attendance history
      final todayDate = DateFormat('yyyy-MM-dd').format(now);

      // Handle check-in
      if (action == "CHECKIN") {
        // Double-check that user is within range (safety check)
        if (!_isWithinRange) {
          return "You must be within ${_locationCheckRadius.toStringAsFixed(0)} meters of ${_libraryName ?? 'the library'} to check in.";
        }

        // First check if user's currentStatus already has valid booking info
        final statusRef = _database.ref().child(
          'users/students/$_studentId/currentStatus',
        );
        final snapshot = await statusRef.get();

        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          final currentLibraryId = data['currentLibraryId']?.toString() ?? '';
          final currentBookingId = data['bookingId']?.toString() ?? '';
          final seatNo = data['currentSeatNo']?.toString() ?? '';
          final currentStatus = data['currentStatus']?.toString() ?? '';
          final paymentStatus = data['paymentStatus']?.toString() ?? '';
          final dueDate = data['dueDate']?.toString() ?? '';

          // Check for shift start time directly from current status
          String shiftStartTime = data['shiftStartTime']?.toString() ?? '';

          // Get shiftId(s) - handle both single and multiple shifts
          List<String> shiftIds = [];

          // Check for multiple shifts
          if (data.containsKey('shiftIds')) {
            if (data['shiftIds'] is List) {
              shiftIds =
                  (data['shiftIds'] as List)
                      .map((id) => id.toString())
                      .toList();
            } else if (data['shiftIds'] is Map) {
              shiftIds =
                  (data['shiftIds'] as Map).values
                      .map((id) => id.toString())
                      .toList();
            }
          }
          // Check for single shift
          else if (data.containsKey('shiftId')) {
            final shiftId = data['shiftId'];
            if (shiftId != null) {
              shiftIds = [shiftId.toString()];
            }
          }

          // VALIDATION STEP 1: Check if the booking is for the correct library
          if (currentLibraryId != libraryId) {
            return 'This booking is for another library. Please go to the correct library.';
          }

          // VALIDATION STEP 2: Check if the booking has valid payment status
          if (paymentStatus != 'paid' && paymentStatus != 'free') {
            return 'Your payment is pending. Please pay before checking in.';
          }

          // VALIDATION STEP 3: Check if the booking has a valid due date
          if (dueDate.isNotEmpty && dueDate.compareTo(todayDate) <= 0) {
            return 'Your booking has expired. Please make a new booking.';
          }

          // VALIDATION STEP 4: Check if the booking has valid seat and shift information
          if (seatNo.isEmpty || shiftIds.isEmpty) {
            return 'Incomplete booking information. Please contact library staff.';
          }
          //5. Check if the booking is cancelled
          if(currentStatus == "none"|| currentStatus.isEmpty) {
            return 'You have no active booking. Please make a new booking.';
          }

          // Check if it's too early to check in (30+ minutes before shift start)
          bool canCheckIn = true;
          String earliestCheckinTime = "";

          // USE SHIFT START TIME FROM CURRENT STATUS IF AVAILABLE
          if (shiftStartTime.isNotEmpty) {
            try {
              final parts = shiftStartTime.split(':');
              if (parts.length >= 2) {
                final shiftHour = int.tryParse(parts[0]) ?? 0;
                final shiftMinute = int.tryParse(parts[1]) ?? 0;

                // Get current date components for accurate comparison
                final now = DateTime.now();
                final currentYear = now.year;
                final currentMonth = now.month;
                final currentDay = now.day;
                final currentHour = now.hour;
                final currentMinute = now.minute;

                // Create DateTime objects for accurate comparison
                final shiftStartDateTime = DateTime(
                  currentYear,
                  currentMonth,
                  currentDay,
                  shiftHour,
                  shiftMinute,
                );

                // Current time as DateTime for comparison
                final currentDateTime = DateTime(
                  currentYear,
                  currentMonth,
                  currentDay,
                  currentHour,
                  currentMinute,
                );

                // Calculate 30 minutes before shift start
                final earlyCheckinDateTime = shiftStartDateTime.subtract(
                  const Duration(minutes: 30),
                );

                // Format for display in error message
                earliestCheckinTime = DateFormat('HH:mm').format(earlyCheckinDateTime);

                // Compare using DateTime objects for more reliable comparison
                if (currentDateTime.isBefore(earlyCheckinDateTime)) {
                  canCheckIn = false;
                  print("[2025-06-29 10:31:19] devivekrt: Too early to check in. Current time: $currentDateTime, Earliest check-in time: $earlyCheckinDateTime");
                } else {
                  print("[2025-06-29 10:31:19] devivekrt: Check-in allowed. Current time: $currentDateTime, Shift start time: $shiftStartDateTime");
                }
              }
            } catch (e) {
              print("[2025-06-29 10:31:19] devivekrt: Error checking shift start time from current status: $e");
              // Default to allowing check-in if there's an error
              canCheckIn = true;
            }
          }

          // If it's too early to check in
          if (!canCheckIn) {
            return 'Too early to check in. You can check in starting at $earliestCheckinTime.';
          }

          // All validations passed, proceed with check-in
          await _database
              .ref()
              .child("users/students/$_studentId/currentStatus")
              .update({
            'isCheckedIn': true,
            'checkInTime': timeString,
            'checkOutTime': '',
            'status': 'checkedIn',
            'checkInDate': todayDate, // Also store the date for duration calculation
          });

          // Update all shifts in the library document
          for (String shiftId in shiftIds) {
            await _firestore
                .collection('libraries')
                .doc(libraryId)
                .update({'seats.$seatNo.shifts.$shiftId.isCheckedIn': true});
          }

          // Create or update attendance record
          await _updateAttendanceHistory(
            libraryId: libraryId,
            seatNo: seatNo,
            shiftId: shiftIds.first,
            shiftIds: shiftIds,
            status: 'active',
            checkInTime: timeString,
            date: todayDate,
          );

          // Check and update streak
          await _updateStreak(true);

          return 'Successfully checked in to seat $seatNo';
        }

        // No active booking found
        return 'No active booking found for this library';
      } else if (action == "CHECKOUT") {
        // Get check-in time from database to calculate duration
        final statusRef =
        await _database
            .ref()
            .child('users/students/$_studentId/currentStatus')
            .get();

        int studyHours = 0;
        List<String> shiftIds = [];

        if (statusRef.exists) {
          final data = statusRef.value as Map<dynamic, dynamic>;
          final checkInTimeStr = data['checkInTime']?.toString() ?? '';
          final seatNo = data['currentSeatNo']?.toString() ?? '';
          final checkInDateStr = data['checkInDate']?.toString() ?? todayDate;

          // Get all shift IDs
          if (data.containsKey('shiftIds')) {
            if (data['shiftIds'] is List) {
              shiftIds =
                  (data['shiftIds'] as List)
                      .map((id) => id.toString())
                      .toList();
            } else if (data['shiftIds'] is Map) {
              shiftIds =
                  (data['shiftIds'] as Map).values
                      .map((id) => id.toString())
                      .toList();
            }
          } else if (data.containsKey('shiftId')) {
            final shiftId = data['shiftId'];
            if (shiftId != null) {
              shiftIds = [shiftId.toString()];
            }
          }

          if (checkInTimeStr.isNotEmpty) {
            try {
              // Calculate duration since check-in
              final checkInParts = checkInTimeStr.split(':');
              final checkInHour = int.tryParse(checkInParts[0]) ?? 0;
              final checkInMinute = int.tryParse(checkInParts[1]) ?? 0;
              final checkInDateParts = checkInDateStr.split('-');
              final checkInDate = DateTime(
                int.parse(checkInDateParts[0]), // Year
                int.parse(checkInDateParts[1]), // Month
                int.parse(checkInDateParts[2]), // Day
                checkInHour,
                checkInMinute,
              );
              final currentDateTime = DateTime.now();
              final duration = currentDateTime.difference(checkInDate);
              studyHours = duration.inHours;
              print("[2025-06-29 10:31:19] devivekrt: Study hours: $studyHours");
            } catch (e) {
              print("[2025-06-29 10:31:19] devivekrt: Error calculating duration: $e");
            }
          }
        }

        // Update student's current status
        await _database
            .ref()
            .child("users/students/$_studentId/currentStatus")
            .update({
          'isCheckedIn': false,
          'checkOutTime': timeString,
          'status': 'checkedOut',
          'studyDuration': studyHours,
        });

        for (String shiftId in shiftIds) {
          await _firestore
              .collection('libraries')
              .doc(libraryId)
              .update({'seats.$_seatNo.shifts.$shiftId.isCheckedIn': false});
        }

        // Update attendance record in attendanceHistory - update the existing record
        await _updateAttendanceHistory(
          libraryId: _currentLibraryId,
          seatNo: _seatNo,
          shiftId: shiftIds.isNotEmpty ? shiftIds.first : _shiftId,
          shiftIds: shiftIds,
          status: 'completed',
          checkOutTime: timeString,
          duration: studyHours,
          date: todayDate,
        );

        return 'Successfully checked out. Duration: ${_formatDuration(studyHours)}';
      }

      return 'Unrecognized action';
    } catch (e) {
      print('[2025-06-29 10:31:19] devivekrt: Error processing QR scan: $e');
      return 'Error processing scan: ${e.toString()}';
    }
  }

// Format duration hours to readable string
  String _formatDuration(int hours) {
    if (hours < 1) {
      return 'Less than 1 hour';
    } else if (hours == 1) {
      return '1 hour';
    } else {
      return '$hours hours';
    }
  }
  // Update attendance history record
  Future<void> _updateAttendanceHistory({
    required String libraryId,
    required String seatNo,
    required String shiftId,
    List<String>? shiftIds,
    required String status,
    required String date,
    String? checkInTime,
    String? checkOutTime,
    int? duration,
    DateTime? shiftStartTime,
    DateTime? shiftEndTime,
  }) async {
    try {
      // Create base attendance data object with common fields
      Map<String, dynamic> baseAttendanceData = {
        'studentId': _studentId,
        'studentName': _studentName,
        'libraryId': libraryId,
        'seatNo': seatNo,
        'shiftId': shiftId,
      };

      // Add shiftIds if available (for multiple shifts)
      if (shiftIds != null && shiftIds.isNotEmpty) {
        baseAttendanceData['shiftIds'] = shiftIds;
        baseAttendanceData['isMultipleShifts'] = shiftIds.length > 1;
      }

      // Generate a unique ID for the attendance record if not updating an existing one
      final String recordId = '$_studentId-$libraryId-$date';

      // Create attendance record data
      Map<String, dynamic> attendanceData = {
        ...baseAttendanceData,
        'status': status,
        'date': date,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add check-in time if provided
      if (checkInTime != null) {
        attendanceData['checkInTime'] = checkInTime;
      }

      // Add check-out time if provided
      if (checkOutTime != null) {
        attendanceData['checkOutTime'] = checkOutTime;
      }

      // Add duration if provided
      if (duration != null) {
        attendanceData['studyHours'] = duration;
      }

      // Store the attendance record - use set with merge to update existing records
      await _firestore
          .collection('attendanceHistory')
          .doc(date)
          .collection('records')
          .doc(recordId)
          .set(attendanceData, SetOptions(merge: true));

      print('[2025-06-29 10:10:32] devivekrt: Attendance history updated for $date');
    } catch (e) {
      print("[2025-06-29 10:10:32] devivekrt: Error updating attendance history: $e");
      throw e;
    }
  }

  // Update streak count - only once per day
  Future<void> _updateStreak(bool isCheckingIn) async {
    try {
      if (!isCheckingIn) {
        // Only update streak on check-in, not check-out
        return;
      }

      // Get today's date string
      final today = DateTime.now();
      final todayString = _formatDateToString(today);

      // Check if we already updated the streak today
      final streakRef = _database.ref().child(
        "users/students/$_studentId/streakData",
      );

      final streakSnapshot = await streakRef.once();
      final streakData =
          streakSnapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};

      // Convert to type-safe map
      final Map<String, dynamic> safeStreakData = {};
      streakData.forEach((key, value) {
        safeStreakData[key.toString()] = value;
      });

      // Check if we already updated the streak today
      if (safeStreakData['lastUpdatedDate'] == todayString) {
        print("[2025-06-29 10:10:32] devivekrt: Streak already updated today. Skipping.");
        return;
      }

      // Check yesterday's attendance to determine streak continuity
      final yesterday = today.subtract(Duration(days: 1));
      final yesterdayString = _formatDateToString(yesterday);

      final yesterdayRef = _firestore
          .collection('attendanceHistory')
          .doc(yesterdayString)
          .collection('records')
          .where('studentId', isEqualTo: _studentId)
          .limit(1);

      final snapshot = await yesterdayRef.get();

      // Get current streak value
      final currentStreak = safeStreakData['value'] ?? 0;
      int newStreak;

      if (snapshot.docs.isNotEmpty) {
        // If checked in yesterday, increment streak
        newStreak = currentStreak + 1;
        print("[2025-06-29 10:10:32] devivekrt: Checked in yesterday. New streak: $newStreak");
      } else {
        // If not checked in yesterday, check if this is the first check-in after multiple missed days

        // Find the last check-in date (look back up to 30 days)
        final now = DateTime.now();
        final dateFormat = DateFormat('yyyy-MM-dd');
        bool found = false;
        DateTime? lastCheckInDate;

        for (int i = 2; i <= 30; i++) {
          // Start from 2 days ago (we already checked yesterday)
          final date = now.subtract(Duration(days: i));
          final dateStr = dateFormat.format(date);

          final attendanceRef = _firestore
              .collection('attendanceHistory')
              .doc(dateStr)
              .collection('records')
              .where('studentId', isEqualTo: _studentId)
              .limit(1);

          final attendanceSnapshot = await attendanceRef.get();
          if (attendanceSnapshot.docs.isNotEmpty) {
            found = true;
            lastCheckInDate = date;
            break;
          }
        }

        // If found a previous check-in and it was exactly 2 days ago,
        // and the student didn't check in yesterday but did the day before,
        // we can consider it just a 1-day gap and not reset the streak completely
        // (customize this rule based on your app's streak policy)
        if (found && lastCheckInDate != null) {
          final daysDifference = today.difference(lastCheckInDate).inDays;
          if (daysDifference <= 2) {
            // Just missed yesterday
            newStreak =
                currentStreak; // Keep the streak (or subtract 1 if you prefer)
            print("[2025-06-29 10:10:32] devivekrt: Missed only yesterday. Maintaining streak: $newStreak");
          } else {
            // Missed more than one day, reset streak
            newStreak = 1;
            print("[2025-06-29 10:10:32] devivekrt: Missed multiple days. Resetting streak to 1");
          }
        } else {
          // No previous check-ins found or too old, start new streak
          newStreak = 1;
          print("[2025-06-29 10:10:32] devivekrt: No recent check-ins found. New streak: 1");
        }
      }

      // Update streak in the main profile
      await _database
          .ref()
          .child("users/students/$_studentId/currentStatus")
          .update({'streak': newStreak});

      // Update streak metadata to prevent multiple updates in same day
      await streakRef.update({
        'value': newStreak,
        'lastUpdatedDate': todayString,
        'updatedAt': ServerValue.timestamp,
      });

      print("[2025-06-29 10:10:32] devivekrt: Streak updated successfully to $newStreak");

      // If streak reaches certain milestones, consider creating an achievement notification
      if (newStreak == 7 || newStreak == 30 || newStreak == 100) {
        _createStreakAchievementNotification(newStreak);
      }
    } catch (e) {
      print("[2025-06-29 10:10:32] devivekrt: Error updating streak: $e");
    }
  }

  // Helper function to format date to string
  String _formatDateToString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Create streak achievement notification
  Future<void> _createStreakAchievementNotification(int streak) async {
    try {
      String message;
      String title;

      if (streak == 7) {
        title = "7-Day Streak!";
        message =
        "Congratulations! You've maintained a 7-day study streak. Keep up the great work!";
      } else if (streak == 30) {
        title = "30-Day Streak!";
        message =
        "Amazing achievement! You've studied for 30 consecutive days!";
      } else if (streak == 100) {
        title = "100-Day Streak!";
        message =
        "Incredible dedication! 100 days of continuous studying is a remarkable achievement!";
      } else {
        return; // No notification for other streak values
      }

      // Create notification in Firestore
      await _firestore.collection('notifications').add({
        'userId': _studentId,
        'type': 'streak_achievement',
        'title': title,
        'message': message,
        'read': false,
        'streakDays': streak,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also add to realtime DB for faster access
      await _database
          .ref("users/students/$_studentId/notifications")
          .push()
          .set({
        'type': 'streak_achievement',
        'title': title,
        'streakDays': streak,
        'read': false,
        'createdAt': ServerValue.timestamp,
      });

      print("[2025-06-29 10:10:32] devivekrt: Created streak achievement notification for $streak days");
    } catch (e) {
      print("[2025-06-29 10:10:32] devivekrt: Error creating streak achievement notification: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final width = MediaQuery.of(context).size.width;

    // Show loading indicator while fetching status
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xff1940CC)),
              SizedBox(height: 20),
              Text(
                "Loading your current status...",
                style: TextStyle(
                  color: Color(0xff1940CC),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Current streak badge if streak > 0
                  if (_streak > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.amber,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Streak: $_streak day${_streak != 1 ? 's' : ''}",
                              style: TextStyle(
                                color: Colors.amber[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Text(
                    _isCheckedIn
                        ? "Check Out from Library"
                        : "Check In to Library",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _isCheckedIn
                        ? "Scan QR code to check out"
                        : "Scan QR code to check in",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),

                  // Display current seat info if checked in
                  if (_isCheckedIn && _currentSeatNo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Currently at seat: $_currentSeatNo",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Display shift info if available
                  if (_shiftStartTime.isNotEmpty && _shiftEndTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Shift: $_shiftStartTime - $_shiftEndTime",
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ),

                  // Display location status indicator
                  if (!_isCheckedIn) // Only show when not checked in
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isLocationChecking ? Colors.grey[700] :
                          _isWithinRange ? Colors.green.withOpacity(0.2) :
                          Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: _isLocationChecking ? Colors.grey :
                            _isWithinRange ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isLocationChecking ?
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                )
                            ) :
                            Icon(
                              _isWithinRange ? Icons.location_on : Icons.location_off,
                              color: _isWithinRange ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _isLocationChecking ? "Checking location..." :
                              _isWithinRange ? "Within library range" : "Not in library range",
                              style: TextStyle(
                                color: _isLocationChecking ? Colors.white :
                                _isWithinRange ? Colors.green[800] : Colors.red[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Display location coordinates if available
                  if (_locationService.isLocationAvailable && !_isCheckedIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Last update: ${_locationService.lastUpdated != null ?
                        DateFormat('HH:mm').format(_locationService.lastUpdated!) : "Unknown"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  SizedBox(height: 30),

                  // QR Scanner Frame
                  Container(
                    width: width * 0.8,
                    height: width * 0.8,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                        _showSuccess
                            ? Colors.green
                            : _showError
                            ? Colors.red
                            : Color(0xff1940CC),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          // Conditional rendering based on state
                          if (!_showSuccess && !_showError)
                            if (_isCheckedIn || _isWithinRange)
                              MobileScanner(
                                controller: _scannerController,
                                onDetect: _onDetect,
                              )
                            else
                              Container(
                                color: Colors.black87,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_off,
                                        color: Colors.red,
                                        size: 60,
                                      ),
                                      SizedBox(height: 20),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Text(
                                          "You must be within ${_locationCheckRadius.toStringAsFixed(0)} meters of ${_libraryName ?? 'the library'} to check in",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () async {
                                          // Get a fresh location update
                                          await _locationService.requestSingleLocationUpdate();
                                          await _checkLocationDistance();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xff1940CC),
                                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: Text("Update Location"),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                          // Show success screen
                          if (_showSuccess)
                            Container(
                              color: Colors.black87,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 60,
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      _scanMessage,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Show error screen
                          if (_showError)
                            Container(
                              color: Colors.black87,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 60,
                                    ),
                                    SizedBox(height: 20),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                      ),
                                      child: Text(
                                        _scanMessage,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Corner markers
                          Positioned(
                            top: 0,
                            left: 0,
                            child: _buildCornerMarker(
                              _showSuccess
                                  ? Colors.green
                                  : _showError
                                  ? Colors.red
                                  : Color(0xff1940CC),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Transform.rotate(
                              angle: 90 * 3.14159 / 180,
                              child: _buildCornerMarker(
                                _showSuccess
                                    ? Colors.green
                                    : _showError
                                    ? Colors.red
                                    : Color(0xff1940CC),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Transform.rotate(
                              angle: -90 * 3.14159 / 180,
                              child: _buildCornerMarker(
                                _showSuccess
                                    ? Colors.green
                                    : _showError
                                    ? Colors.red
                                    : Color(0xff1940CC),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Transform.rotate(
                              angle: 180 * 3.14159 / 180,
                              child: _buildCornerMarker(
                                _showSuccess
                                    ? Colors.green
                                    : _showError
                                    ? Colors.red
                                    : Color(0xff1940CC),
                              ),
                            ),
                          ),

                          // Scan line animation (only when scanning and in range)
                          if (!_showSuccess && !_showError && (_isCheckedIn || _isWithinRange))
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Positioned(
                                  top:
                                  _animationController.value *
                                      (width * 0.8 - 2),
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0xff1940CC),
                                          Color(0xff1940CC),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Show processing message
                          if (_isProcessingQR && !_showSuccess && !_showError)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      "Processing...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Center helper text (only when scanning and in range)
                          if (!_isProcessingQR && !_showSuccess && !_showError && (_isCheckedIn || _isWithinRange))
                            Center(
                              child: Text(
                                "Position QR code in frame",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3.0,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Action label with location requirement note
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      _isCheckedIn
                          ? "The system will automatically check you out when you scan the library QR code"
                          : "You must be within ${_locationCheckRadius.toStringAsFixed(0)} meters of the library to check in",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _isCheckedIn ? Color(0xff1940CC) :
                        _isWithinRange ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Update location button
                  if (!_isCheckedIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: TextButton.icon(
                        onPressed: () async {
                          // Use the location service for update
                          await _locationService.requestSingleLocationUpdate();
                          await _checkLocationDistance();
                        },
                        icon: Icon(
                          Icons.my_location,
                          color: Color(0xff1940CC),
                          size: 18,
                        ),
                        label: Text(
                          "Update My Location",
                          style: TextStyle(
                            color: Color(0xff1940CC),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: BorderSide(
                              color: Color(0xff1940CC).withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 20),

                  // Show check-in time if checked in
                  if (_checkInTime.isNotEmpty && _isCheckedIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          "Checked in at: $_checkInTime",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // Show due date info if available
                  if (_dueDate.isNotEmpty && _isCheckedIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Text(
                          "Due date: $_dueDate",
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Help text at bottom
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _isCheckedIn
                  ? "Don't forget to check out before you leave!"
                  : "Remember to check in when you arrive at the library.",
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Format time for display
  String _formatTimeDisplay(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('hh:mm a').format(dateTime.toLocal());
    } catch (e) {
      return isoString; // Return the original string if parsing fails
    }
  }

  // Corner Marker for QR Scanner
  Widget _buildCornerMarker(Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color, width: 3),
          left: BorderSide(color: color, width: 3),
        ),
      ),
    );
  }
}