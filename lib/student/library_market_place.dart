import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:smartlib/widgets/solid_button.dart';
import 'dart:math' show min, max;

import '../data/string.dart';
import '../function/listen_data.dart';
import '../function/review_service.dart';
import '../function/student_location.dart';
import 'my_bookings_screen.dart' show MyBookingsScreen;
import 'library_detail_screen.dart';
import 'main_tab_screen.dart';

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
  // Add a reference to ListenData service
  final _listenData = ListenData();
  // Add reference to location service
  final StudentLocationService _locationService = StudentLocationService();

  // Store calculated distances
  Map<String, double> _libraryDistances = {};

  // Tab control
  int _currentTabIndex = 0;

  // Data for libraries
  List<LibraryModel> _allLibraries = [];
  List<LibraryModel> _joinedLibraries = [];
  bool _isLoading = true;
  bool _isJoiningLibrary = false; // Track join operations
  bool _isLeavingLibrary = false; // Track leave operations
  String _errorMessage = '';

  // User's current status
  Map<String, dynamic>? _currentStatus;
  bool _isCheckedIntoLibrary = false;
  String? _currentLibraryId;

  // Search control
  final TextEditingController _searchController = TextEditingController();
  List<LibraryModel> _filteredLibraries = [];

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
    _fetchCurrentStatus().then((_) {
      _fetchLibraries();
    });
  }

  // Initialize location service
  Future<void> _initializeLocationService() async {
    try {
      await _locationService.initialize();
      print("Location service initialized: ${_locationService.isLocationAvailable}");
    } catch (e) {
      print("Error initializing location service: $e");
    }
  }

  // Use ListenData to fetch user's current status
  Future<void> _fetchCurrentStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // This will update SmartLib.currentStatus, etc. directly
      await _listenData.getUserData();

      // Now we can just use the values from SmartLib
      setState(() {
        _isCheckedIntoLibrary = SmartLib.isCheckedIn == true;
        _currentLibraryId = SmartLib.libraryId;

        // Create a local copy of current status data for the UI
        _currentStatus = {
          'isCheckedIn': SmartLib.isCheckedIn,
          'currentLibraryId': SmartLib.libraryId,
          'currentSeatNo': SmartLib.seatNo,
          'bookingId': SmartLib.bookingId,
          'shiftName': SmartLib.shiftName,
          'dueDate': SmartLib.dueDate,
        };

        print("User checked into library: $_isCheckedIntoLibrary");
        print("Current library ID: $_currentLibraryId");
      });
    } catch (e) {
      print("Error fetching current status: $e");
    }
  }

  // Use ListenData to fetch libraries
  Future<void> _fetchLibraries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Use the singleton location service to get student location
      // Initialize the location service if not already done
      await _locationService.initialize();

      double studentLat = 0.0;
      double studentLon = 0.0;

      // Check if location is available
      if (_locationService.isLocationAvailable) {
        // Get current location values
        studentLat = _locationService.latitude!;
        studentLon = _locationService.longitude!;

        print('Using existing location: $studentLat, $studentLon');

        // If location is stale, request an update
        if (_locationService.isStale) {
          print('Location is stale, requesting update');
          final locationData = await _locationService.requestSingleLocationUpdate();

          if (locationData != null) {
            studentLat = locationData.latitude;
            studentLon = locationData.longitude;
            print('Updated to fresh location: $studentLat, $studentLon');
          }
        }
      } else {
        // If no location available, try to get a fresh one
        print('No location available, requesting new location');
        final locationData = await _locationService.requestSingleLocationUpdate();

        if (locationData != null) {
          studentLat = locationData.latitude;
          studentLon = locationData.longitude;
          print('Obtained new location: $studentLat, $studentLon');
        } else {
          print('Could not obtain location, using default coordinates');
        }
      }

      // Get all libraries using ListenData service
      final librariesData = await _listenData.getAllLibraries();

      // Convert the raw data to LibraryModel objects
      _allLibraries =
          librariesData
              .map((data) => LibraryModel.fromMap(data, data['id'] as String))
              .toList();

      // Calculate and store distances for all libraries
      if (_locationService.isLocationAvailable) {
        _calculateDistancesForLibraries(_allLibraries);
      }

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

      setState(() {
        _isLoading = false;
        _filteredLibraries = List.from(_allLibraries);
      });
    } catch (e) {
      print('Error fetching libraries: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load libraries. Please try again.';
      });
    }
  }

  // Calculate distances for all libraries
  void _calculateDistancesForLibraries(List<LibraryModel> libraries) {
    if (!_locationService.isLocationAvailable) return;

    for (var library in libraries) {
      if (library.id == null) continue;

      final lat = double.tryParse(library.locationLatitude ?? '') ?? 0.0;
      final lon = double.tryParse(library.locationLongitude ?? '') ?? 0.0;

      if (lat != 0.0 && lon != 0.0) {
        final distance = _locationService.calculateDistanceInKm(lat, lon);
        if (distance != null) {
          _libraryDistances[library.id!] = distance;
        }
      }
    }
  }

  // Helper to get formatted location string with distance
  String _getFormattedLocation(LibraryModel library) {
    String locationText = "";

    // Try to get city from address
    if (library.address != null && library.address!['city'] != null) {
      locationText = library.address!['city'].toString();
    } else if (library.location != null && library.location!.isNotEmpty) {
      locationText = library.location!;
    } else {
      locationText = 'No location info';
    }

    // Add distance if available
    if (library.id != null && _libraryDistances.containsKey(library.id)) {
      double distance = _libraryDistances[library.id]!;
      String distanceText;

      if (distance < 1.0) {
        // If less than 1km, show in meters
        final meters = (distance * 1000).round();
        distanceText = '$meters m';
      } else if (distance < 100) {
        // Show with one decimal place if under 100km
        distanceText = '${distance.toStringAsFixed(1)} km';
      } else {
        // Show as integer for large distances
        distanceText = '${distance.round()} km';
      }

      // Combine location with distance
      return "$locationText • $distanceText away";
    }

    return locationText;
  }

  /// Leave library function with improved error handling and user experience
  Future<void> _leaveLibrary(LibraryModel library) async {
    // Prevent multiple simultaneous attempts
    if (_isLeavingLibrary) return;

    // Check if user has an active booking in this library
    bool hasActiveBooking = false;
    String? currentBookingId;

    try {
      // First check current status in RTDB
      final statusSnapshot =
      await _database
          .ref()
          .child(
        "${SmartLib.constPath}/students/${SmartLib.userId}/currentStatus",
      )
          .get();

      if (statusSnapshot.exists) {
        final statusData = statusSnapshot.value as Map<dynamic, dynamic>?;

        if (statusData != null) {
          final libId = statusData['currentLibraryId']?.toString();
          final isCheckedIn = statusData['isCheckedIn'] == true;

          // If user is checked into this library, they cannot leave
          if (libId == library.id && isCheckedIn) {
            hasActiveBooking = true;
            currentBookingId = statusData['bookingId']?.toString();
          }
        }
      }

      // Show confirmation dialog with appropriate options
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
          backgroundColor: DarkColor.cardColor,
          title: Text(
            'Leave Library',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to leave ${library.libraryName}?',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),

              // Show warning if user is checked in
              if (hasActiveBooking)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'You are checked in!',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You need to check out from this library before leaving.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),

            // If not checked in, show leave button
            if (!hasActiveBooking)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, 'leave'),
                child: Text('Leave'),
              ),

            // If checked in, show checkout navigation button
            if (hasActiveBooking)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(context, 'checkout'),
                child: Text('Go to Check Out'),
              ),
          ],
        ),
      );

      // Handle dialog result
      switch (result) {
        case 'leave':
          await _performLeaveLibrary(library);
          break;

        case 'checkout':
          _navigateToCheckout(library.id!, currentBookingId);
          break;

        case 'cancel':
        default:
        // Do nothing
          return;
      }
    } catch (e) {
      print('Error in leave library flow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Perform the actual leave library actions
  Future<void> _performLeaveLibrary(LibraryModel library) async {
    if (library.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot leave library: Invalid library ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLeavingLibrary = true;
    });

    try {
      // Start a batch write for consistency
      final batch = FirebaseFirestore.instance.batch();

      // 1. Check for active bookings (another verification)
      final bookingsQuery =
      await FirebaseFirestore.instance
          .collection('seatBookings')
          .where('studentId', isEqualTo: SmartLib.userId)
          .where('status', whereIn: ['active', 'confirmed'])
          .get();

      if (bookingsQuery.docs.isNotEmpty) {
        setState(() {
          _isLeavingLibrary = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have active bookings in this library. Please cancel them first.',
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'View Bookings',
              onPressed: () {
                // Navigate to bookings page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyBookingsScreen()),
                );
              },
            ),
          ),
        );
        return;
      }

      // 2. Remove from joinedLibraries in RTDB
      await _database
          .ref()
          .child(
        "${SmartLib.constPath}/students/${SmartLib.userId}/joinedLibraries/${library.id}",
      )
          .remove();

      await _database
          .ref()
          .child(
        "${SmartLib.constPath}/students/${SmartLib.userId}/currentStatus",
      )
          .remove();

      // Update student count in library if this is a new student
      final libraryDocRef = FirebaseFirestore.instance
          .collection("libraries")
          .doc(library.id);
      batch.update(libraryDocRef, {'students': FieldValue.increment(-1)});

      // Reference to the library subscribers collection
      final subscribersRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(library.id)
          .collection('subscribers')
          .doc(SmartLib.userId);
      // 3. Remove the user from the library subscribers
      batch.delete(subscribersRef);
      // Execute the batch
      await batch.commit();

      // 5. Update our local lists
      setState(() {
        _isLeavingLibrary = false;
        _joinedLibraries.removeWhere((lib) => lib.id == library.id);

        // Ensure we're not adding duplicates
        if (!_allLibraries.any((lib) => lib.id == library.id)) {
          _allLibraries.add(library);
        }

        // Update filtered libraries
        _filteredLibraries = List.from(_allLibraries);
      });

      // 6. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have left ${library.libraryName}'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error leaving library: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave library. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLeavingLibrary = false;
      });
    }
  }

  /// Navigate to checkout page for the current booking
  void _navigateToCheckout(String libraryId, String? bookingId) {
    try {
      // If we don't have a booking ID, navigate to general checkout page
      if (bookingId == null || bookingId.isEmpty) {
      } else {
        // If we have a booking ID, navigate to specific checkout
      }
    } catch (e) {
      print('Error navigating to checkout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open checkout screen. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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

  // Add these variables to your State class
  bool _filterOpenNow = false;
  bool _filterNearby = false;
  bool _filter24x7 = false;
  bool _filterTopRated = false;
  double _maxDistance = 10.0; // Default 10 km

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E2A38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder:
          (context) => StatefulBuilder(
        builder:
            (context, setModalState) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Library Filters",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _filterOpenNow = false;
                        _filterNearby = false;
                        _filter24x7 = false;
                        _filterTopRated = false;
                        _maxDistance = 10.0;
                      });
                    },
                    child: Text(
                      "Reset",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),

              // Simple filter options
              _buildFilterOption("Open Now", _filterOpenNow, (value) {
                setModalState(() => _filterOpenNow = value);
              }),
              _buildFilterOption("24/7 Access", _filter24x7, (value) {
                setModalState(() => _filter24x7 = value);
              }),
              _buildFilterOption(
                "Top Rated (4+ stars)",
                _filterTopRated,
                    (value) {
                  setModalState(() => _filterTopRated = value);
                },
              ),

              // Nearby filter with distance slider
              _buildFilterOption(
                "Nearby (within ${_maxDistance.toStringAsFixed(0)} km)",
                _filterNearby,
                    (value) {
                  setModalState(() => _filterNearby = value);
                },
              ),

              // Only show distance slider when nearby is selected
              if (_filterNearby)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Distance: ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      Expanded(
                        child: Slider(
                          value: _maxDistance,
                          min: 1.0,
                          max: 10.0,
                          divisions: 10,
                          activeColor: Colors.blue,
                          onChanged: (value) {
                            setModalState(() => _maxDistance = value);
                          },
                        ),
                      ),
                      Text(
                        "${_maxDistance.toStringAsFixed(0)} km",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 15),
              SolidButton(
                text: "Apply Filters",
                width: double.infinity,
                height: 45,
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilters();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(
      String title,
      bool value,
      Function(bool) onChanged,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Colors.white70)),
          Spacer(),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.blue),
        ],
      ),
    );
  }

  // Simple function to apply filters
  void _applyFilters() {
    // Start with all libraries
    List<LibraryModel> filtered = [..._allLibraries];

    // Apply filters one by one
    if (_filterOpenNow) {
      filtered = filtered.where((lib) => _isLibraryOpen(lib)).toList();
    }

    if (_filterTopRated) {
      filtered = filtered.where((lib) => (lib.rating ?? 0) >= 4.0).toList();
    }

    if (_filterNearby) {
      final locationService = StudentLocationService();
      if (locationService.isLocationAvailable) {
        filtered =
            filtered.where((lib) {
              final lat = double.tryParse(lib.locationLatitude ?? '') ?? 0.0;
              final lng = double.tryParse(lib.locationLongitude ?? '') ?? 0.0;
              final distance = locationService.calculateDistanceInKm(lat, lng);
              return distance != null && distance <= _maxDistance;
            }).toList();
      }
    }

    // Update filtered libraries
    setState(() {
      _filteredLibraries = filtered;
    });

    // Show feedback
    int count = _filteredLibraries.length;
    String message =
    count > 0
        ? "Found $count matching libraries"
        : "No libraries match your filters";

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Simple function to check if library is open
  bool _isLibraryOpen(LibraryModel library) {
    // Get current time and day
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;
    final isWeekend = now.weekday == 6 || now.weekday == 7; // 6 = Saturday, 7 = Sunday

    // Check operating hours if available
    try {
      final openingHours = library.openingHours;
      if (openingHours != null) {
        // Check the appropriate key based on day of week
        final String timeRangeKey = isWeekend ? 'sat-sun' : 'mon-fri';

        if (openingHours.containsKey(timeRangeKey)) {
          final timeRange = openingHours[timeRangeKey];

          if (timeRange != null &&
              timeRange['openTime'] != null &&
              timeRange['closeTime'] != null) {

            // Parse open time
            final String openTimeStr = timeRange['openTime'].toString();
            final List<String> openTimeParts = openTimeStr.split(':');
            if (openTimeParts.length >= 2) {
              final int openHour = int.tryParse(openTimeParts[0]) ?? 0;
              final int openMinute = int.tryParse(openTimeParts[1]) ?? 0;

              // Parse close time
              final String closeTimeStr = timeRange['closeTime'].toString();
              final List<String> closeTimeParts = closeTimeStr.split(':');
              if (closeTimeParts.length >= 2) {
                final int closeHour = int.tryParse(closeTimeParts[0]) ?? 0;
                final int closeMinute = int.tryParse(closeTimeParts[1]) ?? 0;

                // Convert to minutes since midnight for easier comparison
                final int currentTimeMinutes = currentHour * 60 + currentMinute;
                final int openTimeMinutes = openHour * 60 + openMinute;
                final int closeTimeMinutes = closeHour * 60 + closeMinute;

                // Handle overnight hours (when closing time is earlier than opening time)
                if (closeTimeMinutes < openTimeMinutes) {
                  return currentTimeMinutes >= openTimeMinutes || currentTimeMinutes < closeTimeMinutes;
                } else {
                  return currentTimeMinutes >= openTimeMinutes && currentTimeMinutes < closeTimeMinutes;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking if library is open: $e');
    }

    // Default to closed if we can't determine
    return false;
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

  void navigateToLibraryDetail(LibraryModel library) async {
    // Check if student is already checked into another library
    if (_isCheckedIntoLibrary && _currentLibraryId != library.id) {
      // Find the current library name
      String currentLibraryName = "another library";
      for (var lib in _joinedLibraries) {
        if (lib.id == _currentLibraryId) {
          currentLibraryName = lib.libraryName ?? "another library";
          break;
        }
      }

      // Show an alert dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
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
                'You are currently checked in to $currentLibraryName.',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 8),
              Text(
                'You need to check out from your current library before booking a seat at ${library.libraryName}.',
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
              ),
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
              },
              child: Text('My Bookings'),
            ),
          ],
        ),
      );
      return;
    }

    // If not checked in or checked into the same library, proceed to library details
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
        _fetchCurrentStatus().then((_) {
          _fetchLibraries();
        });
      }
    });
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
          automaticallyImplyLeading: false,
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
        // UTC timestamp banner at top
        // Adding the timestamp banner below the AppBar
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Book Later button only shown when signed up
            if (widget.isSignedUp)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: SolidButton(
                  text: "Book Later",
                  onPressed: () {
                    //remove previous page
                    Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => MainTabScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: Duration(milliseconds: 500),
                    ), (route) => false);
                  },
                  width: double.infinity,
                ),
              ),
          ],
        ),
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
                      Gap(8),
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
            Gap(8),
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
            Gap(8),
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

    // Add this section to check for reviewable libraries
    return FutureBuilder<List<LibraryModel>>(
      future: _checkForReviewableLibraries(),
      builder: (context, snapshot) {
        // Show loading if needed
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        // If error, just show regular list
        if (snapshot.hasError) {
          return _buildJoinedLibrariesList();
        }

        final reviewableLibraries =
            snapshot.data?.where((lib) => lib.canReview ?? false).toList() ??
                [];

        // If no reviewable libraries, just show regular list
        if (reviewableLibraries.isEmpty) {
          return _buildJoinedLibrariesList();
        }

        // Show reviewable libraries banner at top
        return Column(
          children: [
            // Reviewable libraries section
            Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: _buildReviewBanner(reviewableLibraries),
            ),

            // Divider
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.2)),
            ),

            // Regular joined libraries
            Expanded(child: _buildJoinedLibrariesList()),
          ],
        );
      },
    );
  }

  // Add these helper methods
  Future<List<LibraryModel>> _checkForReviewableLibraries() async {
    final ReviewService _reviewService = ReviewService();
    final eligibleList = await _reviewService.getLibrariesEligibleForReview();

    // Mark libraries that are eligible for review
    for (var library in _joinedLibraries) {
      final isEligible = eligibleList.any((lib) => lib['id'] == library.id);
      library.canReview = isEligible;
    }

    return _joinedLibraries;
  }

  Widget _buildReviewBanner(List<LibraryModel> reviewableLibraries) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Share Your Experience!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'You\'ve been using these libraries for 15+ days. Help others by sharing your feedback!',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          SizedBox(height: 15),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: reviewableLibraries.length,
              itemBuilder: (context, index) {
                final library = reviewableLibraries[index];
                return GestureDetector(
                  onTap: () => _showReviewDialog(library),
                  child: Container(
                    width: 150,
                    margin: EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Library image or icon
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            image:
                            library.libraryImageUrl != null
                                ? DecorationImage(
                              image: NetworkImage(
                                library.libraryImageUrl!,
                              ),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child:
                          library.libraryImageUrl == null
                              ? Icon(
                            Icons.library_books,
                            color: Colors.white,
                          )
                              : null,
                        ),
                        SizedBox(height: 8),
                        Text(
                          library.libraryName ?? 'Unknown Library',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap to review',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Method to show the review dialog
  void _showReviewDialog(LibraryModel library) {
    double rating = 0;
    final feedbackController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: DarkColor.cardColor,
              title: Text(
                'Rate Your Experience',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How was your experience at ${library.libraryName}?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 20),

                    // Rating stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            color:
                            index < rating.round()
                                ? Colors.amber
                                : Colors.grey,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              rating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),

                    SizedBox(height: 5),
                    Center(
                      child: Text(
                        _getRatingText(rating),
                        style: TextStyle(
                          color: _getRatingColor(rating),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Feedback text field
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Share your experience (optional)',
                        hintStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: DarkColor.highlightColor,
                          ),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                isSubmitting
                    ? Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : ElevatedButton(
                  onPressed:
                  rating <= 0
                      ? null
                      : () async {
                    setState(() {
                      isSubmitting = true;
                    });

                    final ReviewService _reviewService =
                    ReviewService();
                    final success = await _reviewService
                        .submitReview(
                      libraryId: library.id!,
                      rating: rating,
                      feedback: feedbackController.text,
                    );

                    if (success) {
                      Navigator.pop(context);

                      // Refresh the joined libraries list
                      this.setState(() {
                        // Mark this library as reviewed
                        for (var lib in _joinedLibraries) {
                          if (lib.id == library.id) {
                            lib.canReview = false;
                          }
                        }
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Thank you for your review!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      setState(() {
                        isSubmitting = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to submit review. Please try again.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarkColor.highlightColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Submit Review'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      feedbackController.dispose();
    });
  }

  // Helper methods for rating text and colors
  String _getRatingText(double rating) {
    if (rating <= 0) return 'Select Rating';
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Fair';
    if (rating <= 3) return 'Good';
    if (rating <= 4) return 'Very Good';
    return 'Excellent';
  }

  Color _getRatingColor(double rating) {
    if (rating <= 0) return Colors.grey;
    if (rating <= 1) return Colors.red;
    if (rating <= 2) return Colors.orange;
    if (rating <= 3) return Colors.amber;
    if (rating <= 4) return Colors.lightGreen;
    return Colors.green;
  }

  // Method to build the regular joined libraries list
  Widget _buildJoinedLibrariesList() {
    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: _joinedLibraries.length,
      itemBuilder: (context, index) {
        final library = _joinedLibraries[index];
        return _buildJoinedLibraryCard(library);
      },
    );
  }

  Widget _buildJoinedLibraryCard(LibraryModel library) {
    final color = _getColorForLibrary(library);
    final availableSeats = library.availableSeats ?? 0;
    final isOpen = (availableSeats > 0);

    // Check if this is the library the user is currently checked into
    final isCurrentLibrary =
        _isCheckedIntoLibrary && _currentLibraryId == library.id;

    return GestureDetector(
      onTap: () => navigateToLibraryDetail(library),
      child: Container(
        margin: EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
            isCurrentLibrary
                ? Colors.green.withOpacity(0.5)
                : color.withOpacity(0.3),
            width: isCurrentLibrary ? 2 : 1,
          ),
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
              child: Column(
                children: [
                  Row(
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

                              // Joined badge on top right
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    isCurrentLibrary
                                        ? Colors.green.withOpacity(0.8)
                                        : Colors.blue.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isCurrentLibrary
                                            ? Icons.check_circle
                                            : Icons.check_circle,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        isCurrentLibrary ? 'Current' : 'Joined',
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
                            Row(
                              children: [
                                if (isCurrentLibrary)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                if (isCurrentLibrary) SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    library.libraryName ?? 'Unnamed Library',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color:
                                      isCurrentLibrary
                                          ? Colors.green
                                          : Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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

                            // Location with distance
                            SizedBox(height: 6),
                            Row(
                              children: [
                                // Use distance icon if distance is available
                                Icon(
                                  _libraryDistances.containsKey(library.id)
                                      ? Icons.directions
                                      : Icons.location_on_outlined,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _getFormattedLocation(library),
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

                            // Status information - only show if checked in
                            if (isCurrentLibrary && _currentStatus != null) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  "Currently checked in",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Library action buttons in a row
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // View button
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.visibility, size: 16),
                          label: Text("View"),
                          onPressed: () => navigateToLibraryDetail(library),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: color,
                            side: BorderSide(color: color),
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),

                      // Leave button (disabled if checked in)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isCurrentLibrary ? Icons.logout : Icons.close,
                            size: 16,
                          ),
                          label: Text(isCurrentLibrary ? "Check Out" : "Leave"),
                          onPressed:
                          _isLeavingLibrary || isCurrentLibrary
                              ? null // Disable if currently leaving or checked in
                              : () => _leaveLibrary(library),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            isCurrentLibrary
                                ? Colors.amber
                                : Colors.red.shade700,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade800,
                            disabledForegroundColor: Colors.grey,
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryCard(LibraryModel library) {
    final width = MediaQuery.of(context).size.width;
    final color = _getColorForLibrary(library);
    final availableSeats = library.availableSeats ?? 0;
    final totalSeats = library.totalSeats ?? 1;
    final isOpen = (availableSeats > 0);
    final isPopular = (library.students ?? 0) > 20; // Just an example threshold

    // Check if user is checked into any library
    final canBookNewSeat =
        !_isCheckedIntoLibrary || _currentLibraryId == library.id;

    return GestureDetector(
      onTap: () => navigateToLibraryDetail(library),
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
                          // Use distance icon if distance is available
                          Icon(
                            _libraryDistances.containsKey(library.id)
                                ? Icons.directions
                                : Icons.location_on_outlined,
                            color: Colors.white.withOpacity(0.7),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _getFormattedLocation(library),
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

                // Show warning if already checked in to another library
                if (_isCheckedIntoLibrary &&
                    _currentLibraryId != library.id) ...[
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 10),
                        SizedBox(width: 4),
                        Text(
                          'Check out first',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
                // Book button - disabled if checked into another library
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                    (_isJoiningLibrary || !canBookNewSeat)
                        ? color.withOpacity(0.5)
                        : color,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: InkWell(
                    onTap:
                    canBookNewSeat && !_isJoiningLibrary
                        ? () => navigateToLibraryDetail(library)
                        : null,
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
                        canBookNewSeat
                            ? "Book a Seat"
                            : "Check Out First",
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

// Helper class for library distance data
class _LibraryWithDistance {
  final LibraryModel library;
  final double distanceKm;
  _LibraryWithDistance({required this.library, required this.distanceKm});
}