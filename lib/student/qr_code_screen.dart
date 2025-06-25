import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

class QRScannerScreen extends StatefulWidget {
  // No parameters used anymore - we'll get everything from the database
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isProcessingQR = false;
  String _scanMessage = "";
  bool _showSuccess = false;
  bool _showError = false;
  bool _isCheckedIn = false;
  bool _isLoading = true;

  // Current student details
  final String _studentId = SmartLib.userId;
  final String _studentName = SmartLib.studentName;

  // Current Date and Time formatted as required
  final formattedDateTime = DateTime.now().isUtc;

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

    // Fetch current status from Firebase
    _fetchCurrentStatus();
  }

  // Fetch user's complete current status from Firebase Realtime Database
  Future<void> _fetchCurrentStatus() async {
    try {
      final statusRef = FirebaseDatabase.instance.ref().child(
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

          _streak =
              (data['streak'] != null)
                  ? int.tryParse(data['streak'].toString()) ?? 0
                  : 0;

          _isLoading = false;
        });
      } else {
        setState(() {
          _isCheckedIn = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching current status: $e');
      setState(() {
        _isCheckedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

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

      // Determine the action based on QR code format
      if (code.contains('_SMARTLIB')) {
        // Smart format QR code - auto-detects check-in/check-out
        final part = code.split('_')[1];
        final libraryId = 'LIB_$part';
        print("Scanned library ID: $libraryId");
        print("Current library ID: $_currentLibraryId");

        // Determine if we're checking in or out based on current state
        final action = _isCheckedIn ? "CHECKOUT" : "CHECKIN";

        // Process using the handler with attendance tracking
        result = await _processQRScan(libraryId: libraryId, action: action);
      } else if (code.contains('_CHECKIN') || code.contains('_CHECKOUT')) {
        // Legacy format - explicit check-in/check-out QR codes
        final parts = code.split('_');
        final libraryId = parts[0];
        final action = parts[1];

        result = await _processQRScan(libraryId: libraryId, action: action);
      } else {
        // Invalid QR code format
        throw Exception(
          'Invalid QR code format. Please scan a valid SmartLib QR code.',
        );
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
      final timeString = DateFormat('HH:mm:ss').format(now);
      // Format date as YYYY-MM-DD for attendance history
      final todayDate = DateFormat('yyyy-MM-dd').format(now);

      // Handle check-in
      if (action == "CHECKIN") {
        // First check if user's currentStatus already has valid booking info
        final statusRef = FirebaseDatabase.instance.ref().child(
          'users/students/$_studentId/currentStatus',
        );
        final snapshot = await statusRef.get();

        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          final currentLibraryId = data['currentLibraryId']?.toString() ?? '';
          final currentBookingId = data['bookingId']?.toString() ?? '';
          final seatNo = data['currentSeatNo']?.toString() ?? '';
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
          if (currentBookingId.isEmpty || seatNo.isEmpty || shiftIds.isEmpty) {
            return 'Incomplete booking information. Please contact library staff.';
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

                // Calculate 30 minutes before shift start
                final shiftStartDateTime = DateTime(
                  int.parse(todayDate.split('-')[0]), // Year
                  int.parse(todayDate.split('-')[1]), // Month
                  int.parse(todayDate.split('-')[2]), // Day
                  shiftHour,
                  shiftMinute,
                );

                final earlyCheckinDateTime = shiftStartDateTime.subtract(
                  Duration(minutes: 30),
                );

                // Format for comparison
                earliestCheckinTime =
                    "${earlyCheckinDateTime.hour.toString().padLeft(2, '0')}:${earlyCheckinDateTime.minute.toString().padLeft(2, '0')}";

                // Compare current time with early check-in time
                final currentTimeParts = timeString.split(':');
                final currentHour = int.tryParse(currentTimeParts[0]) ?? 0;
                final currentMinute = int.tryParse(currentTimeParts[1]) ?? 0;

                final currentTimeMinutes = currentHour * 60 + currentMinute;
                final earlyCheckinMinutes =
                    earlyCheckinDateTime.hour * 60 +
                    earlyCheckinDateTime.minute;

                if (currentTimeMinutes < earlyCheckinMinutes) {
                  canCheckIn = false;
                }
              }
            } catch (e) {
              print("Error checking shift start time from current status: $e");
              // Default to allowing check-in if there's an error
              canCheckIn = true;
            }
          }
          // If it's too early to check in
          if (!canCheckIn) {
            return 'Too early to check in. You can check in starting at $earliestCheckinTime.';
          }

          // All validations passed, proceed with check-in
          await FirebaseDatabase.instance
              .ref()
              .child("users/students/$_studentId/currentStatus")
              .update({
                'isCheckedIn': true,
                'checkInTime': timeString,
                'checkOutTime': '',
                'status': 'checkedIn',
              });

          // Update all shifts in the library document
          for (String shiftId in shiftIds) {
            await FirebaseFirestore.instance
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

        // [Firestore booking search code]
      } else if (action == "CHECKOUT") {
        // Get check-in time from database to calculate duration
        final statusRef =
            await FirebaseDatabase.instance
                .ref()
                .child('users/students/$_studentId/currentStatus')
                .get();

        int durationMinutes = 0;
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
              final currentDateTime = DateTime.now().toUtc();
              final duration = currentDateTime.difference(checkInDate);
              durationMinutes = duration.inMinutes;
              print("Duration in minutes: $durationMinutes");
            } catch (e) {
              print("Error calculating duration: $e");
            }
          }
        }

        // Update student's current status
        await FirebaseDatabase.instance
            .ref()
            .child("users/students/$_studentId/currentStatus")
            .update({
              'isCheckedIn': false,
              'checkOutTime': timeString,
              'status': 'checkedOut',
          'studyDuration': durationMinutes,
            });

        for (String shiftId in shiftIds) {
          await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .update({'seats.$_seatNo.shifts.$shiftId.isCheckedIn': true});
        }

        // Update attendance record in attendanceHistory - update the existing record
        await _updateAttendanceHistory(
          libraryId: _currentLibraryId,
          seatNo: _seatNo,
          shiftId: shiftIds.isNotEmpty ? shiftIds.first : _shiftId,
          shiftIds: shiftIds,
          status: 'completed',
          checkOutTime: timeString,
          duration: durationMinutes,
          date: todayDate,
        );

        return 'Successfully checked out. Duration: ${_formatDuration(durationMinutes)}';
      }

      return 'Unrecognized action';
    } catch (e) {
      print('Error processing QR scan: $e');
      return 'Error processing scan: Please try again';
    }
  }

