import 'dart:math';
import 'dart:math' as math;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Added for formatting date
import 'package:smartlib/student/student_card_page.dart';
import 'package:smartlib/widgets/solid_button.dart';

// For navigation to marketplace and detail page
import '../data/string.dart';
import '../models/library_model.dart';
import 'library_detail_screen.dart';
import 'library_market_place.dart';
import 'notification_center.dart';

class StudentHomePage extends StatefulWidget {
  final VoidCallback onScanButtonPressed;
  final VoidCallback onBookSeatPressed;

  const StudentHomePage({
    Key? key,
    required this.onScanButtonPressed,
    required this.onBookSeatPressed,
  }) : super(key: key);

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Current user details
  String? _userId;
  String _userName = "User";
  Map<String, dynamic> _userData = {};

  // Status data
  bool _isCheckedIn = false;
  String _currentSeatId = "";
  String _currentLibraryId = "";
  String _currentLibraryName = "";
  String _currentBookingId = ""; // Added missing property
  String _shiftId = ""; // Added missing property
  String _shiftStartTime = ""; // Added missing property
  String _shiftEndTime = ""; // Added missing property
  String _dueDate = ""; // Added missing property
  double _fee = 0.0; // Added missing property
  String _paymentStatus = ""; // Added missing property
  int _shiftCount = 0; // Added missing property
  String? _checkInTime;
  String? _checkOutTime; // Added missing property

  // For location
  double _studentLat = 28.6139; // Example: New Delhi latitude
  double _studentLon = 77.2090; // Example: New Delhi longitude

