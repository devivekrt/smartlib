import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smartlib/data/string.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

class StudentCardPage extends StatefulWidget {
  const StudentCardPage({Key? key}) : super(key: key);

  @override
  State<StudentCardPage> createState() => _StudentCardPageState();
}

class _StudentCardPageState extends State<StudentCardPage> with SingleTickerProviderStateMixin {

  // Student data
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _currentStatus = {};
  List<Map<String, dynamic>> _registeredLibraries = [];

  // Card properties
  final double _cardAspectRatio = 1.586; // Standard ID card aspect ratio
  bool _isLoading = true;
  bool _showQrCode = false;

  // Animation controller for flipping card
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Create animation
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );

    _loadStudentData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Load student data - FIXED VERSION
  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = SmartLib.userId;

      // First load student profile data
      final userRef = FirebaseDatabase.instance.ref().child('users/students/$userId');
      final userSnapshot = await userRef.get();

      if (userSnapshot.exists) {
        // Convert dynamic to typed
        final Map<dynamic, dynamic> userData = userSnapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> typedUserData = {};

        // Convert all data to strings
        userData.forEach((key, value) {
          if (key != 'currentStatus') {
            typedUserData[key.toString()] = value;
          }
        });

        // Get current status separately
        final statusRef = FirebaseDatabase.instance.ref().child('users/students/$userId/currentStatus');
        final statusSnapshot = await statusRef.get();

        Map<String, dynamic> currentStatus = {};
        if (statusSnapshot.exists) {
          final Map<dynamic, dynamic> statusData = statusSnapshot.value as Map<dynamic, dynamic>;

          // Convert all status data to strings
          statusData.forEach((key, value) {
            currentStatus[key.toString()] = value;
          });

          print("Current Status Data: $currentStatus"); // Debug print
        }

        setState(() {
          _userData = typedUserData;
          _currentStatus = currentStatus;
          _isLoading = false;
        });

        print("User Data: $_userData"); // Debug print
      } else {
        print("User data not found in database"); // Debug print


      }
    } catch (e) {
      print('Error loading student data: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading student data: $e')),
      );
    }
  }



  // Format date
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Generate QR code data
  String _generateQrData() {
    final userId = SmartLib.userId;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Format: userId_SMARTCARD_timestamp
    return '$userId\_SMARTCARD_$timestamp';
  }

  // Update to include real-time listener for status changes
  void _setupRealtimeUpdates() {
    final userId = SmartLib.userId;

    FirebaseDatabase.instance
        .ref()
        .child('users/students/$userId/currentStatus')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> statusData = event.snapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> currentStatus = {};

        statusData.forEach((key, value) {
          currentStatus[key.toString()] = value;
        });

        setState(() {
          _currentStatus = currentStatus;
        });

        print("Status updated in real-time: $_currentStatus"); // Debug print
      }
    }, onError: (error) {
      print("Error in real-time updates: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardShadowColor = isDarkMode ? Colors.black54 : Colors.black26;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Card',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Instructions
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xff1940CC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xff1940CC).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xff1940CC),
                          size: 24,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Digital Student Card',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xff1940CC),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap the card to see more details. Show this card to access library facilities.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Gap(20),

                  // Student Card
                  GestureDetector(
                    onTap: () {
                      if (_showQrCode) {
                        // Don't flip when QR code is showing
                        return;
                      }

                      if (_animationController.isAnimating) {
                        return;
                      }

                      if (_animationController.value == 0) {
                        _animationController.forward();
                      } else {
                        _animationController.reverse();
                      }
                    },
                    child: AspectRatio(
                      aspectRatio: _cardAspectRatio,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final double value = _animation.value;
                          final bool isFrontVisible = value < 0.5;

                          // Calculate rotation angle for card flip
                          final angle = isFrontVisible
                              ? math.pi * value
                              : math.pi * (1 - value);

                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(math.pi * value),
                            alignment: Alignment.center,
                            child: isFrontVisible
                                ? _buildFrontCard(textColor, cardShadowColor)
                                : Transform(
                              transform: Matrix4.identity()..rotateY(math.pi),
                              alignment: Alignment.center,
                              child: _buildBackCard(textColor, cardShadowColor),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  Gap(20),


                  // Registered Libraries
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: cardShadowColor,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Registered Libraries',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xff1940CC).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_registeredLibraries.length}',
                                style: TextStyle(
                                  color: Color(0xff1940CC),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Gap(10),

                        // Library list
                        ..._registeredLibraries.map((library) => _buildLibraryItem(library, textColor)).toList(),

                        if (_registeredLibraries.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.library_books_outlined,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No registered libraries yet',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Gap(20),

                  // Current Status
                  if (_currentStatus.isNotEmpty && _currentStatus['isCheckedIn'] == true)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xff1940CC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xff1940CC).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Currently Checked In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      'Library: ${_currentStatus["currentLibraryId"]}',
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Gap(10),
                          Divider(),
                          Gap(10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatusDetail(
                                label: 'Seat',
                                value: _currentStatus['currentSeatNo']?.toString() ?? 'N/A',
                                icon: Icons.chair,
                              ),
                              _buildStatusDetail(
                                label: 'Check-in Time',
                                value: _currentStatus['checkInTime']?.toString() ?? 'N/A',
                                icon: Icons.access_time,
                              ),
                              _buildStatusDetail(
                                label: 'Shift',
                                value: _currentStatus['shiftName']?.toString() ?? 'N/A',
                                icon: Icons.schedule,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  Gap(30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Rest of your methods (remaining with same implementation)...
  // Build front side of student card
  Widget _buildFrontCard(Color textColor, Color shadowColor) {
    final String studentName = _userData['fullName'] ?? _userData['name'] ?? 'Student Name';
    final String studentId = SmartLib.userId;
    final String department = _userData['department'] ?? 'Department';
    final String profileUrl = _userData['profileImageUrl'] ?? _userData['profilePic'] ?? '';

    // Extract first letter of each name part for initials
    final nameParts = studentName.split(' ');
    String initials = '';
    for (var part in nameParts) {
      if (part.isNotEmpty) {
        initials += part[0];
      }
      if (initials.length >= 2) break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background patterns
          Positioned(
            right: -50,
            bottom: -50,
            child: Opacity(
              opacity: 0.1,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: -30,
            child: Opacity(
              opacity: 0.05,
              child: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Card content
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDENT ID CARD',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          SmartLib.libraryName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png', // Replace with actual logo
                        width: 30,
                        height: 30,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.school,
                          size: 30,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),

                Expanded(
                  child: Center(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile picture
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: profileUrl.isNotEmpty
                              ? ClipOval(
                            child: Image.network(
                              profileUrl,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ),
                          )
                              : Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20),

                        // Student info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                studentName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8),
                              _buildInfoText('ID', studentId),
                              _buildInfoText('Department', department),
                              SizedBox(height: 10),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expires: 12/31/2025',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Tap to flip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.flip,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
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
    );
  }

  // Build back side of student card - FIXED to prevent overflow
  Widget _buildBackCard(Color textColor, Color shadowColor) {
    final String studentName = _userData['fullName'] ?? _userData['name'] ?? 'Student Name';
    final String studentId = SmartLib.userId;
    final String qrData = '$studentId\_SMARTCARD';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background patterns
          Positioned(
            left: -50,
            bottom: -50,
            child: Opacity(
              opacity: 0.1,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            right: -30,
            top: -30,
            child: Opacity(
              opacity: 0.05,
              child: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Card content - FIXED LAYOUT
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header - using less vertical space
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Student Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14, // Smaller font
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8), // Smaller padding
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school,
                        size: 18, // Smaller icon
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20), // Fixed spacing

                // QR Code with name - smaller QR code
                Container(
                  width: 100, // Smaller QR code
                  height: 100, // Smaller QR code
                  padding: EdgeInsets.all(4), // Less padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xff1E3A8A),
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xff1E3A8A),
                    ),
                  ),
                ),

                const SizedBox(height: 10), // Less space

                // Student ID
                Text(
                  'ID: $studentId',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10), // Fixed space


                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Issued: 01/01/2023',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10, // Smaller font
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Tap to flip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 10, // Smaller font
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.flip,
                          size: 12, // Smaller icon
                          color: Colors.white.withOpacity(0.9),
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
    );
  }

  // Build library item in the list
  Widget _buildLibraryItem(Map<String, dynamic> library, Color textColor) {
    final String libraryName = library['libraryName'] ?? library['name'] ?? 'Unknown Library';
    final String libraryId = library['libraryId'] ?? '';
    final bool isCurrentLibrary = _currentStatus.isNotEmpty &&
        _currentStatus['currentLibraryId'] == libraryId;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentLibrary
            ? Color(0xff1940CC).withOpacity(0.1)
            : Colors.transparent,
        border: Border.all(
          color: isCurrentLibrary
              ? Color(0xff1940CC)
              : Colors.grey.withOpacity(0.3),
          width: isCurrentLibrary ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrentLibrary
                  ? Color(0xff1940CC).withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book,
              color: isCurrentLibrary ? Color(0xff1940CC) : Colors.grey,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libraryName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

              ],
            ),
          ),
          if (isCurrentLibrary)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'CURRENT',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build student info text for front of card
  Widget _buildInfoText(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  // Build current status detail
  Widget _buildStatusDetail({required String label, required String value, required IconData icon}) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Color(0xff1940CC),
            size: 20,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}