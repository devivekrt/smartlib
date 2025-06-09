import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:smartlib/widgets/solid_button.dart';
import 'package:smartlib/user-pages/home_page.dart';

import '../logic/string.dart';

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

  @override
  void initState() {
    super.initState();
    _isJoined = widget.isJoined;
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.library.id != null) {
      try {
        final snapshot =
            await FirebaseDatabase.instance
                .ref(
                  '${SmartLib.constPath}/users/students/${user.uid}/favorites',
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
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.library.id != null) {
      try {
        final ref = FirebaseDatabase.instance
            .ref('${SmartLib.constPath}/users/students/${user.uid}/favorites')
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
  }

  Future<void> _joinLibrary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.library.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseDatabase.instance
          .ref('${SmartLib.constPath}/students/${user.uid}/joinedLibraries')
          .child(widget.library.id!)
          .set({
            'joinedAt':
                "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
            'status': 'active',
          });

      // Update student count in Firestore
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.library.id)
          .update({'students': FieldValue.increment(1)});

      setState(() {
        _isJoined = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined ${widget.library.libraryName}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error joining library: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join library. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final library = widget.library;
    final Color libraryColor = _getColorForLibrary(library);
    final gradientBorder = LinearGradient(
      colors: [Color(0xff209CC9), Color(0xffF4C264)],
    );

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
        bottomNavigationBar: Container(
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
                                  builder: (context) => HomePage(),
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
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors:
                                  _isJoined
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
                                _isJoined || _isLoading
                                    ? null
                                    : () async {
                                      await _joinLibrary();
                                      if (_isJoined) {
                                        // After successful join, navigate to home
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => HomePage(),
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
                                      _isJoined ? "Already Booked" : "Book Now",
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
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors:
                            _isJoined
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
                      onPressed: _isJoined || _isLoading ? null : _joinLibrary,
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
                                _isJoined ? "Already Joined" : "Book a Seat",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                    ),
                  ),
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
                                        builder: (context) => HomePage(),
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
                            // Joined status if already joined
                            if (_isJoined)
                              Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Already Joined',
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

                            SizedBox(height: 8),

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

                                SizedBox(width: 8),

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
                        SizedBox(height: 12),
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

                              SizedBox(height: 12),

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
                                      SizedBox(height: 8),
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
                          SizedBox(height: 12),
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
                          SizedBox(height: 12),
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

                        // Shifts information
                        if (library.shifts.isNotEmpty) ...[
                          _buildSectionHeader(
                            title: 'Operating Shifts',
                            icon: Icons.schedule_rounded,
                          ),
                          SizedBox(height: 12),
                          ...library.shifts.map(
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
        SizedBox(width: 8),
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
              SizedBox(height: 12),
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
                    SizedBox(width: 8),
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