// Update attendance history in database - creates separate check-in and check-out records
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

      // Handle CHECK-IN activity if provided
      if (checkInTime != null) {
        // Create a separate check-in record
        Map<String, dynamic> checkInData = {
          ...baseAttendanceData,
          'type': 'Check-In',
          'status': 'checked_in',
          'checkInTime': checkInTime,
          'timestamp': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Store the check-in record
        await FirebaseFirestore.instance
            .collection('attendanceHistory')
            .doc(date)
            .collection('records')
            .add(checkInData);

        print('Check-in record saved for $date');
      }

      // Handle CHECK-OUT activity if provided
      if (checkOutTime != null) {
        // Create a separate check-out record
        Map<String, dynamic> checkOutData = {
          ...baseAttendanceData,
          'type': 'Check-Out',
          'status': 'checked_out',
          'checkOutTime': checkOutTime,
          'timestamp': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add duration if available
        if (duration != null) {
          checkOutData['duration'] = duration;
        }

        // Store the check-out record
        await FirebaseFirestore.instance
            .collection('attendanceHistory')
            .doc(date)
            .collection('records')
            .add(checkOutData);

        print('Check-out record saved for $date');
      }

    } catch (e) {
      print("Error updating attendance history: $e");
      // Don't throw error to avoid interrupting check-in/out process
    }
  }

  // Update streak count
// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-22 09:45:31
// Current User's Login: devivekrt

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
      final streakRef = FirebaseDatabase.instance
          .ref()
          .child("users/students/$_studentId/streakData");

      final streakSnapshot = await streakRef.once();
      final streakData = streakSnapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};

      // Convert to type-safe map
      final Map<String, dynamic> safeStreakData = {};
      streakData.forEach((key, value) {
        safeStreakData[key.toString()] = value;
      });

      // Check if we already updated the streak today
      if (safeStreakData['lastUpdatedDate'] == todayString) {
        print("Streak already updated today. Skipping.");
        return;
      }

      // Check yesterday's attendance to determine streak continuity
      final yesterday = today.subtract(Duration(days: 1));
      final yesterdayString = _formatDateToString(yesterday);

      final yesterdayRef = FirebaseFirestore.instance
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
        print("Checked in yesterday. New streak: $newStreak");
      } else {
        // If not checked in yesterday, check if this is the first check-in after multiple missed days

        // Find the last check-in date (look back up to 30 days)
        final now = DateTime.now();
        final dateFormat = DateFormat('yyyy-MM-dd');
        bool found = false;
        DateTime? lastCheckInDate;

        for (int i = 2; i <= 30; i++) { // Start from 2 days ago (we already checked yesterday)
          final date = now.subtract(Duration(days: i));
          final dateStr = dateFormat.format(date);

          final attendanceRef = FirebaseFirestore.instance
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
          if (daysDifference <= 2) { // Just missed yesterday
            newStreak = currentStreak;  // Keep the streak (or subtract 1 if you prefer)
            print("Missed only yesterday. Maintaining streak: $newStreak");
          } else {
            // Missed more than one day, reset streak
            newStreak = 1;
            print("Missed multiple days. Resetting streak to 1");
          }
        } else {
          // No previous check-ins found or too old, start new streak
          newStreak = 1;
          print("No recent check-ins found. New streak: 1");
        }
      }

      // Update streak in the main profile
      await FirebaseDatabase.instance
          .ref()
          .child("users/students/$_studentId/currentStatus")
          .update({'streak': newStreak});

      // Update streak metadata to prevent multiple updates in same day
      await streakRef.update({
        'value': newStreak,
        'lastUpdatedDate': todayString,
        'updatedAt': ServerValue.timestamp,
      });

      print("Streak updated successfully to $newStreak");

      // If streak reaches certain milestones, consider creating an achievement notification
      if (newStreak == 7 || newStreak == 30 || newStreak == 100) {
        _createStreakAchievementNotification(newStreak);
      }

    } catch (e) {
      print("Error updating streak: $e");
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
        message = "Congratulations! You've maintained a 7-day study streak. Keep up the great work!";
      } else if (streak == 30) {
        title = "30-Day Streak!";
        message = "Amazing achievement! You've studied for 30 consecutive days!";
      } else if (streak == 100) {
        title = "100-Day Streak!";
        message = "Incredible dedication! 100 days of continuous studying is a remarkable achievement!";
      } else {
        return; // No notification for other streak values
      }

      // Create notification in Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': _studentId,
        'type': 'streak_achievement',
        'title': title,
        'message': message,
        'read': false,
        'streakDays': streak,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also add to realtime DB for faster access
      await FirebaseDatabase.instance
          .ref("users/students/$_studentId/notifications")
          .push()
          .set({
        'type': 'streak_achievement',
        'title': title,
        'streakDays': streak,
        'read': false,
        'createdAt': ServerValue.timestamp,
      });

    } catch (e) {
      print("Error creating streak achievement notification: $e");
    }
  }
  // Format duration from minutes to readable string
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours hour${hours > 1 ? 's' : ''} $remainingMinutes minute${remainingMinutes != 1 ? 's' : ''}';
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

                  SizedBox(height: 40),

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
                          // Camera view with live scanner
                          if (!_showSuccess && !_showError)
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _onDetect,
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

                          // Scan line animation (only when scanning)
                          if (!_showSuccess && !_showError)
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

                          // Center helper text (only when scanning)
                          if (!_isProcessingQR && !_showSuccess && !_showError)
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

                  // Action label
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      _isCheckedIn
                          ? "The system will automatically check you out when you scan the library QR code"
                          : "The system will automatically check you in when you scan the library QR code",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xff1940CC)),
                    ),
                  ),

                  SizedBox(height: 30),

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
                          "Checked in at: ${_formatTimeDisplay(_checkInTime)}",
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
      return "Unknown";
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
