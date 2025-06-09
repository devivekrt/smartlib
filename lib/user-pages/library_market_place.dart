import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:smartlib/widgets/solid_button.dart';
import 'package:smartlib/user-pages/home_page.dart';
import 'dart:math' show min, max;

import '../logic/string.dart';
import '../owner-pages/library_detail_screen.dart';

class LibraryMarketplace extends StatefulWidget {
  // Add isSignedUp parameter like in the MarketPlace widget
  final bool isSignedUp;

  const LibraryMarketplace({Key? key, required this.isSignedUp})
    : super(key: key);

  @override
  State<LibraryMarketplace> createState() => _LibraryMarketplaceState();
}

class _LibraryMarketplaceState extends State<LibraryMarketplace> {
  final _firestore = FirebaseFirestore.instance;
  final _database = FirebaseDatabase.instance;

  // Tab control
  int _currentTabIndex = 0;

  // Data for libraries
  List<LibraryModel> _allLibraries = [];
  List<LibraryModel> _joinedLibraries = [];
  bool _isLoading = true;
  bool _isJoiningLibrary = false; // Track join operations
  String _errorMessage = '';

  // Search control
  final TextEditingController _searchController = TextEditingController();
  List<LibraryModel> _filteredLibraries = [];

  @override
  void initState() {
    super.initState();
    _fetchLibraries();
  }

  Future<void> _fetchLibraries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get all libraries
      final libraryDocs = await _firestore.collection('libraries').get();
      print("is library found $libraryDocs");

      // Parse all libraries
      _allLibraries =
          libraryDocs.docs
              .map((doc) => LibraryModel.fromMap(doc.data(), doc.id))
              .toList();

      // Filter for joined libraries
      final joinedSnapshot =
          await _database
              .ref(
                '${SmartLib.constPath}/students/${SmartLib.userId}/joinedLibraries',
              )
              .get();

      if (joinedSnapshot.exists) {
        final Map<dynamic, dynamic> joinedMap =
            joinedSnapshot.value as Map<dynamic, dynamic>;
        final Set<String> joinedIds =
            joinedMap.keys.map((key) => key.toString()).toSet();

        _joinedLibraries =
            _allLibraries
                .where(
                  (library) =>
                      library.id != null && joinedIds.contains(library.id),
                )
                .toList();

        // Remove joined libraries from all libraries list
        _allLibraries =
            _allLibraries
                .where(
                  (library) =>
                      library.id != null && !joinedIds.contains(library.id),
                )
                .toList();
      }