  // Data containers
  List<LibraryModel> _allLibraries = [];
  List<LibraryModel> _joinedLibraries = [];
  List<_LibraryWithDistance> _nearbyLibrariesWithDistance = [];
  bool _isLoadingLibraries = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _seatHistory = [];
  bool _isLoadingHistory = true;
  bool _isLoadingCurrentStatus = true;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }


  // Get current user details and start data fetching
  void _getCurrentUser() {
    _userId = SmartLib.userId;

    // Once we have the user ID, fetch all data
    _fetchUserData().then((_) {
      _fetchCurrentStatus();
      _fetchNearbyLibraries();
      _fetchSeatHistory();
    });
  }

  // Fetch user data from Realtime Database
  Future<void> _fetchUserData() async {
    if (_userId == null || _userId!.isEmpty) return;

    try {
      setState(() {
        _isLoadingUserData = true;
      });

      // Get user data from Realtime Database
      DatabaseEvent event = await _database
          .ref()
          .child('${SmartLib.constPath}/students/$_userId')
          .once();

      if (event.snapshot.exists) {
        // Convert snapshot value to Map
        Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;

        // Convert to type-safe Map<String, dynamic>
        Map<String, dynamic> userData = {};
        data.forEach((key, value) => userData[key.toString()] = value);

        setState(() {
          _userData = userData;
          _userName = userData['fullName'] ?? "User";
          SmartLib.studentName = _userName;
        });

        print('User data loaded: $_userName');
      } else {
        print('No user data found in Realtime Database');
      }
    } catch (e) {
      print('Error fetching user data: $e');
    } finally {
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  // Fetch current status from Realtime Database - updated to show all data without check-in requirement
  Future<void> _fetchCurrentStatus() async {
    try {
      setState(() {
        _isLoadingCurrentStatus = true;
      });

      // Get user's current status from Realtime Database
      DatabaseEvent event = await _database
          .ref()
          .child('${SmartLib.constPath}/students/$_userId/currentStatus')
          .once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;

        // Convert to type-safe Map
        Map<String, dynamic> statusData = {};
        data.forEach((key, value) => statusData[key.toString()] = value);

        setState(() {
          // Set check-in status - keep this for reference but don't gate the other data on it
          _isCheckedIn = statusData['isCheckedIn'] == true;

          // Basic library and seat info - show regardless of check-in status
          _currentLibraryId = statusData['currentLibraryId']?.toString() ?? '';
          _currentSeatId = statusData['currentSeatNo']?.toString() ?? '';

          // Get booking ID
          _currentBookingId = statusData['bookingId']?.toString() ?? '';

          // Get shift information
          _shiftId = statusData['shiftName']?.toString() ?? '';
          _shiftStartTime = statusData['shiftStartTime']?.toString() ?? '';
          _shiftEndTime = statusData['shiftEndTime']?.toString() ?? '';

          // Get payment and timing information
          _dueDate = statusData['dueDate']?.toString() ?? '';
          _fee = (statusData['shiftFee'] != null)
              ? double.tryParse(statusData['shiftFee'].toString()) ?? 0.0
              : 0.0;
          _paymentStatus = statusData['paymentStatus']?.toString() ?? '';

          // Get shift count
          _shiftCount = (statusData['shiftCount'] != null)
              ? int.tryParse(statusData['shiftCount'].toString()) ?? 1
              : 1;

          // Get check-in/out times
          _checkInTime = statusData['checkInTime']?.toString();
          _checkOutTime = statusData['checkOutTime']?.toString();
        });

        // Fetch library name if we have library ID - do this regardless of check-in status
        if (_currentLibraryId.isNotEmpty) {
          try {
            final libraryDoc = await _firestore
                .collection('libraries')
                .doc(_currentLibraryId)
                .get();

            if (libraryDoc.exists) {
              final libraryData = libraryDoc.data();
              setState(() {
                _currentLibraryName = libraryData?['libraryName'] ?? 'Unknown Library';
              });
            }
          } catch (e) {
            print('Error fetching library details: $e');
            setState(() {
              _currentLibraryName = 'Unknown Library';
            });
          }
        }
      } else {
        // No status found - set default values but don't check check-in status
        setState(() {
          _isCheckedIn = false;
          _currentLibraryId = '';
          _currentLibraryName = '';
          _currentSeatId = '';
          _shiftId = '';
          _shiftStartTime = '';
          _shiftEndTime = '';
          _dueDate = '';
          _fee = 0.0;
          _paymentStatus = '';
          _shiftCount = 0;
          _checkInTime = null;
          _checkOutTime = null;
        });
      }
    } catch (e) {

      // In case of error, clear status but don't change check-in state
      setState(() {
        _currentLibraryId = '';
        _currentLibraryName = 'Error fetching data';
        _currentSeatId = '';
        _currentBookingId = '';
      });
    } finally {
      setState(() {
        _isLoadingCurrentStatus = false;
      });
    }
  }

  // Fetch all libraries and separate joined ones
  Future<void> _fetchNearbyLibraries() async {
    try {
      setState(() {
        _isLoadingLibraries = true;
        _errorMessage = '';
      });

      // Get all active libraries from Firestore
      final querySnapshot = await _firestore
          .collection('libraries')
          .where('status', isEqualTo: 'active')
          .get();


      // Parse all libraries
      final tempAllLibraries = querySnapshot.docs.map((doc) {
        // Use the factory constructor to create LibraryModel from Firestore document
        return LibraryModel.fromMap(doc.data(), doc.id);
      }).toList();

      // Filter for joined libraries
      final joinedSnapshot = await _database
          .ref('${SmartLib.constPath}/students/${SmartLib.userId}/joinedLibraries')
          .get();

      final List<LibraryModel> joinedLibraries = [];

      if (joinedSnapshot.exists) {
        final Map<dynamic, dynamic> joinedMap = joinedSnapshot.value as Map<dynamic, dynamic>;
        final Set<String> joinedIds = joinedMap.keys.map((key) => key.toString()).toSet();

        // Extract joined libraries
        joinedLibraries.addAll(
            tempAllLibraries.where(
                  (library) => library.id != null && joinedIds.contains(library.id),
            )
        );

        // Calculate distance for each library
        final List<_LibraryWithDistance> nearbyLibraries = tempAllLibraries.map((lib) {
          final lat = double.tryParse(lib.locationLatitude ?? '') ?? 0.0;
          final lon = double.tryParse(lib.locationLongitude ?? '') ?? 0.0;
          final dist = _calculateDistance(_studentLat, _studentLon, lat, lon);
          return _LibraryWithDistance(library: lib, distanceKm: dist);
        }).toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

        // Remove joined libraries from all libraries list to prevent duplication
        final allNotJoined = tempAllLibraries.where(
              (library) => library.id != null && !joinedIds.contains(library.id),
        ).toList();

        setState(() {
          _allLibraries = allNotJoined;
          _joinedLibraries = joinedLibraries;
          _nearbyLibrariesWithDistance = nearbyLibraries;
          _isLoadingLibraries = false;
        });
      } else {
        // No joined libraries, just calculate distances
        final List<_LibraryWithDistance> nearbyLibraries = tempAllLibraries.map((lib) {
          final lat = double.tryParse(lib.locationLatitude ?? '') ?? 0.0;
          final lon = double.tryParse(lib.locationLongitude ?? '') ?? 0.0;
          final dist = _calculateDistance(_studentLat, _studentLon, lat, lon);
          return _LibraryWithDistance(library: lib, distanceKm: dist);
        }).toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

        setState(() {
          _allLibraries = tempAllLibraries;
          _joinedLibraries = [];
          _nearbyLibrariesWithDistance = nearbyLibraries;
          _isLoadingLibraries = false;
        });
      }
    } catch (e) {
      print('Error fetching libraries: $e');
      setState(() {
        _isLoadingLibraries = false;
        _errorMessage = 'Failed to load libraries. Please try again.';
      });
    }
  }


  // Fetch seat booking history from Realtime Database
  Future<void> _fetchSeatHistory() async {
    if (_userId == null) return;

    try {
      setState(() {
        _isLoadingHistory = true;
      });

      // Get booking history from Realtime Database
      DatabaseEvent event = await _database
          .ref()
          .child('${SmartLib.constPath}/students/$_userId/seatBookings')
          .limitToLast(5)
          .once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> bookings = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> history = [];

        // Process each booking
        for (var entry in bookings.entries) {
          final bookingId = entry.key.toString();

          // Fetch detailed booking info from Firestore
          try {
            final bookingDoc = await _firestore
                .collection('seatBookings')
                .doc(bookingId)
                .get();

            if (bookingDoc.exists) {
              final bookingData = bookingDoc.data()!;

              // Get library name from library ID
              String libraryName = 'Unknown Library';
              if (bookingData['libraryId'] != null) {
                final libraryDoc = await _firestore
                    .collection('libraries')
                    .doc(bookingData['libraryId'])
                    .get();

                if (libraryDoc.exists) {
                  libraryName = libraryDoc.data()?['libraryName'] ?? 'Unknown Library';
                }
              }

              // Calculate duration if check-in and check-out times exist
              String duration = 'N/A';
              if (bookingData['checkInTime'] != null && bookingData['checkOutTime'] != null) {
                final checkInTime = _parseDateTime(bookingData['checkInTime']);
                final checkOutTime = _parseDateTime(bookingData['checkOutTime']);

                if (checkInTime != null && checkOutTime != null) {
                  final diff = checkOutTime.difference(checkInTime);
                  final hours = diff.inHours;
                  final mins = diff.inMinutes.remainder(60);
                  duration = '${hours}h ${mins}m';
                }
              }

              history.add({
                'id': bookingData['seatNo'] ?? 'Unknown',
                'library': libraryName,
                'date': bookingData['date'] ?? '',
                'duration': duration,
                'status': bookingData['status'] ?? 'completed',
                'bookingId': bookingId,
              });
            }
          } catch (e) {
            print('Error fetching booking details for $bookingId: $e');
          }
        }

        // Sort by most recent
        history.sort((a, b) {
          final aDate = a['date'] as String;
          final bDate = b['date'] as String;
          return bDate.compareTo(aDate);
        });

        setState(() {
          _seatHistory = history;
        });
      }
    } catch (e) {
      print('Error fetching seat history: $e');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  // Helper to parse date-time string
  DateTime? _parseDateTime(String? dateTimeString) {
    if (dateTimeString == null) return null;

    try {
      // Try to parse the date-time string
      return DateTime.parse(dateTimeString);
    } catch (e) {
      // If parsing fails, return null
      return null;
    }
  }

  // Haversine formula to calculate distance between two points (in km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  // Generates a color for each library based on its id or name
  Color _getColorForLibrary(LibraryModel library) {
    final seed = library.id?.hashCode ?? library.libraryName?.hashCode ?? 0;
    final colors = [
      Color(0xFF1E88E5), // Blue
      Color(0xFF43A047), // Green
      Color(0xFFE53935), // Red
      Color(0xFF8E24AA), // Purple
      Color(0xFFEF6C00), // Orange
      Color(0xFF00ACC1), // Cyan
    ];
    return colors[seed % colors.length];
  }

  // Format time of day
  String _formatTimeOfDay(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = Theme.of(context).cardColor;

    return SafeArea(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Profile Row
              _buildProfileRow(textColor),

              Gap(20),

              // Current Status Card - Check-in status
              _isLoadingCurrentStatus
                  ? _buildLoadingCard(height: 200)
                  : _buildCurrentStatusCard(width),

              Gap(20),

              // Study Statistics Section
              _buildStudyStatsSection(textColor, cardColor),

              Gap(20),

              // Nearby Libraries Section
              _isLoadingLibraries
                  ? _buildLoadingCard(height: 210)
                  : _buildNearbyLibrariesSection(width, textColor, context, _nearbyLibrariesWithDistance),

              Gap(20),

              // Recent Seat History
              _isLoadingHistory
                  ? _buildLoadingCard(height: 240)
                  : _buildSeatHistorySection(textColor, cardColor),

              Gap(20),
            ],
          ),
        ),
      ),
    );
  }

  // Loading placeholder
  Widget _buildLoadingCard({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xff1940CC),
        ),
      ),
    );
  }

  // Profile Row with Greeting
  Widget _buildProfileRow(Color textColor) {
    String greeting = _getGreeting();

    // Get first name for display
    String displayName = _userName;
    if (displayName.contains(' ')) {
      displayName = displayName.split(' ')[0]; // Get first name
    }
    // Limit display name length to prevent overflow
    if (displayName.length > 12) {
      displayName = displayName.substring(0, 12) + '...';
    }

    // Extract first letter of name for avatar
    String avatarText = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile and Greeting
         Row(
          children: [
            InkWell(
              onTap: () {
                // Navigate to student card page when profile is tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentCardPage(),
                  ),
                );
              },
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xff6C63FF), Color(0xff1940CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xff1940CC).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Center(
                  child: _userData['photoURL'] != null && _userData['photoURL'].toString().isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(
                      _userData['photoURL'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Text(
                        avatarText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                      : Text(
                    avatarText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
                Text(
                  "$displayName 👋",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),

        // Notification with badge
        GestureDetector(
          onTap: () {
            // Navigate to notification center
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationCenterScreen(
                studentId: _userId ?? '',
              )),
            );
          },
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
              Container(
                height: 12,
                width: 12,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF121212), width: 2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Advanced Student Detail Current Status Card - Enhanced without check-in restriction
  Widget _buildCurrentStatusCard(double width) {

    // Has data flag - check if we have meaningful data to display
    final hasData = _currentLibraryId.isNotEmpty || _currentSeatId.isNotEmpty || _shiftId.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      shadowColor: Color(0xff1940CC).withOpacity(0.4),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff1940CC), Color(0xff4169E1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Background design elements
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              left: -15,
              bottom: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and refresh button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status icon and label
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(
                              hasData ? Icons.account_balance_rounded : Icons.book_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentLibraryName.isNotEmpty
                                    ? _currentLibraryName
                                    : "Library Status",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "UID: ${_userId ?? 'studentId'}",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Refresh button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            onPressed: () {
                              // Refresh status data
                              _fetchCurrentStatus();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Refreshing your status...'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: Icon(Icons.refresh, color: Color(0xff1940CC)),
                            tooltip: "Refresh Status",
                          ),
                        ),
                      ),
                    ],
                  ),

                  Gap(16),

                  // Show status - always show available data
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status indicator with check-in status
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isCheckedIn ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isCheckedIn ? Colors.green : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isCheckedIn ? Icons.check_circle : Icons.info_outline,
                              color: _isCheckedIn ? Colors.green : Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              _isCheckedIn ? "Checked In" : "Not Checked In",
                              style: TextStyle(
                                color: _isCheckedIn ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Gap(16),

                      // Seat and shift info card
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Current Booking Details",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Gap(8),

                            // Seat information - show any available info
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEnhancedInfoRow(
                                    "Seat:",
                                    _currentSeatId.isNotEmpty ? _currentSeatId : "Not assigned",
                                    Icons.event_seat,
                                  ),
                                ),
                                Expanded(
                                  child: _buildEnhancedInfoRow(
                                    "Shift:",
                                    _shiftId.isNotEmpty ? _shiftId : "No shift",
                                    Icons.schedule,
                                  ),
                                ),
                              ],
                            ),
                            Gap(8),

                            // Shift times if available
                            if (_shiftStartTime.isNotEmpty && _shiftEndTime.isNotEmpty)
                              _buildEnhancedInfoRow(
                                "Time:",
                                "$_shiftStartTime - $_shiftEndTime",
                                Icons.access_time,
                              ),

                            // Due date if available
                            if (_dueDate.isNotEmpty)
                              _buildEnhancedInfoRow(
                                "Due:",
                                _dueDate,
                                Icons.event,
                              ),

                            // Fee and payment status if available
                            if (_fee > 0)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildEnhancedInfoRow(
                                      "Fee:",
                                      "₹$_fee",
                                      Icons.monetization_on,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildEnhancedInfoRow(
                                      "Payment:",
                                      _paymentStatus.isEmpty ? "Not paid" : _paymentStatus,
                                      Icons.payment,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                    ],
                  ),

                  // Time information at bottom
                  Gap(16),
                  Divider(color: Colors.white38, height: 1),
                  Gap(12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                          SizedBox(width: 6),
                          Text(
                            _shiftCount > 1 ? "$_shiftCount shifts booked" :
                            _shiftCount == 1 ? "1 shift booked" : "No shifts booked",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.white70, size: 16),
                          SizedBox(width: 6),
                          Text(
                            _isCheckedIn ? "Just checked in" : "Not checked in",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Enhanced info row with icon
  Widget _buildEnhancedInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white70,
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


// Study stats section with dynamic heights based on content
  Widget _buildStudyStatsSection(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Study Statistics",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Gap(15),

        // Use FutureBuilder without fixed height container
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchStudyStats(),
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200, // Only fixed height for loading state
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xff1940CC),
                  ),
                ),
              );
            }

            // Error state
            if (snapshot.hasError) {
              return Container(
                height: 180, // Only fixed height for error state
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                      SizedBox(height: 8),
                      Text(
                        "Error loading statistics",
                        style: TextStyle(color: textColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Get stats from snapshot
            final stats = snapshot.data ?? {
              'weeklyHours': 0.0,
              'longestDay': 0,
              'streak': 0,
              'dailyHours': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            };

            // Format data for display
            final weeklyHours = (stats['weeklyHours'] as double).toStringAsFixed(0) + 'h';
            final longestDayMins = stats['longestDay'] as int;
            final longestDayHours = (longestDayMins / 60).floor();
            final longestDayMinutes = longestDayMins % 60;
            final longestDayStr = longestDayHours > 0
                ? '${longestDayHours}h ${longestDayMinutes}m'
                : '$longestDayMinutes mins';
            final streak = (stats['streak'] as int).toString();

            // Prepare bar chart data
            final List<dynamic> rawDailyHours = stats['dailyHours'] as List<dynamic>;
            final List<double> dailyMinutes = List<double>.from(rawDailyHours);

            // Find maximum for normalization
            double maxDailyMinutes = dailyMinutes.isEmpty ? 60.0 :
            dailyMinutes.reduce((a, b) => max(a, b));
            if (maxDailyMinutes < 10.0) maxDailyMinutes = 60.0; // Minimum display value

            // Calculate normalized values and display hours
            final List<double> normalizedValues =
            dailyMinutes.map((minutes) => minutes / maxDailyMinutes).toList();
            final List<int> displayHours =
            dailyMinutes.map((minutes) => (minutes / 60).round()).toList();

            // Day labels
            final List<String> dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
            final today = DateTime.now().weekday - 1; // 0=Monday, 6=Sunday

            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Chart title and subtitle (optional)
                  // Weekly hours chart - now with LayoutBuilder
                  LayoutBuilder(
                      builder: (context, constraints) {
                        // Available width for chart
                        final availableWidth = constraints.maxWidth;
                        // Fixed bar width based on available width
                        final barWidth = (availableWidth / 9); // 7 days + some padding

                        return Container(
                          height: 100, // Fixed height for chart area only
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (index) {
                              final hours = index < displayHours.length ?
                              displayHours[index] : 0;
                              final value = index < normalizedValues.length ?
                              normalizedValues[index] : 0.0;
                              final isHighlighted = index == today;

                              // Safe bar height calculation
                              final double barHeight = value * 60.0;

                              return Container(
                                width: barWidth * 0.8, // Leave some space between bars
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: barWidth * 0.6,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isHighlighted
                                              ? [Color(0xff1940CC), Color(0xff2D5BFF)]
                                              : [Color(0xff1940CC).withOpacity(0.3), Color(0xff2D5BFF).withOpacity(0.3)],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      dayLabels[index],
                                      style: TextStyle(
                                        color: isHighlighted ? Color(0xff1940CC) : textColor.withOpacity(0.7),
                                        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      hours > 0 ? "${hours}h" : "-",
                                      style: TextStyle(
                                        color: isHighlighted ? Color(0xff1940CC) : textColor.withOpacity(0.5),
                                        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        );
                      }
                  ),

                  Gap(15),
                  Divider(height: 1, color: textColor.withOpacity(0.1)),
                  Gap(15),

                  // Stats summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatsItem(
                        value: weeklyHours,
                        label: "This Week",
                        icon: Icons.access_time,
                        color: Color(0xff1940CC),
                        textColor: textColor,
                      ),
                      _buildStatsItem(
                        value: longestDayStr,
                        label: "Longest Day",
                        icon: Icons.bar_chart,
                        color: Color(0xff9C49F5),
                        textColor: textColor,
                      ),
                      _buildStatsItem(
                        value: streak,
                        label: "Day Streak",
                        icon: Icons.local_fire_department,
                        color: Color(0xFFFF5E7C),
                        textColor: textColor,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

// Improved stats item with proper spacing
  Widget _buildStatsItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

// Function to fetch study statistics from Firestore
  Future<Map<String, dynamic>> _fetchStudyStats() async {
    try {
      // Default result
      final result = {
        'weeklyHours': 0.0, // Total hours studied this week
        'longestDay': 0,    // Longest session in minutes
        'streak': 0,        // Consecutive days with activity
        'dailyHours': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], // Minutes per day of the week
      };

      if (_userId == null) return result;

      // Get the start of current week (Monday)
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekStr = DateFormat('yyyy-MM-dd').format(startOfWeek);

      // Get dates for the last 14 days to calculate streak
      final dateFormat = DateFormat('yyyy-MM-dd');
      final last14Days = List.generate(14, (i) =>
          dateFormat.format(now.subtract(Duration(days: i)))
      );

      // Initialize counters
      double weeklyMinutes = 0.0;
      int longestDaySoFar = 0;
      int streak = 0;
      bool streakBroken = false;
      List<double> dailyMinutes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      // Process each day
      for (int i = 0; i < last14Days.length; i++) {
        final date = last14Days[i];

        // Get attendance records for this day
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendanceHistory')
            .doc(date)
            .collection('records')
            .where('studentId', isEqualTo: _userId)
            .get();

        // Skip to next day if no records found
        if (attendanceSnapshot.docs.isEmpty) {
          if (i < 7) {
            // For streak calculation
            if (i == 0) {
              // Today counts as part of streak only if we have records
              continue;
            } else {
              streakBroken = true;
            }
          }
          continue;
        }

        // Calculate total minutes for this day
        int totalMinutes = 0;

        // Process each record from this day
        for (final doc in attendanceSnapshot.docs) {
          final data = doc.data();

          // Get duration if available directly
          if (data['duration'] != null) {
            try {
              totalMinutes += int.parse(data['duration'].toString());
            } catch (e) {
              // Handle parsing error
            }
          }
          // Otherwise calculate from check-in and check-out times
          else if (data['checkInTime'] != null && data['checkOutTime'] != null) {
            try {
              final checkIn = DateTime.parse(data['checkInTime'].toString());
              final checkOut = DateTime.parse(data['checkOutTime'].toString());
              totalMinutes += checkOut.difference(checkIn).inMinutes;
            } catch (e) {
              // Handle parsing error
            }
          }
        }

        // Update stats
        if (i < 7) {
          // This is within the current week
          weeklyMinutes += totalMinutes;

          // Update daily hours - ensure day of week is valid
          try {
            final dayOfWeek = DateTime.parse(date).weekday - 1; // 0-based (0 = Monday)
            if (dayOfWeek >= 0 && dayOfWeek < 7) {
              dailyMinutes[dayOfWeek] = totalMinutes.toDouble();
            }
          } catch (e) {
            print('Error parsing date for daily hours: $e');
          }
        }

        // Update longest day
        if (totalMinutes > longestDaySoFar) {
          longestDaySoFar = totalMinutes;
        }

        // Update streak
        if (i > 0 && !streakBroken) {
          streak++;
        }
      }

      // Populate result map
      result['weeklyHours'] = weeklyMinutes / 60; // Convert minutes to hours
      result['longestDay'] = longestDaySoFar;
      result['streak'] = streak;
      result['dailyHours'] = dailyMinutes; // Store as minutes

      return result;

    } catch (e) {
      print("Error fetching study statistics: $e");
      // Return default values on error
      return {
        'weeklyHours': 0.0,
        'longestDay': 0,
        'streak': 0,
        'dailyHours': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      };
    }
  }

  // Modify the _buildNearbyLibrariesSection function

  Widget _buildNearbyLibrariesSection(
      double width,
      Color textColor,
      BuildContext context,
      List<_LibraryWithDistance> allLibraries,
      ) {
    // First, filter out joined libraries
    final Set<String> joinedLibraryIds = _joinedLibraries
        .where((lib) => lib.id != null)
        .map((lib) => lib.id!)
        .toSet();

    // Create a filtered list excluding joined libraries
    final List<_LibraryWithDistance> nonJoinedLibraries = allLibraries
        .where((libWithDist) =>
    libWithDist.library.id == null ||
        !joinedLibraryIds.contains(libWithDist.library.id))
        .toList();

    // Now use nonJoinedLibraries for the ListView
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Nearest Libraries",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LibraryMarketplace(isSignedUp: false),
                  ),
                );
              },
              child: Text(
                "View All",
                style: TextStyle(
                  color: Color(0xff2D5BFF),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        Gap(10),
        Container(
          height: 245, // Height increased slightly to prevent overflow
          child: nonJoinedLibraries.isEmpty
              ? Center(child: Text("No libraries found nearby", style: TextStyle(color: textColor.withOpacity(0.7))))
              : ListView.builder(
            physics: BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: nonJoinedLibraries.length,
            itemBuilder: (context, index) {
              final libWithDistance = nonJoinedLibraries[index];
              final lib = libWithDistance.library;
              final color = _getColorForLibrary(lib);

              // Calculate values
              final availableSeats = lib.availableSeats ?? 0;
              final totalSeats = lib.totalSeats ?? 1;
              final isOpen = availableSeats > 0;
              final isPopular = (lib.students ?? 0) > 20;

              // Function to safely get address or location
              String getLocation() {
                if (libWithDistance.distanceKm != null) {
                  return "${libWithDistance.distanceKm.toStringAsFixed(1)} km";
                } else if (lib.address != null && lib.address!['city'] != null) {
                  return lib.address!['city'].toString();
                } else {
                  return lib.location ?? 'No location';
                }
              }

              return Container(
                width: width * 0.7,
                margin: EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                padding: EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Library info
                    Row(
                      children: [
                        Container(
                          height: 60,
                          width: 60,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            image: lib.libraryImageUrl != null
                                ? DecorationImage(
                              image: NetworkImage(lib.libraryImageUrl!),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: lib.libraryImageUrl == null
                              ? Center(
                            child: Icon(
                              Icons.apartment,
                              color: color,
                              size: 25,
                            ),
                          )
                              : null,
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lib.libraryName ?? 'Unnamed Library',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: textColor.withOpacity(0.7),
                                    size: 14,
                                  ),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      getLocation(),
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Status tags
                    SizedBox(height: 10),
                    Row(
                      children: [
                        // Open/Closed status tag
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              color: isOpen ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),

                        // Popular tag if applicable
                        if (isPopular)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Popular',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        Spacer(),

                        // Rating
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 3),
                            Text(
                              (lib.rating ?? 0.0).toStringAsFixed(1),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              " (${lib.reviews ?? 0})",
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    // Availability info
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$availableSeats seats available",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 5),
                              // Use Stack-based progress bar like in the example
                              Container(
                                height: 6,
                                width: width * 0.7 - 30,
                                decoration: BoxDecoration(
                                  color: textColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: math.min((availableSeats / math.max(1, totalSeats)) * (width * 0.7 - 30), width * 0.7 - 30),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "out of $totalSeats total seats",
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Fee display and Book button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price if available
                        if (lib.lowFee != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber),
                              color: Colors.white.withOpacity(0.05),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  "₹${lib.lowFee}",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "/month",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(), // Empty spacer if no fee

                        // Book button
                        GestureDetector(
                          onTap: widget.onBookSeatPressed,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                "Book a Seat",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // Seat History Section (updated to use real data)
  Widget _buildSeatHistorySection(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Sessions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "See All",
                style: TextStyle(
                  color: Color(0xff2D5BFF),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        Gap(10),
        //seat booking history
        _seatHistory.isEmpty
            ? Container(
          height: 100,
          alignment: Alignment.center,
          child: Text(
            "No recent booking history",
            style: TextStyle(color: textColor.withOpacity(0.7)),
          ),
        )
            : Column(
          children: _seatHistory.map((session) {
            return Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: Color(0xff1940CC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        session['id']?.toString() ?? 'NA',
                        style: TextStyle(
                          color: Color(0xff1940CC),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['library']?.toString() ?? 'Unknown Library',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: textColor.withOpacity(0.7),
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              _formatDate(session['date']?.toString() ?? ''),
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.access_time,
                              color: textColor.withOpacity(0.7),
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              session['duration']?.toString() ?? 'N/A',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Color(0xff43A047).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _formatStatus(session['status']?.toString() ?? 'Unknown'),
                      style: TextStyle(
                        color: Color(0xff43A047),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Format status for display
  String _formatStatus(String status) {
    if (status == 'confirmed') return 'Active';
    if (status == 'completed') return 'Completed';
    if (status == 'cancelled' || status == 'canceled') return 'Cancelled';
    if (status.isEmpty) return 'Unknown';
    return status.substring(0, 1).toUpperCase() + status.substring(1);
  }

  // Fixed Bar Chart Item to prevent overflow
  Widget _buildBarChartItem(
      String label,
      double value,
      int hours,
      Color textColor,
      {bool isHighlighted = false}
      ) {
    // Ensure value is between 0.0 and 1.0 to prevent overflow
    value = value.clamp(0.0, 1.0);

    // Maximum height allowed for the bar to prevent overflow
    const double maxBarHeight = 75;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min, // Use min size to prevent expansion
      children: [
        Container(
          width: 25,
          height: value * maxBarHeight, // Constrain height to prevent overflow
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isHighlighted
                  ? [Color(0xff1940CC), Color(0xff2D5BFF)]
                  : [Color(0xff1940CC).withOpacity(0.3), Color(0xff2D5BFF).withOpacity(0.3)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
        Gap(8),
        Text(
          label,
          style: TextStyle(
            color: isHighlighted ? Color(0xff1940CC) : textColor.withOpacity(0.7),
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            fontSize: 12, // Smaller font size to help prevent overflow
          ),
        ),
        SizedBox(height: 4),
        // Always show hours, even for non-highlighted bars
        Text(
          hours > 0 ? "${hours}h" : "-", // Show dash if zero hours
          style: TextStyle(
            color: isHighlighted ? Color(0xff1940CC) : textColor.withOpacity(0.5),
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            fontSize: isHighlighted ? 12 : 10, // Smaller for non-highlighted
          ),
        ),
      ],
    );
  }



  // Get greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning,";
    } else if (hour < 17) {
      return "Good Afternoon,";
    } else {
      return "Good Evening,";
    }
  }

  // Format date for display
  String _formatDate(String date) {
    if (date.isEmpty) return 'N/A';
    final parts = date.split('-');
    if (parts.length >= 3) {
      return "${parts[1]}/${parts[2]}";
    }
    return date;
  }
}

// Helper class for sorted library list with distances
class _LibraryWithDistance {
  final LibraryModel library;
  final double distanceKm;
  _LibraryWithDistance({required this.library, required this.distanceKm});
}