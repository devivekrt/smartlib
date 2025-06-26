import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:smartlib/student/seat_booking_screen.dart';
import 'package:smartlib/widgets/solid_button.dart';

import '../data/string.dart';
import 'main_tab_screen.dart';

class LibraryDetailScreen extends StatefulWidget {
  final LibraryModel library;
  final bool isJoined;
  final bool isSignedUp;

  const LibraryDetailScreen({
    Key? key,
    required this.library,
    this.isJoined = false,
    this.isSignedUp = false,
  }) : super(key: key);

  @override
  State<LibraryDetailScreen> createState() => _LibraryDetailScreenState();
}

class _LibraryDetailScreenState extends State<LibraryDetailScreen> {
  bool _favorite = false;
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isJoined = false;

  // Current user status
  bool _isBookedLibrary = false;
  String? _currentLibraryId;
  String? _currentLibraryName;

  @override
  void initState() {
    super.initState();
    _isJoined = widget.isJoined;
    _checkFavorite();
    _checkCurrentStatus();
  }

  // Check if user is already checked into a library
  Future<void> _checkCurrentStatus() async {
    try {
      final statusRef = FirebaseDatabase.instance
          .ref()
          .child("users/students/${SmartLib.userId}/currentStatus");

      final snapshot = await statusRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _isBookedLibrary = data['currentStatus'] == 'joined';
          _currentLibraryId = data['currentLibraryId']?.toString();
        });