      _filteredLibraries = List.from(_allLibraries);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching libraries: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load libraries. Please try again.';
      });
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E2A38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sort By",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 15),
                _buildSortOption("Price: Low to High"),
                _buildSortOption("Price: High to Low"),
                _buildSortOption("Rating: High to Low"),
                _buildSortOption("Most Reviews"),
                _buildSortOption("Most Popular"),
              ],
            ),
          ),
    );
  }

  Widget _buildSortOption(String title) {
    return InkWell(
      onTap: () => _applySortOption(title),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          title,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),
    );
  }

  void _applySortOption(String option) {
    Navigator.pop(context);

    setState(() {
      switch (option) {
        case "Price: Low to High":
          _filteredLibraries.sort(
            (a, b) => (a.lowFee ?? 0).compareTo(b.lowFee ?? 0),
          );
          break;
        case "Price: High to Low":
          _filteredLibraries.sort(
            (a, b) => (b.lowFee ?? 0).compareTo(a.lowFee ?? 0),
          );
          break;
        case "Rating: High to Low":
          _filteredLibraries.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case "Most Reviews":
          _filteredLibraries.sort((a, b) => (b.reviews).compareTo(a.reviews));
          break;
        case "Most Popular":
          _filteredLibraries.sort((a, b) => (b.students).compareTo(a.students));
          break;
      }
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E2A38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filter Options",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 15),
                _buildFilterOption("Rating (4+)"),
                _buildFilterOption("Open Now"),
                _buildFilterOption("24x7 Access"),
                _buildFilterOption("Distance (< 3km)"),
                SizedBox(height: 15),
                SolidButton(
                  text: "Apply Filters",
                  width: double.infinity,
                  height: 45,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildFilterOption(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Colors.white70)),
          Spacer(),
          Switch(
            value: false,
            onChanged: (value) {
              // Implement filter logic here
            },
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  void _searchLibraries(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredLibraries = List.from(_allLibraries);
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredLibraries =
          _allLibraries.where((library) {
            final name = library.libraryName?.toLowerCase() ?? '';
            final location = library.location?.toLowerCase() ?? '';
            return name.contains(lowercaseQuery) ||
                location.contains(lowercaseQuery);
          }).toList();
    });
  }

  Future<void> _joinLibrary(LibraryModel library) async {
    if (library.id == null || _isJoiningLibrary) return;

    setState(() {
      _isJoiningLibrary = true;
    });

    try {
      // Add library to user's joined libraries
      await _database
          .ref(
            '${SmartLib.constPath}/students/${SmartLib.userId}/joinedLibraries',
          )
          .child(library.id!)
          .set({
            'joinedAt':
                "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
            'status': 'active',
          });

      // Update UI
      setState(() {
        _joinedLibraries.add(library);
        _allLibraries.remove(library);
        _filteredLibraries = List.from(_allLibraries);
        _isJoiningLibrary = false;
      });

      // Update student count in the library
      await _firestore.collection('libraries').doc(library.id).update({
        'students': FieldValue.increment(1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully joined ${library.libraryName}')),
      );
    } catch (e) {
      setState(() {
        _isJoiningLibrary = false;
      });
      print('Error joining library: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join library. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user has just signed up, force the Find tab to be selected
    if (widget.isSignedUp && _currentTabIndex != 0) {
      _currentTabIndex = 0;
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          // Don't show back button if user just signed up
          automaticallyImplyLeading: !widget.isSignedUp,
          title: Text(
            'Library Marketplace',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          actions: [
            // Sort and filter icons always shown
            IconButton(
              icon: Icon(Icons.sort, color: Colors.white),
              onPressed: _showSortOptions,
            ),
            IconButton(
              icon: Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilterOptions,
            ),
          ],
        ),
        // Book Later button only shown when signed up
        bottomNavigationBar:
            widget.isSignedUp
                ? Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: SolidButton(
                    text: "Book Later",
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                    },
                    width: double.infinity,
                  ),
                )
                : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab buttons - Only show custom tab buttons when not just signed up
            if (!widget.isSignedUp)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Container(
                  height: 70,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Find New button
                      Expanded(
                        child: SolidButton(
                          text: "Find New",
                          onPressed: () {
                            setState(() {
                              _currentTabIndex = 0;
                            });
                          },
                          buttonColor:
                              _currentTabIndex == 0
                                  ? DarkColor.primary
                                  : Colors.transparent,
                          borderColor:
                              _currentTabIndex == 0
                                  ? Colors.transparent
                                  : DarkColor.primary,
                          width: double.infinity,
                          height: 50,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Joined button with only border
                      Expanded(
                        child: SolidButton(
                          text: "Joined",
                          onPressed: () {
                            setState(() {
                              _currentTabIndex = 1;
                            });
                          },
                          buttonColor:
                              _currentTabIndex == 1
                                  ? DarkColor.primary
                                  : Colors.transparent,
                          borderColor:
                              _currentTabIndex == 1
                                  ? Colors.transparent
                                  : DarkColor.primary,
                          width: double.infinity,
                          height: 50,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 20,
              ), // Just a spacer for signed up users, no tabs
            // Library content based on tab - always show the Find tab if just signed up
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _errorMessage.isNotEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _fetchLibraries,
                              icon: Icon(Icons.refresh),
                              label: Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                      : _currentTabIndex == 0 || widget.isSignedUp
                      ? _buildFindTab()
                      : _buildJoinedTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindTab() {
    final libraries = _filteredLibraries;

    if (libraries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.withOpacity(0.7),
            ),
            SizedBox(height: 16),
            Text(
              'No libraries found',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try a different search term'
                  : 'New libraries will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header text moved below the tab
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find Your Perfect Study Spot',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Discover and join libraries near you',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Search field below headers
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Container(
            decoration: BoxDecoration(
              color: DarkColor.cardColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchLibraries,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search libraries...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
          child: Text(
            'Libraries Near You',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),

        // Library cards - now in vertical scrolling list
        Expanded(
          child: ListView.builder(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20),
            itemCount: libraries.length,
            itemBuilder: (context, index) {
              final library = libraries[index];
              return _buildLibraryCard(library);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJoinedTab() {
    if (_joinedLibraries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.7),
            ),
            SizedBox(height: 16),
            Text(
              'You haven\'t joined any libraries yet',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Join a library to see it here',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentTabIndex = 0;
                });
              },
              icon: Icon(Icons.search),
              label: Text('Find Libraries'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DarkColor.highlightColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: _joinedLibraries.length,
      itemBuilder: (context, index) {
        final library = _joinedLibraries[index];
        return _buildVerticalLibraryCard(library, isJoined: true);
      },
    );
  }

  Widget _buildLibraryCard(LibraryModel library) {
    final width = MediaQuery.of(context).size.width;
    final color = _getColorForLibrary(library);
    final availableSeats = library.availableSeats ?? 0;
    final totalSeats = library.totalSeats ?? 1;
    final isOpen = (availableSeats > 0);
    final isPopular = (library.students ?? 0) > 20; // Just an example threshold

    // Function to safely get address or location
    String getLocation() {
      if (library.address != null) {
        final address = library.address!;
        if (address['city'] != null) {
          return address['city'].toString();
        }
      }
      return library.location ?? 'No location';
    }

    return GestureDetector(
      onTap: () => _navigateToLibraryDetail(library),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 15),
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
                    image:
                        library.libraryImageUrl != null
                            ? DecorationImage(
                              image: NetworkImage(library.libraryImageUrl!),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      library.libraryImageUrl == null
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
                              library.libraryName ?? 'Unnamed Library',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
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
                            color: Colors.white.withOpacity(0.7),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              getLocation(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
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

            // Status tags - Updated styling but not using LibraryCard style
            SizedBox(height: 10),
            Row(
              children: [
                // Open/Closed status tag
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        isOpen
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

                // Rating - Keep previous style
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 3),
                    Text(
                      library.rating != null
                          ? library.rating.toStringAsFixed(1)
                          : "0",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      " (${library.reviews})",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Show some amenities
            SizedBox(height: 10),
            if (library.utilities.isNotEmpty)
              SizedBox(
                height: 26,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _buildUtilityChips(library).take(5).toList(),
                ),
              ),

            SizedBox(height: 15),

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
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 5),
                      _buildProgressBar(
                        width - 60,
                        availableSeats,
                        totalSeats,
                        color,
                      ),
                      SizedBox(height: 5),
                      Text(
                        "out of $totalSeats total seats",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 15),

            // Fee display and Book button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Price if available - updated style
                if (library.lowFee != null)
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
                          "₹${library.lowFee}",
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
                  onTap: _isJoiningLibrary ? null : () => _joinLibrary(library),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isJoiningLibrary ? color.withOpacity(0.5) : color,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child:
                          _isJoiningLibrary
                              ? SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(
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
      ),
    );
  }

  Widget _buildProgressBar(
    double containerWidth,
    int available,
    int total,
    Color color,
  ) {
    // Prevent division by zero and ensure ratio is between 0 and 1
    final double ratio = total <= 0 ? 0.0 : min(1.0, available / max(1, total));

    // Explicitly convert to double and clamp width to prevent overflow
    final double barWidth =
        min(containerWidth, max(0.0, containerWidth * ratio)).toDouble();

    return Container(
      height: 6,
      width: containerWidth,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Stack(
        // Using Stack instead of Row for better width control
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: barWidth,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalLibraryCard(
    LibraryModel library, {
    bool isJoined = false,
  }) {
    final color = _getColorForLibrary(library);
    final availableSeats = library.availableSeats ?? 0;
    final totalSeats = library.totalSeats ?? 1;
    final isOpen = (availableSeats > 0);

    // Function to safely get address or location
    String getLocation() {
      if (library.address != null) {
        final address = library.address!;
        if (address['city'] != null) {
          return address['city'].toString();
        }
      }
      return library.location ?? 'No location';
    }

    return GestureDetector(
      onTap: () => _navigateToLibraryDetail(library),
      child: Container(
        margin: EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.transparent, color.withOpacity(0.15)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  // Library Image with gradient overlay
                  Container(
                    height: 90,
                    width: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image or placeholder
                          library.libraryImageUrl != null
                              ? Image.network(
                                library.libraryImageUrl!,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                color: color.withOpacity(0.3),
                                child: Icon(
                                  Icons.apartment,
                                  color: color,
                                  size: 30,
                                ),
                              ),

                          // Gradient overlay for better text contrast
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Status chip in the bottom left
                          Positioned(
                            bottom: 5,
                            left: 5,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isOpen
                                        ? Colors.green.withOpacity(0.8)
                                        : Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isOpen ? 'Open' : 'Closed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Joined badge on top right for joined libraries
                          if (isJoined)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Joined',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 15),

                  // Library Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Library Name
                        Text(
                          library.libraryName ?? 'Unnamed Library',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 4),

                        // Rating with stars
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 3),
                            Text(
                              "${library.rating != null ? library.rating.toStringAsFixed(1) : '0'}/5.0",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              " • ${library.reviews} reviews",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        // Location
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.white.withOpacity(0.8),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                getLocation(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // Utilities as chips
                        SizedBox(height: 8),
                        if (library.utilities.isNotEmpty)
                          SizedBox(
                            height: 22,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children:
                                  library.utilities.take(3).map((util) {
                                    final utilityIconMap = {
                                      'wifi': Icons.wifi,
                                      'cctv': Icons.videocam,
                                      'water': Icons.water_drop,
                                      'ac': Icons.ac_unit,
                                      'printer': Icons.print,
                                      'scanner': Icons.scanner,
                                      'locker': Icons.lock,
                                      'cafe': Icons.local_cafe,
                                      'parking': Icons.local_parking,
                                      'charging': Icons.power,
                                    };

                                    IconData icon = Icons.star;
                                    if (utilityIconMap.containsKey(util)) {
                                      icon = utilityIconMap[util]!;
                                    }

                                    return Container(
                                      margin: EdgeInsets.only(right: 6),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(icon, size: 12, color: color),
                                          SizedBox(width: 4),
                                          Text(
                                            _getUtilityName(util),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),

                        SizedBox(height: 8),

                        // Price and button row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Price with modern styling
                            if (library.lowFee != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber),
                                  color: Colors.white.withOpacity(0.05),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      "₹${library.lowFee}",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "/mo",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      availableSeats > 0
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        availableSeats > 0
                                            ? Colors.green.withOpacity(0.5)
                                            : Colors.red.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  "$availableSeats/$totalSeats seats",
                                  style: TextStyle(
                                    color:
                                        availableSeats > 0
                                            ? Colors.green
                                            : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            // Button or joined status
                            isJoined
                                ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Manage',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : _isJoiningLibrary
                                ? Container(
                                  height: 32,
                                  width: 65,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    color: color.withOpacity(0.2),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                )
                                : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color, color.withOpacity(0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => _joinLibrary(library),
                                    child: Text(
                                      'Join',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      minimumSize: Size(65, 32),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLibraryDetail(LibraryModel library) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LibraryDetailScreen(
              library: library,
              isJoined: _joinedLibraries.contains(library),
              isSignedUp: widget.isSignedUp, // Pass isSignedUp parameter
            ),
      ),
    ).then((result) {
      // Refresh data if needed
      if (result == true) {
        _fetchLibraries();
      }
    });
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

  String _getUtilityName(String utilityId) {
    // Map utility IDs to display names
    final Map<String, String> utilityNameMap = {
      'wifi': 'Wi-Fi',
      'cctv': 'CCTV',
      'water': 'Water',
      'ac': 'AC',
      'printer': 'Printer',
      'scanner': 'Scanner',
      'locker': 'Lockers',
      'cafe': 'Café',
      'parking': 'Parking',
      'charging': 'Charging',
    };

    if (utilityId.startsWith('custom_')) {
      return utilityId.replaceAll('custom_', '').replaceAll('_', ' ');
    }

    return utilityNameMap[utilityId] ?? utilityId;
  }

  List<Widget> _buildUtilityChips(LibraryModel library) {
    final List<Widget> chips = [];
    final utilityIconMap = {
      'wifi': Icons.wifi,
      'cctv': Icons.videocam,
      'water': Icons.water_drop,
      'ac': Icons.ac_unit,
      'printer': Icons.print,
      'scanner': Icons.scanner,
      'locker': Icons.lock,
      'cafe': Icons.local_cafe,
      'parking': Icons.local_parking,
      'charging': Icons.power,
    };

    for (String utilityId in library.utilities) {
      if (chips.length >= 5) break; // Only show 5 max

      // Get the color for this library
      final color = _getColorForLibrary(library);

      // Get icon or use default
      IconData icon = Icons.star;
      if (utilityIconMap.containsKey(utilityId)) {
        icon = utilityIconMap[utilityId]!;
      }

      chips.add(
        Container(
          margin: EdgeInsets.only(right: 6),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              SizedBox(width: 4),
              Text(
                _getUtilityName(utilityId),
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    return chips;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