        // If checked into another library, get the library name
        if (_isBookedLibrary && _currentLibraryId != null && _currentLibraryId != widget.library.id) {
          await _fetchCurrentLibraryName();
        }
      }
    } catch (e) {
      print("Error checking current status: $e");
    }
  }

  // Fetch the name of the library the user is currently checked into
  Future<void> _fetchCurrentLibraryName() async {
    try {
      if (_currentLibraryId == null) return;

      final libraryDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(_currentLibraryId)
          .get();

      if (libraryDoc.exists) {
        setState(() {
          _currentLibraryName = libraryDoc.data()?['libraryName'];
        });
      }
    } catch (e) {
      print("Error fetching current library name: $e");
    }
  }

  Future<void> _checkFavorite() async {
    try {
      final snapshot =
      await FirebaseDatabase.instance
          .ref(
        '${SmartLib.constPath}/students/${SmartLib.userId}/favorites',
      )
          .child(widget.library.id!)
          .get();

      setState(() {
        _favorite = snapshot.exists;
      });
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final ref = FirebaseDatabase.instance
          .ref('${SmartLib.constPath}/students/${SmartLib.userId}/favorites')
          .child(widget.library.id!);

      if (_favorite) {
        await ref.remove();
      } else {
        await ref.set({'timestamp': ServerValue.timestamp});
      }

      setState(() {
        _favorite = !_favorite;
      });
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update favorites')));
    }
  }

  // Updated method to check current status before joining library
  Future<void> _joinLibrary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if student is already checked into another library
      if (_isBookedLibrary && _currentLibraryId != null && _currentLibraryId != widget.library.id) {
        setState(() {
          _isLoading = false;
        });

        // Show an alert dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: DarkColor.cardColor,
            title: Text(
              'Already Checked In',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are currently checked in to ${_currentLibraryName ?? "another library"}.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 8),
                Text(
                  'You need to check out from your current library before booking a seat at ${widget.library.libraryName}.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You can check out by scanning the QR code at your current library or using the My Bookings screen.',
                          style: TextStyle(color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  // Here you could navigate to the bookings page
                  Navigator.pop(context);

                  // Optional: Navigate to My Bookings page here
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => MyBookingsScreen()));
                },
                child: Text('My Bookings'),
              ),
            ],
          ),
        );

        return;
      }

      // If not checked in or checked into this library, proceed with booking
      setState(() {
        _isLoading = false;
      });

      // Launch the seat booking flow
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeatBookingScreen(
            library: widget.library,
            userId: SmartLib.userId,
          ),
        ),
      );

      // Handle the result
      if (result != null && result is Map<String, dynamic>) {
        if (result['success'] == true) {
          setState(() {
            _isJoined = true;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your seat has been booked successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to bottom_navigation page if it's a signup flow
          if (widget.isSignedUp) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainTabScreen()),
                  (route) => false,
            );
          }
        }
      }
    } catch (e) {
      print('Error joining library: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getColorForLibrary(LibraryModel library) {
    // Generate a consistent color based on library name or ID
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

  // Convert shifts map to list of ShiftModel objects
  List<ShiftModel> _getShiftsFromMap() {
    final List<ShiftModel> shiftsList = [];

    // Check if library.shifts is a map
    if (widget.library.shifts is Map) {
      Map<String, dynamic> shiftsMap = Map<String, dynamic>.from(widget.library.shifts);

      shiftsMap.forEach((key, value) {
        if (value is Map) {
          final shiftData = Map<String, dynamic>.from(value);

          // Create ShiftModel from the shift data
          final shift = ShiftModel(
            shiftName: shiftData['shiftName'],
            startTime: shiftData['shiftStartTime'],
            endTime: shiftData['shiftEndTime'],
            fee: shiftData['shiftFee'] is int ? shiftData['shiftFee'] : int.tryParse(shiftData['shiftFee'].toString()),
          );

          shiftsList.add(shift);
        }
      });
    }

    return shiftsList;
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final library = widget.library;
    final Color libraryColor = _getColorForLibrary(library);
    final gradientBorder = LinearGradient(
      colors: [Color(0xff209CC9), Color(0xffF4C264)],
    );

    // Check if this is the library the user is currently checked into
    final isCurrentLibrary = _currentLibraryId == library.id;

    // Get shifts as a list
    final List<ShiftModel> shiftsList = _getShiftsFromMap();

    // Build full address from components
    String location = '';
    if (library.address != null) {
      final address = library.address!;
      if (address['street'] != null)
        location += address['street'].toString() + ', ';
      if (address['city'] != null)
        location += address['city'].toString() + ', ';
      if (address['state'] != null)
        location += address['state'].toString() + ' ';
      if (address['zipCode'] != null) location += address['zipCode'].toString();
      if (address['landMark'] != null &&
          address['landMark'].toString().isNotEmpty) {
        location += '\nNear ' + address['landMark'].toString();
      }
    } else if (library.location != null) {
      location = library.location!;
    }

    final String shortLocation =
    location.length > 70 ? location.substring(0, 70) + '...' : location;

    return SafeArea(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        // Replace the floating action button with this bottom navigation bar
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main action buttons
            Container(
              height: 80,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child:
              widget.isSignedUp
                  ? Row(
                children: [
                  // Skip button (goes to home)
                  Expanded(
                    child: Container(
                      height: 56,
                      margin: EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.orange, width: 2),
                        color: Colors.transparent,
                      ),
                      child: MaterialButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MainTabScreen(),
                            ),
                                (route) => false,
                          );
                        },
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Book button (join and go to home)
                  Expanded(
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors:
                          _isJoined || (_isBookedLibrary && !isCurrentLibrary)
                              ? [Colors.grey, Colors.grey.shade700]
                              : [Colors.orange, Colors.deepOrange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: MaterialButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        onPressed:
                        _isJoined || _isLoading || (_isBookedLibrary && !isCurrentLibrary)
                            ? null
                            : () async {
                          await _joinLibrary();
                          if (_isJoined) {
                            // After successful join, navigate to home
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SeatBookingScreen(library: library, userId: SmartLib.userId),
                              ),
                                  (route) => false,
                            );
                          }
                        },
                        child:
                        _isLoading
                            ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                            : Text(
                          _isJoined
                              ? "Already Booked"
                              : (_isBookedLibrary && !isCurrentLibrary)
                              ? "Check Out First"
                              : "Book Now",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  : Container(
                height: 56,
                width: width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors:
                    _isJoined || (_isBookedLibrary && !isCurrentLibrary)
                        ? [Colors.grey, Colors.grey.shade700]
                        : [Colors.orange, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: MaterialButton(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  onPressed: _isJoined || _isLoading || (_isBookedLibrary && !isCurrentLibrary)
                      ? null
                      : _joinLibrary,
                  child:
                  _isLoading
                      ? SizedBox(
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                      : Text(
                    _isJoined
                        ? "Already Joined"
                        : (_isBookedLibrary && !isCurrentLibrary)
                        ? "Check Out First"
                        : "Book a Seat",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        body: Stack(
          children: [
            // Main scrollable content
            SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero image and content
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Library image
                      Container(
                        height: height * 0.4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image:
                          library.libraryImageUrl != null
                              ? DecorationImage(
                            image: NetworkImage(
                              library.libraryImageUrl!,
                            ),
                            fit: BoxFit.cover,
                          )
                              : null,
                          color:
                          library.libraryImageUrl == null
                              ? Colors.grey[800]
                              : null,
                        ),
                        child:
                        library.libraryImageUrl == null
                            ? Center(
                          child: Icon(
                            Icons.apartment,
                            size: 80,
                            color: Colors.white54,
                          ),
                        )
                            : null,
                      ),

                      // Gradient overlay for contrast
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // White curved overlay
                      Positioned(
                        bottom: -1,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                        ),
                      ),

                      // Back and favorite buttons
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  if (widget.isSignedUp) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MainTabScreen(),
                                      ),
                                          (route) => false,
                                    );
                                  } else {
                                    Navigator.pop(
                                      context,
                                      _isJoined != widget.isJoined,
                                    );
                                  }
                                },
                              ),
                            ),

                            // Favorite button with animated effect
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _favorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _favorite ? Colors.red : Colors.white,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: _toggleFavorite,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Library name, rating, location at bottom of image
                      Positioned(
                        bottom: 45,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status badge section - now handling multiple states
                            if (_isJoined || _isBookedLibrary)
                              Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: (_isBookedLibrary && isCurrentLibrary)
                                      ? Colors.green.withOpacity(0.9)
                                      : (_isJoined
                                      ? Colors.blue.withOpacity(0.9)
                                      : Colors.amber.withOpacity(0.9)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (_isBookedLibrary && isCurrentLibrary)
                                          ? Icons.check_circle
                                          : (_isJoined
                                          ? Icons.check_circle
                                          : Icons.warning_amber),
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      (_isBookedLibrary && isCurrentLibrary)
                                          ? 'Currently Joined In'
                                          : (_isJoined
                                          ? 'Already Joined'
                                          : 'Checked In Elsewhere'),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Library name
                            Text(
                              library.libraryName ?? 'Unnamed Library',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            Gap(8),

                            // Rating with stars
                            Row(
                              children: [
                                // Star rating
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "${library.rating != null ? library.rating.toStringAsFixed(1) : '0'}/5.0",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Gap(8),

                                // Reviews count
                                Text(
                                  "${library.reviews ?? 0} reviews",
                                  style: TextStyle(
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 10),

                            // Location preview
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    getLocation(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 3,
                                        ),
                                      ],
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

                  // Main content with cards
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      10,
                      20,
                      100,
                    ), // Bottom padding for FAB
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Add warning message if checked into another library
                        if (_isBookedLibrary && !isCurrentLibrary) ...[
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 20),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Already Joined In",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "You're currently checked into ${_currentLibraryName ?? "another library"}. "
                                      "You must check out from there before booking a seat here.",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Fee and Established info in a row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Students enrolled
                            _buildInfoCard(
                              icon: Icons.people_alt_rounded,
                              title: "${library.students ?? 0}",
                              subtitle: "Students",
                              color: libraryColor,
                              width: width * 0.28,
                            ),

                            // Established Date
                            if (library.establishedDate != null)
                              _buildInfoCard(
                                icon: Icons.calendar_today_rounded,
                                title: "Est. ${library.establishedDate}",
                                subtitle: "Founded",
                                color: Colors.orange,
                                width: width * 0.32,
                              ),

                            // Fee
                            if (library.lowFee != null)
                              _buildInfoCard(
                                icon: Icons.currency_rupee_rounded,
                                title: "${library.lowFee}/mo",
                                subtitle: "Fee",
                                color: Colors.amber,
                                width: width * 0.28,
                              ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Amenities section with modern chips
                        if (library.utilities.isNotEmpty) ...[
                          _buildSectionHeader(
                            title: 'Available Amenities',
                            icon: Icons.stars_rounded,
                          ),
                          SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _buildUtilityChips(library, libraryColor),
                          ),
                          SizedBox(height: 24),
                        ],

                        // Location details card
                        _buildSectionHeader(
                          title: 'Location',
                          icon: Icons.location_on_rounded,
                        ),
                        Gap(12),
                        _buildInfoBox(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  text: _isExpanded ? location : shortLocation,
                                  children:
                                  location.length > 70
                                      ? [
                                    TextSpan(
                                      text:
                                      _isExpanded
                                          ? "  Show less"
                                          : "  Show more",
                                      style: TextStyle(
                                        color: libraryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          setState(() {
                                            _isExpanded =
                                            !_isExpanded;
                                          });
                                        },
                                    ),
                                  ]
                                      : [],
                                ),
                              ),

                              Gap(12),

                              // Map placeholder (can be replaced with actual map)
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.map_rounded,
                                        color: Colors.white70,
                                        size: 40,
                                      ),
                                      Gap(8),
                                      Text(
                                        "Map View",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Description
                        if (library.description != null &&
                            library.description!.isNotEmpty) ...[
                          _buildSectionHeader(
                            title: 'About this Library',
                            icon: Icons.info_rounded,
                          ),
                          Gap(12),
                          _buildInfoBox(
                            child: Text(
                              library.description!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                        ],

                        // Rules and regulations
                        if (library.rules.isNotEmpty) ...[
                          _buildSectionHeader(
                            title: 'Rules & Regulations',
                            icon: Icons.rule_rounded,
                          ),
                          Gap(12),
                          _buildInfoBox(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...library.rules.map(
                                      (rule) => _buildRuleItem(rule),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),
                        ],

                        // Shifts information - MODIFIED CODE HERE
                        if (library.shifts.isNotEmpty) ...[
                          _buildSectionHeader(
                            title: 'Operating Shifts',
                            icon: Icons.schedule_rounded,
                          ),
                          Gap(12),
                          ...shiftsList.map(
                                (shift) => _buildShiftItem(shift, libraryColor),
                          ),
                          SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Helper method to get a consistent location string
  String getLocation() {
    final library = widget.library;
    String location = '';

    if (library.address != null) {
      final address = library.address!;
      if (address['city'] != null) {
        location = address['city'].toString();
        if (address['state'] != null) {
          location += ', ' + address['state'].toString();
        }
      } else if (library.location != null) {
        location = library.location!;
      }
    } else if (library.location != null) {
      location = library.location!;
    } else {
      location = 'Location not specified';
    }

    return location;
  }

  // Helper method to build section headers
  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber, size: 22),
        Gap(8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Helper method to build info cards
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  // Helper method for consistent info boxes
  Widget _buildInfoBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarkColor.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  List<Widget> _buildUtilityChips(LibraryModel library, Color libraryColor) {
    final List<Widget> chips = [];

    // Map of utility IDs to name/icon pairs
    final utilityData = {
      'wifi': {'name': 'WiFi', 'icon': Icons.wifi_rounded},
      'cctv': {'name': 'CCTV', 'icon': Icons.videocam_rounded},
      'water': {'name': 'RO Water', 'icon': Icons.water_drop_rounded},
      'ac': {'name': 'AC', 'icon': Icons.ac_unit_rounded},
      'printer': {'name': 'Printer', 'icon': Icons.print_rounded},
      'scanner': {'name': 'Scanner', 'icon': Icons.scanner_rounded},
      'locker': {'name': 'Lockers', 'icon': Icons.lock_rounded},
      'cafe': {'name': 'Cafeteria', 'icon': Icons.local_cafe_rounded},
      'parking': {'name': 'Parking', 'icon': Icons.local_parking_rounded},
      'charging': {'name': 'Charging', 'icon': Icons.power_rounded},
    };

    for (String utilityId in library.utilities) {
      // Get color for this utility
      Color chipColor = libraryColor;

      // Custom utility
      if (utilityId.startsWith('custom_')) {
        String name = utilityId.replaceAll('custom_', '').replaceAll('_', ' ');
        chips.add(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [chipColor, chipColor.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: chipColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Standard utility
      if (utilityData.containsKey(utilityId)) {
        final data = utilityData[utilityId]!;

        // Alternate colors for visual interest
        final index = library.utilities.indexOf(utilityId);
        final colors = [
          libraryColor,
          Colors.purple,
          Colors.teal,
          Colors.indigo,
          Colors.amber,
          Colors.pink,
        ];
        chipColor = colors[index % colors.length];

        chips.add(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [chipColor, chipColor.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: chipColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data['icon'] as IconData, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  data['name'] as String,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return chips;
  }

  Widget _buildRuleItem(String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            width: 22,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              rule,
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftItem(ShiftModel shift, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: DarkColor.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    shift.shiftName ?? 'Unnamed Shift',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (shift.fee != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.currency_rupee,
                            color: Colors.amber,
                            size: 14,
                          ),
                          Text(
                            '${shift.fee}',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Gap(12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, color: color, size: 16),
                    Gap(8),
                    Text(
                      "${shift.startTime ?? 'N/A'} - ${shift.endTime ?? 'N/A'}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RuleItem extends StatelessWidget {
  final String text;
  const RuleItem(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            width: 22,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class ShiftModel {
  final String? shiftName;
  final String? startTime;
  final String? endTime;
  final int? fee;

  ShiftModel({
    this.shiftName,
    this.startTime,
    this.endTime,
    this.fee,
  });
}