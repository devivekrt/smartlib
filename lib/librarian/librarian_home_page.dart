import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';

import 'package:smartlib/models/library_model.dart';
import 'package:smartlib/data/string.dart';

import '../library/library_edit_screen.dart';

class LibrarianHomePage extends StatefulWidget {
  const LibrarianHomePage({Key? key}) : super(key: key);

  @override
  State<LibrarianHomePage> createState() => _LibrarianHomePageState();
}

class _LibrarianHomePageState extends State<LibrarianHomePage> {
  // Navigation state
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Firebase instances
  final _firestore = FirebaseFirestore.instance;
  final _database = FirebaseDatabase.instance;

  // User and library data
  Map<String, dynamic> _librarianData = {};
  List<LibraryModel> _libraryModels = [];
  LibraryModel? _currentLibraryModel;
  List<Map<String, dynamic>> _libraries = []; // Legacy support
  Map<String, dynamic> _currentLibrary = {};
  Map<String, Map<String, dynamic>> _seats = {};

  // Dashboard data
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _todayBookings = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  Map<String, int> _occupancyByShift = {};
  List<String> _shifts = ['morning', 'afternoon', 'evening']; // Default shifts
  String? _selectedShift;

  // Bookings tab filters
  String _selectedDateRange = 'Today';
  List<String> _dateRanges = ['Today', 'This Week', 'This Month', 'Custom'];
  String _selectedStatus = 'All';
  List<String> _statuses = ['All', 'Confirmed', 'Pending'];
  List<Map<String, dynamic>> _bookingHistory = [];

  // Subscriptions for real-time data
  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _occupancySubscription;
  StreamSubscription? _pendingPaymentsSubscription;
  StreamSubscription? _seatsSubscription;

  // Loading states
  bool _isLoading = true;
  bool _isLoadingBookings = false;
  bool _isLoadingSeats = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLibrarianData();

    // Set up periodic refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _refreshTimer?.cancel();
    // Cancel all subscriptions
    _bookingsSubscription?.cancel();
    _occupancySubscription?.cancel();
    _pendingPaymentsSubscription?.cancel();
    _seatsSubscription?.cancel();
    super.dispose();
  }

  // Refresh all data
  void _refreshData() {
    if (!mounted) return;

    // Only refresh when on dashboard tab
    if (_currentIndex == 0) {
      _loadDashboardData();
      _fetchPendingPayments();
    }
  }

  // Load librarian profile data
  Future<void> _loadLibrarianData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Check if we have a valid user ID
      if (SmartLib.userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User ID not available. Please login again.'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      String userId = SmartLib.userId;

      // Get data from the direct path to this librarian's record
      DatabaseEvent librarianSnapshot =
          await FirebaseDatabase.instance
              .ref()
              .child("${SmartLib.constPath}/librarians/$userId")
              .once();

      if (librarianSnapshot.snapshot.exists) {
        // Get the librarian data directly
        Map<dynamic, dynamic>? librarianData =
            librarianSnapshot.snapshot.value as Map?;

        if (librarianData != null) {
          // Convert to type-safe map
          Map<String, dynamic> typeSafeData = {};

          librarianData.forEach((key, value) {
            if (value is num) {
              typeSafeData[key.toString()] = value.toDouble();
            } else {
              typeSafeData[key.toString()] = value;
            }
          });

          setState(() {
            _librarianData = typeSafeData;
          });

          // Load libraries managed by this librarian
          await _fetchLibraries();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Librarian profile is empty')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Librarian profile not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Load libraries managed by the librarian
  Future<void> _fetchLibraries() async {
    if (!mounted) return;

    try {
      String userId = SmartLib.userId;

      // STEP 1: Get all library IDs managed by this librarian from RTDB
      final databaseRef = FirebaseDatabase.instance.ref();
      final managedLibrariesSnapshot =
          await databaseRef
              .child(
                "${SmartLib.constPath}/librarians/$userId/managedLibraries",
              )
              .once();

      // Initialize empty library list
      List<Map<String, dynamic>> libraryList = [];
      List<LibraryModel> modelList = [];

      if (managedLibrariesSnapshot.snapshot.exists) {
        // Get the managed libraries map
        final managedLibraries = managedLibrariesSnapshot.snapshot.value;

        if (managedLibraries is Map) {
          // STEP 2: Fetch each library's details from Firestore
          final firestoreRef = FirebaseFirestore.instance.collection(
            'libraries',
          );

          // Use a for loop to handle async operations sequentially
          for (final entry in managedLibraries.entries) {
            final libraryId = entry.key.toString();

            try {
              // Get library document from Firestore
              final docSnapshot = await firestoreRef.doc(libraryId).get();

              if (docSnapshot.exists) {
                // Get library data and ensure libraryId is included
                final libraryData = docSnapshot.data() ?? {};
                libraryData['libraryId'] = libraryId;

                // Add to our list
                libraryList.add(libraryData);

                // Create LibraryModel and add to list
                final model = LibraryModel.fromMap(libraryData, libraryId);
                modelList.add(model);
              }
            } catch (e) {
            }
          }
        }
      }

      setState(() {
        _libraries = libraryList;
        _libraryModels = modelList;

        if (libraryList.isNotEmpty) {
          _currentLibrary = libraryList[0];
          _currentLibraryModel = modelList[0];

          // Check for shifts in the current library
          if (_currentLibraryModel != null) {
            _shifts =
                (_currentLibraryModel!.shifts).keys
                    .toList();
                    }

          // Default select first shift
          if (_shifts.isNotEmpty && _selectedShift == null) {
            _selectedShift = _shifts.first;
          }
        } else {
          _currentLibrary = {};
          _currentLibraryModel = null;
        }
      });

      // Only load dashboard data if we have libraries
      if (_libraries.isNotEmpty) {
        await _loadDashboardData();
        await _fetchPendingPayments();
        await _fetchSeats();
        await _fetchBookingHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load libraries: ${e.toString()}')),
        );
      }
    }
  }

  // Load dashboard data for the current library
  Future<void> _loadDashboardData() async {
    if (!mounted || _currentLibrary.isEmpty) return;

    // Cancel existing subscriptions
    _bookingsSubscription?.cancel();
    _occupancySubscription?.cancel();

    String libraryId = _currentLibrary['libraryId'];
    if (libraryId.isEmpty) return;

    final today = _formatDateToString(_selectedDate);

    try {
      // Listen for today's bookings
      _bookingsSubscription = _firestore
          .collection('seatBookings')
          .where('libraryId', isEqualTo: libraryId)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;

              List<Map<String, dynamic>> bookings = [];

              for (final doc in snapshot.docs) {
                final data = Map<String, dynamic>.from(doc.data());
                data['bookingId'] = doc.id;
                bookings.add(data);
              }

              // Calculate occupancy by shift
              Map<String, int> occupancyByShift = {};
              for (final shift in _shifts) {
                occupancyByShift[shift] = 0;
              }

              // Count bookings for each shift
              for (final booking in bookings) {
                // Handle the case where booking has multiple shifts
                if (booking['shifts'] != null && booking['shifts'] is List) {
                  for (final shiftData in booking['shifts']) {
                    if (shiftData is Map && shiftData['shiftId'] != null) {
                      final shiftId = shiftData['shiftId'];
                      if (occupancyByShift.containsKey(shiftId) &&
                          booking['status'] == 'booked') {
                        occupancyByShift[shiftId] =
                            (occupancyByShift[shiftId] ?? 0) + 1;
                      }
                    }
                  }
                }
                // Handle the case where booking has a single shiftId
                else if (booking['shiftId'] != null) {
                  final shiftId = booking['shiftId'];
                  if (occupancyByShift.containsKey(shiftId) &&
                      booking['status'] == 'booked') {
                    occupancyByShift[shiftId] =
                        (occupancyByShift[shiftId] ?? 0) + 1;
                  }
                }
              }

              setState(() {
                _todayBookings = bookings;
                _occupancyByShift = occupancyByShift;
              });
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error loading bookings: $error')),
                );
              }
            },
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up data streams: ${e.toString()}'),
          ),
        );
      }
    }
  }

  // Fetch pending payments for the current library
  Future<void> _fetchPendingPayments() async {
    // Cancel existing subscription
    _pendingPaymentsSubscription?.cancel();

    String libraryId = _currentLibrary['libraryId'];
    if (libraryId.isEmpty) return;

    try {
      // Listen for bookings with pending payments that need confirmation
      _pendingPaymentsSubscription = _firestore
          .collection('seatBookings')
          .where('paymentStatus', isEqualTo: 'pending')
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;

              List<Map<String, dynamic>> payments = [];

              for (final doc in snapshot.docs) {
                final data = Map<String, dynamic>.from(doc.data());
                data['bookingId'] = doc.id;
                payments.add(data);
              }

              setState(() {
                _pendingPayments = payments;
              });
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading pending payments: $error'),
                  ),
                );
              }
            },
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching pending payments: ${e.toString()}'),
          ),
        );
      }
    }
  }

  // Fetch all seats for current library
  Future<void> _fetchSeats() async {
    if (!mounted || _currentLibrary.isEmpty) return;

    setState(() {
      _isLoadingSeats = true;
    });

    _seatsSubscription?.cancel();
    String libraryId = _currentLibrary['libraryId'];

    try {
      // Listen for real-time seat data updates
      _seatsSubscription = _firestore
          .collection('libraries')
          .doc(libraryId)
          .snapshots()
          .listen(
            (snapshot) {
              final data = snapshot.data();
              if (data != null && data['seats'] != null) {
                Map<String, dynamic> seatsData = data['seats'];
                Map<String, Map<String, dynamic>> processedSeats = {};

                // Convert the seats data to a properly typed map
                seatsData.forEach((seatId, seatData) {
                  processedSeats[seatId] = Map<String, dynamic>.from(
                    seatData as Map,
                  );
                });

                setState(() {
                  _seats = processedSeats;
                  _isLoadingSeats = false;
                });
              } else {
                setState(() {
                  _seats = {};
                  _isLoadingSeats = false;
                });
              }
            },
            onError: (error) {
              setState(() {
                _isLoadingSeats = false;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error loading seats: $error')),
                );
              }
            },
          );
    } catch (e) {
      setState(() {
        _isLoadingSeats = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching seats: ${e.toString()}')),
        );
      }
    }
  }

  // Fetch booking history with structure and order
  Future<void> _fetchBookingHistory() async {
    if (!mounted || _currentLibrary.isEmpty) return;

    setState(() {
      _isLoadingBookings = true;
    });

    String libraryId = _currentLibrary['libraryId'];

    try {
      // Query for bookings with proper ordering
      final querySnapshot =
          await _firestore
              .collection('seatBookings')
              .where('libraryId', isEqualTo: libraryId)
              .limit(50)
              .get();

      List<Map<String, dynamic>> bookings = [];

      for (final doc in querySnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['bookingId'] = doc.id;

        // Ensure consistent date format for filtering
        if (data['bookedAt'] != null && data['bookedAt'] is String) {
          // Keep the date as is, but make sure it's valid
          try {
            DateTime.parse(data['bookedAt']);
          } catch (e) {
            // If date is invalid, use today's date
            data['bookedAt'] = _formatDateToString(DateTime.now());
          }
        } else if (data['date'] != null && data['date'] is String) {
          // Some records might use 'date' instead of 'bookedAt'
          data['bookedAt'] = data['date'];
        } else {
          // Default to today if no date is available
          data['bookedAt'] = _formatDateToString(DateTime.now());
        }

        bookings.add(data);
      }

      // Group bookings by date for structured display
      final Map<String, List<Map<String, dynamic>>> groupedBookings = {};
      for (final booking in bookings) {
        final date = booking['bookedAt'] ?? 'Unknown';
        if (!groupedBookings.containsKey(date)) {
          groupedBookings[date] = [];
        }
        groupedBookings[date]!.add(booking);
      }

      setState(() {
        _bookingHistory = bookings;
        _isLoadingBookings = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBookings = false;
        _bookingHistory = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading booking history: ${e.toString()}'),
          ),
        );
      }
    }
  }

  // Change the selected date
  void _changeDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadDashboardData();
  }

  // Change status filter
  void _changeStatusFilter(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  // Change date range filter
  void _changeDateRangeFilter(String range) {
    setState(() {
      _selectedDateRange = range;
    });

    // Update the selected date based on the range
    DateTime newDate;
    switch (range) {
      case 'Today':
        newDate = DateTime.now();
        break;
      case 'Yesterday':
        newDate = DateTime.now().subtract(const Duration(days: 1));
        break;
      case 'Last 7 Days':
        // Here we're just selecting today, but we'd load bookings for 7 days
        newDate = DateTime.now();
        break;
      case 'Last 30 Days':
        // Here we're just selecting today, but we'd load bookings for 30 days
        newDate = DateTime.now();
        break;
      default:
        newDate = DateTime.now();
    }
    _changeDate(newDate);
  }

  // Change shift
  void _changeShift(String shift) {
    setState(() {
      _selectedShift = shift;
    });
  }

  // Show search bookings dialog
  void _showSearchBookingsDialog() {
    TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Search Bookings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID or Seat Number',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Perform search
                  _searchBookings(searchController.text);
                  Navigator.of(context).pop();
                },
                child: const Text('Search'),
              ),
            ],
          ),
    );
  }

  // Search bookings by student ID or seat number
  void _searchBookings(String query) {
    if (query.isEmpty) {
      _fetchBookingHistory();
      return;
    }

    final searchResults =
        _bookingHistory.where((booking) {
          final studentId =
              booking['studentId']?.toString().toLowerCase() ?? '';
          final seatNo = booking['seatNo']?.toString().toLowerCase() ?? '';
          final searchTerm = query.toLowerCase();

          return studentId.contains(searchTerm) || seatNo.contains(searchTerm);
        }).toList();

    setState(() {
      _bookingHistory = searchResults;
    });
  }

  // Show seat details
  void _showSeatDetails(String seatId, String studentId) {
    final bookingsForSeat =
        _todayBookings.where((booking) => booking['seatNo'] == seatId).toList();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Seat $seatId Details'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bookingsForSeat.isEmpty
                      ? const Text('No bookings for this seat')
                      : Container(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: bookingsForSeat.length,
                          itemBuilder: (context, index) {
                            final booking = bookingsForSeat[index];
                            return ListTile(
                              title: Text(
                                'Shift: ${getShiftName(booking['shiftId'] ?? 'Unknown')}',
                              ),
                              subtitle: Text(
                                'Status: ${booking['status'] ?? 'Unknown'}',
                              ),
                              trailing: Text(
                                'Student ID: ${booking['studentId'] ?? 'Unknown'}',
                              ),
                            );
                          },
                        ),
                      ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Confirm payment for a booking
  Future<void> _confirmPayment(String bookingId) async {
    try {
      // Update the booking in Firestore
      await _firestore.collection('seatBookings').doc(bookingId).update({
        'paymentStatus': 'paid',
        'status': 'confirmed',
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
      });
      // Update current status
      await FirebaseDatabase.instance
          .ref()
          .child("users/students/${SmartLib.userId}/currentStatus")
          .update({"paymentStatus": 'paid'});

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh data
      _fetchBookingHistory();
      _fetchPendingPayments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Format date to string (YYYY-MM-DD)
  String _formatDateToString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Format weekday name
  String _getWeekdayName(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // Adjust for weekday index (1-7 to 0-6)
    final index = date.weekday - 1;
    if (index < 0 || index >= weekdays.length) return '';
    return weekdays[index];
  }

  // Helper to change libraries
  void _changeLibrary(int index) {
    if (index >= 0 && index < _libraryModels.length) {
      setState(() {
        _currentLibraryModel = _libraryModels[index];
        _currentLibrary = _libraries[index]; // Legacy support

        // Reset shift selection and update shifts list
        if (_currentLibraryModel != null) {
          _shifts =
              (_currentLibraryModel!.shifts as Map<String, dynamic>).keys
                  .toList();
                }

        // Default select first shift
        if (_shifts.isNotEmpty) {
          _selectedShift = _shifts.first;
        } else {
          _selectedShift = null;
        }
      });

      // Load data for the new library
      _loadDashboardData();
      _fetchPendingPayments();
      _fetchSeats();
      _fetchBookingHistory();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${_currentLibraryModel!.libraryName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Get shift name from shift ID
  String getShiftName(String shiftId) {
    if (_currentLibraryModel != null) {
      // Try to get shift name from library model
      final shifts = _currentLibraryModel!.shifts;
      if (shifts.containsKey(shiftId) &&
          shifts[shiftId] is Map) {
        final shiftData = shifts[shiftId] as Map;
        if (shiftData.containsKey('name')) {
          return shiftData['name'].toString();
        }
      }
    }

    // Default shift names
    switch (shiftId) {
      case 'morning':
        return 'Morning Shift';
      case 'afternoon':
        return 'Afternoon Shift';
      case 'evening':
        return 'Evening Shift';
      default:
        return 'Shift $shiftId';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentLibraryModel?.libraryName ?? 'Library Dashboard',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? _buildLoadingScreen()
              : PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: [
                  _buildDashboardTab(),
                  _buildBookingsTab(),
                  _buildSeatsTab(),
                  _buildProfileTab(),
                ],
              ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xff1940CC),
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(Icons.calendar_month),
                if (_pendingPayments.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        '${_pendingPayments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Bookings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_seat),
            label: 'Seats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Loading screen
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: const Color(0xff1940CC)),
          const SizedBox(height: 16),
          const Text('Loading library data...'),
        ],
      ),
    );
  }

  // Dashboard tab view
  Widget _buildDashboardTab() {
    // Check if we have a valid library model
    if (_currentLibraryModel == null) {
      return const Center(child: Text("No library selected"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Library Overview Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          // Access libraryName directly from the root
                          _currentLibrary['libraryName'] ?? 'Library',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          // Navigate to library settings
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => LibraryEditScreen(
                                    librarianId: SmartLib.userId,
                                    libraryId: SmartLib.libraryId,
                                  ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Gap(8),

                  // Address - format it from the address map or use the location string
                  Text(
                    _formatAddress() ??
                        _currentLibrary['location'] ??
                        'Address not available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statItem(
                        "Total Seats",
                        // Access totalSeats directly from the root
                        _currentLibrary['totalSeats']?.toString() ?? '0',
                        Icons.chair,
                      ),
                      _statItem(
                        "Today's Bookings",
                        _todayBookings.length.toString(),
                        Icons.calendar_today,
                      ),
                      _statItem(
                        "Pending Payments",
                        _pendingPayments.length
                            .toString(), // New: Show pending payments count
                        Icons.payment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Date Selector Card
          const Gap(20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Date",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(7, (index) {
                        final date = DateTime.now().add(
                          Duration(days: index - 3),
                        );
                        final isSelected =
                            _formatDateToString(date) ==
                            _formatDateToString(_selectedDate);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () => _changeDate(date),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _getWeekdayName(date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    date.day.toString(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Occupancy Chart
          const Gap(20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Occupancy by Shift",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildOccupancyChart(),
                ],
              ),
            ),
          ),

          // Quick Actions
          const Gap(20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Quick Actions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _actionButton("View Bookings", Icons.calendar_today, () {
                        // Navigate to bookings tab
                        setState(() => _currentIndex = 1);
                      }),
                      _actionButton("Manage Seats", Icons.event_seat, () {
                        // Navigate to seat management tab
                        setState(() => _currentIndex = 3);
                      }),
                      _actionButton("Payments", Icons.payment, () {
                        // Navigate to payments tab
                        setState(() => _currentIndex = 2);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pending Payments Banner (New)
          if (_pendingPayments.isNotEmpty)
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.orange[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: Colors.orange[800]),
                        const SizedBox(width: 8),
                        Text(
                          "${_pendingPayments.length} Pending Payments",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You have payments that need confirmation",
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // Navigate to payments tab
                          setState(() => _currentIndex = 2);
                        },
                        child: const Text("View Payments"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Recent Activity
          const Gap(20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Recent Activity",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _todayBookings.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No recent activity"),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            _todayBookings.length > 5
                                ? 5
                                : _todayBookings.length,
                        itemBuilder: (context, index) {
                          final booking = _todayBookings[index];
                          Icon leadingIcon;

                          if (booking['checkInTime'] != null &&
                              booking['checkOutTime'] == null) {
                            leadingIcon = const Icon(
                              Icons.login,
                              color: Colors.green,
                            );
                          } else if (booking['checkOutTime'] != null) {
                            leadingIcon = const Icon(
                              Icons.logout,
                              color: Colors.blue,
                            );
                          } else {
                            leadingIcon = const Icon(
                              Icons.calendar_today,
                              color: Colors.orange,
                            );
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              child: leadingIcon,
                            ),
                            title: Text(
                              'Seat ${booking['seatNo'] ?? 'Unknown'} - ${booking['shiftId'] ?? 'Unknown'} shift',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Student ID: ${booking['studentId'] ?? 'Unknown'}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: Text(
                              booking['status'] ?? 'Unknown',
                              style: TextStyle(
                                color:
                                    (booking['status'] == 'confirmed')
                                        ? Colors.green
                                        : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                  if (_todayBookings.length > 5)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          // Navigate to view all bookings
                          setState(() => _currentIndex = 1);
                        },
                        child: const Text("View All"),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to format the address from the address map
  String? _formatAddress() {
    final addressMap = _currentLibrary['address'];
    if (addressMap is Map) {
      // Format the address components
      final List<String> components = [];
      if (addressMap['street'] != null) components.add(addressMap['street']);
      if (addressMap['city'] != null) components.add(addressMap['city']);
      if (addressMap['state'] != null) components.add(addressMap['state']);
      if (addressMap['zipCode'] != null) components.add(addressMap['zipCode']);

      if (components.isNotEmpty) {
        return components.join(', ');
      }
    }
    return null;
  }

  // Build custom occupancy chart with enhanced UI
  Widget _buildOccupancyChart() {
    final maxOccupancy = _occupancyByShift.values.fold(
      0,
      (max, value) => value > max ? value : max,
    );

    // Use the library model to get total seats
    final maxCapacity = _currentLibraryModel?.totalSeats ?? 100;

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children:
            _shifts.map((shift) {
              final occupancy = _occupancyByShift[shift] ?? 0;
              // Ensure bar height is at least 20% of container height for visibility
              final percentage = maxCapacity > 0 ? occupancy / maxCapacity : 0;
              final barHeight =
                  160 * (percentage > 0.05 ? percentage : 0.05).toDouble();

              // Get the shift name from the library model
              final shiftName = getShiftName(shift);

              // Determine color based on shift key
              Color shiftColor;
              if (shift == 'morning') {
                shiftColor = Colors.orange;
              } else if (shift == 'afternoon') {
                shiftColor = Colors.blue;
              } else if (shift == 'evening') {
                shiftColor = Colors.purple;
              } else {
                // Derive color from shift name to ensure consistency
                final hashCode = shift.hashCode;
                final hue = (hashCode % 360).toDouble();
                shiftColor = HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    occupancy.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 40,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: shiftColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shiftColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Tooltip(
                    message: shiftName,
                    child: Text(
                      // Show an abbreviation of the shift name
                      shift.substring(0, min(3, shift.length)).toUpperCase(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  // Helper widget for action buttons
  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.blue[700], size: 24),
            ),
            const Gap(8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // Helper widget for stats items
  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 24),
        ),
        const Gap(8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // Build bookings tab with history and filtering
  Widget _buildBookingsTab() {
    // Filter bookings based on current selections
    List<Map<String, dynamic>> filteredBookings = _bookingHistory;

    // Apply status filter
    if (_selectedStatus != 'All') {
      filteredBookings =
          filteredBookings
              .where(
                (booking) =>
                    booking['status']?.toString().toLowerCase() ==
                    _selectedStatus.toLowerCase(),
              )
              .toList();
    }

    // Apply date range filter
    if (_selectedDateRange != 'All') {
      filteredBookings = _applyDateRangeFilter(
        filteredBookings,
        _selectedDateRange,
      );
    }

    // Group filtered bookings by date
    final Map<String, List<Map<String, dynamic>>> groupedFilteredBookings = {};
    for (final booking in filteredBookings) {
      final date = booking['bookedAt'] ?? 'Unknown';
      if (!groupedFilteredBookings.containsKey(date)) {
        groupedFilteredBookings[date] = [];
      }
      groupedFilteredBookings[date]!.add(booking);
    }

    // Get sorted dates (most recent first)
    final List<String> sortedDates =
        groupedFilteredBookings.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Filter section
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range selector
              Row(
                children: [
                  const Text(
                    'Date Range:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),
                  DropdownButton<String>(
                    value: _selectedDateRange,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _changeDateRangeFilter(newValue);
                      }
                    },
                    items:
                        _dateRanges.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                  ),
                ],
              ),

              const Gap(8),

              // Status filter and search button
              Row(
                children: [
                  // Status filter
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'Status:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Gap(8),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedStatus,
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                _changeStatusFilter(newValue);
                              }
                            },
                            items:
                                _statuses.map<DropdownMenuItem<String>>((
                                  String value,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search button
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _showSearchBookingsDialog,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bookings count summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${filteredBookings.length} bookings',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                onPressed: _fetchBookingHistory,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Bookings list with pull to refresh
        Expanded(
          child:
              _isLoadingBookings
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading bookings...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                  : filteredBookings.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No bookings found",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Try changing your filters",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Data'),
                          onPressed: _fetchBookingHistory,
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _fetchBookingHistory,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      // Build one item per date group + bookings within that date
                      itemCount: sortedDates.length,
                      itemBuilder: (context, dateIndex) {
                        final date = sortedDates[dateIndex];
                        final dateBookings = groupedFilteredBookings[date]!;

                        // Format date for display
                        String displayDate = 'Unknown Date';
                        try {
                          final dateObj = DateTime.parse(date);
                          final now = DateTime.now();
                          final yesterday = DateTime.now().subtract(
                            const Duration(days: 1),
                          );

                          if (dateObj.year == now.year &&
                              dateObj.month == now.month &&
                              dateObj.day == now.day) {
                            displayDate = 'Today';
                          } else if (dateObj.year == yesterday.year &&
                              dateObj.month == yesterday.month &&
                              dateObj.day == yesterday.day) {
                            displayDate = 'Yesterday';
                          } else {
                            displayDate = DateFormat(
                              'EEE, MMM d, yyyy',
                            ).format(dateObj);
                          }
                        } catch (e) {
                          // Keep default if parsing fails
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                right: 16.0,
                                top: 16.0,
                                bottom: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    displayDate,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      '${dateBookings.length}',
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bookings for this date
                            ...dateBookings.map((booking) {
                              // Define the card background color based on status
                              Color cardColor = Colors.white;
                              if (booking['status'] == 'confirmed') {
                                if (booking['checkInTime'] != null) {
                                  cardColor = Colors.green[50]!;
                                } else {
                                  cardColor = Colors.blue[50]!;
                                }
                              } else if (booking['status'] == 'pending') {
                                cardColor = Colors.orange[50]!;
                              } else if (booking['status'] == 'canceled') {
                                cardColor = Colors.grey[100]!;
                              }

                              // Check if payment needs confirmation
                              final needsPaymentConfirmation =
                                  (booking['paymentMethod'] == 'cash' ||
                                      booking['paymentMethod'] ==
                                          'pay to owner') &&
                                  booking['paymentStatus'] == 'pending';

                              return Card(
                                margin: const EdgeInsets.only(
                                  bottom: 8.0,
                                  left: 8.0,
                                  right: 8.0,
                                ),
                                color: cardColor,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            booking['status'] == 'confirmed'
                                                ? booking['checkInTime'] != null
                                                    ? Colors.green[100]
                                                    : Colors.blue[100]
                                                : booking['status'] == 'pending'
                                                ? Colors.orange[100]
                                                : Colors.grey[200],
                                        child: Text(
                                          booking['seatNo'] ?? 'N/A',
                                          style: TextStyle(
                                            color:
                                                booking['status'] == 'confirmed'
                                                    ? booking['checkInTime'] !=
                                                            null
                                                        ? Colors.green[800]
                                                        : Colors.blue[800]
                                                    : booking['status'] ==
                                                        'pending'
                                                    ? Colors.orange[800]
                                                    : Colors.grey[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Student: ${booking['studentId'] ?? 'Unknown'}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 2.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  booking['status'] ==
                                                          'confirmed'
                                                      ? Colors.green[100]
                                                      : booking['status'] ==
                                                          'pending'
                                                      ? Colors.orange[100]
                                                      : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                            ),
                                            child: Text(
                                              booking['status'] ?? 'Unknown',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    booking['status'] ==
                                                            'confirmed'
                                                        ? Colors.green[800]
                                                        : booking['status'] ==
                                                            'pending'
                                                        ? Colors.orange[800]
                                                        : Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),

                                          // Booking details
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                getShiftName(
                                                  booking['shiftId'] ??
                                                      'Unknown',
                                                ),
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              const Icon(
                                                Icons.confirmation_number,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Booking ID: ${booking['bookingId'].toString().substring(0, min(8, booking['bookingId'].toString().length))}...',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Show payment status - Fixed overflow issue
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.payment,
                                                size: 14,
                                                color:
                                                    booking['paymentStatus'] ==
                                                            'paid'
                                                        ? Colors.green[700]
                                                        : Colors.red[700],
                                              ),
                                              const SizedBox(width: 4),
                                              // Wrap the text in Flexible to allow it to shrink if needed
                                              Flexible(
                                                child: Text(
                                                  'Payment: ${booking['paymentStatus'] ?? 'pending'}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        booking['paymentStatus'] ==
                                                                'paid'
                                                            ? Colors.green[700]
                                                            : Colors.red[700],
                                                  ),
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis, // Allow text to truncate with ellipsis
                                                ),
                                              ),
                                              if (needsPaymentConfirmation)
                                                Flexible(
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ), // Reduced margin
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              4, // Reduced padding
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Needs confirmation',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize:
                                                            9, // Slightly smaller font
                                                      ),
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis, // Allow text to truncate
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.more_vert),
                                        onPressed: () {
                                          // Show booking details dialog
                                          _showBookingDetailsDialog(booking);
                                        },
                                      ),
                                    ),
                                    if (needsPaymentConfirmation)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          12,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () {
                                                // Implement reject data
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (context) => AlertDialog(
                                                        title: const Text(
                                                          'Reject Payment?',
                                                        ),
                                                        content: const Text(
                                                          'Are you sure you want to reject this payment? This will cancel the booking.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            style:
                                                                ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              // Add rejection implementation
                                                            },
                                                            child: const Text(
                                                              'Reject',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: const Text('Reject'),
                                            ),
                                            const SizedBox(width: 12),
                                            ElevatedButton(
                                              onPressed:
                                                  () => _confirmPayment(
                                                    booking['bookingId'],
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text(
                                                'Confirm Payment',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  // Helper method to show booking details dialog
  void _showBookingDetailsDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.event_seat, color: Colors.blue[700]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking Details',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Seat ${booking['seatNo'] ?? 'N/A'} - ${getShiftName(booking['shiftId'] ?? 'Unknown')}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Details
                  _buildDetailRow(
                    'Student ID:',
                    booking['studentId'] ?? 'Unknown',
                    Icons.person,
                  ),
                  _buildDetailRow(
                    'Date:',
                    booking['bookedAt'] ?? 'Unknown',
                    Icons.calendar_today,
                  ),
                  _buildDetailRow(
                    'Status:',
                    booking['status'] ?? 'Unknown',
                    Icons.info_outline,
                  ),
                  _buildDetailRow(
                    'Payment:',
                    booking['paymentStatus'] ?? 'pending',
                    Icons.payment,
                  ),
                  _buildDetailRow(
                    'Method:',
                    booking['paymentMethod'] ?? 'Unknown',
                    Icons.credit_card,
                  ),
                  _buildDetailRow(
                    'Booking ID:',
                    booking['bookingId'] ?? 'Unknown',
                    Icons.confirmation_number,
                  ),

                  if (booking['checkInTime'] != null)
                    _buildDetailRow(
                      'Check-in Time:',
                      booking['checkInTime'],
                      Icons.login,
                    ),

                  if (booking['checkOutTime'] != null)
                    _buildDetailRow(
                      'Check-out Time:',
                      booking['checkOutTime'],
                      Icons.logout,
                    ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      if (booking['paymentStatus'] == 'pending' &&
                          (booking['paymentMethod'] == 'cash' ||
                              booking['paymentMethod'] == 'pay to owner'))
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _confirmPayment(booking['bookingId']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirm Payment'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Helper method to apply date range filter
  List<Map<String, dynamic>> _applyDateRangeFilter(
    List<Map<String, dynamic>> bookings,
    String rangeType,
  ) {
    final now = DateTime.now();

    switch (rangeType) {
      case 'Today':
        final today = _formatDateToString(now);
        return bookings.where((booking) {
          return booking['bookedAt'] == today;
        }).toList();

      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));

        return bookings.where((booking) {
          try {
            final bookingDate = DateTime.parse(booking['bookedAt']);
            return !bookingDate.isBefore(startOfWeek) &&
                !bookingDate.isAfter(endOfWeek);
          } catch (_) {
            return false;
          }
        }).toList();

      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        return bookings.where((booking) {
          try {
            final bookingDate = DateTime.parse(booking['bookedAt']);
            return !bookingDate.isBefore(startOfMonth) &&
                !bookingDate.isAfter(endOfMonth);
          } catch (_) {
            return false;
          }
        }).toList();

      case 'Custom':
        // This would use a date range picker
        return bookings;

      default:
        return bookings;
    }
  }

  // Helper method for building detail rows in dialog
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Seats tab with enhanced UI
  Widget _buildSeatsTab() {
    // Filter bookings for today and selected shift
    final bookingsForToday =
        _todayBookings
            .where((b) => b['bookedAt'] == _formatDateToString(_selectedDate))
            .toList();

    // Create a properly typed list for bookingsForShift
    List<Map<String, dynamic>> typedBookingsForShift = [];

    // Only populate if we have a selected shift
    if (_selectedShift != null) {
      for (final booking in bookingsForToday) {
        if (booking['shiftId'] == _selectedShift) {
          // Ensure each booking is properly typed as Map<String, dynamic>
          typedBookingsForShift.add(Map<String, dynamic>.from(booking));
        }
      }
    }
    // Helper to check if two dates are the same day
    bool isSameDay(DateTime date1, DateTime date2) {
      return date1.year == date2.year &&
          date1.month == date2.month &&
          date1.day == date2.day;
    }

    // Create shift data structure
    Map<String, Map<String, dynamic>> shiftsData = {};
    if (_currentLibraryModel?.shifts != null) {
      shiftsData = Map<String, Map<String, dynamic>>.from(
        _currentLibraryModel!.shifts,
      );
    }

    return Column(
      children: [
        // Enhanced but simplified date selection component
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Date',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Simple date selection with 7 days
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7, // Show one week of dates
                  itemBuilder: (context, index) {
                    // Generate dates from 3 days ago to 3 days ahead
                    final date = DateTime.now().add(Duration(days: index - 3));

                    final isToday = isSameDay(date, DateTime.now());
                    final isSelected = isSameDay(date, _selectedDate);

                    return GestureDetector(
                      onTap: () {
                        // Use simpler approach: call setState directly
                        setState(() {
                          _selectedDate = date;
                        });

                        // Refresh data if needed
                        _loadDashboardData();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 65,
                        decoration: BoxDecoration(
                          gradient:
                              isSelected
                                  ? LinearGradient(
                                    colors: [
                                      const Color(0xff1940CC),
                                      const Color(0xff1940CC).withOpacity(0.8),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                  : null,
                          color:
                              isSelected
                                  ? null
                                  : isToday
                                  ? const Color(0xff1940CC).withOpacity(0.1)
                                  : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border:
                              isToday && !isSelected
                                  ? Border.all(color: const Color(0xff1940CC))
                                  : null,
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xff1940CC,
                                      ).withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Day name (Mon, Tue, etc.)
                            Text(
                              [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun',
                              ][date.weekday - 1],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Day number
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : isToday
                                        ? const Color(0xff1940CC)
                                        : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Month name (short)
                            Text(
                              [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ][date.month - 1],
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Debug info
              const SizedBox(height: 4),
              Text(
                'Tap on a date to select it',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Shift selection with improved UI
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Shift:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children:
                        _shifts.map((shiftId) {
                          final isSelected = _selectedShift == shiftId;

                          // Determine shift color based on index
                          Color shiftColor;
                          int index = _shifts.indexOf(shiftId);
                          switch (index % 3) {
                            case 0:
                              shiftColor = Colors.blue;
                              break;
                            case 1:
                              shiftColor = Colors.amber;
                              break;
                            default:
                              shiftColor = Colors.deepPurple;
                          }

                          // Get shift details from library model if available
                          Map<String, dynamic> shiftDetails = {};
                          if (shiftsData.containsKey(shiftId)) {
                            shiftDetails = shiftsData[shiftId]!;
                          }

                          final shiftName =
                              shiftDetails['name'] ?? getShiftName(shiftId);
                          final startTime =
                              shiftDetails['startTime'] ?? '00:00';
                          final endTime = shiftDetails['endTime'] ?? '00:00';

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => _changeShift(shiftId),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient:
                                      isSelected
                                          ? LinearGradient(
                                            colors: [
                                              shiftColor,
                                              shiftColor.withOpacity(0.7),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                          : null,
                                  color: isSelected ? null : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? shiftColor
                                            : Colors.grey.shade400,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : shiftColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          shiftName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? Colors.white.withOpacity(0.3)
                                                : shiftColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$startTime - $endTime",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : shiftColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Enhanced seat legend with partial booking status
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seat Status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildEnhancedLegendItem(Colors.green, 'Available'),
                      const SizedBox(width: 16),
                      _buildEnhancedLegendItem(Colors.orange, 'Pending'),
                      const SizedBox(width: 16),
                      _buildEnhancedLegendItem(Colors.red, 'Booked'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Seat map grid
        Expanded(
          child:
              _isLoadingSeats
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedShift == null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_seat_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a shift to view seats',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                  : _seats.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No seats found for this library',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                  : _buildEnhancedSeatMap(typedBookingsForShift),
        ),
      ],
    );
  }

  // Enhanced version of legend item
  Widget _buildEnhancedLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // Enhanced seat map with grid view and partial booking support
  Widget _buildEnhancedSeatMap(List<Map<String, dynamic>> bookingsForShift) {
    // Create a map of seat status and student IDs based on bookings
    Map<String, String> seatStatus = {};
    Map<String, String> seatStudentIds = {};

    for (final booking in bookingsForShift) {
      final seatNo = booking['seatNo'];
      if (seatNo != null && seatNo is String) {
        seatStatus[seatNo] = booking['status'] ?? 'available';
        seatStudentIds[seatNo] = booking['studentId'] ?? '';
      }
    }

    // Process seats into rows for better organization
    Map<String, List<MapEntry<String, Map<String, dynamic>>>> seatsByRow = {};

    for (var entry in _seats.entries) {
      final seatId = entry.key;
      if (seatId.isNotEmpty) {
        try {
          final row = seatId.substring(0, 1).toUpperCase();
          if (!seatsByRow.containsKey(row)) {
            seatsByRow[row] = [];
          }
          seatsByRow[row]!.add(entry);
        } catch (e) {
        }
      }
    }

    // Sort rows alphabetically
    final sortedRows = seatsByRow.keys.toList()..sort();

    if (sortedRows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_seat_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No seat layout available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'This library doesn\'t have a configured seat layout',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          ...sortedRows.map((row) {
            // Sort seats within the row by seat number
            final seatsInRow = seatsByRow[row]!;
            seatsInRow.sort((a, b) {
              try {
                final numA = int.tryParse(a.key.substring(1)) ?? 0;
                final numB = int.tryParse(b.key.substring(1)) ?? 0;
                return numA.compareTo(numB);
              } catch (_) {
                return a.key.compareTo(b.key);
              }
            });

            // If row has more than 10 seats, split into multiple rows
            List<Widget> rowWidgets = [];
            if (seatsInRow.length <= 10) {
              // Single row layout
              rowWidgets.add(
                _buildSeatsRowWithHeader(
                  row,
                  seatsInRow,
                  seatStatus,
                  seatStudentIds,
                ),
              );
            } else {
              // Split into multiple sub-rows
              int chunksCount = (seatsInRow.length / 10).ceil();
              for (int i = 0; i < chunksCount; i++) {
                int startIdx = i * 10;
                int endIdx = min(startIdx + 10, seatsInRow.length);

                List<MapEntry<String, Map<String, dynamic>>> subRow = seatsInRow
                    .sublist(startIdx, endIdx);

                rowWidgets.add(
                  _buildSeatsRowWithHeader(
                    i == 0 ? row : '',
                    subRow,
                    seatStatus,
                    seatStudentIds,
                    isSubRow: i > 0,
                    rowIndicator: i > 0 ? "$row${i + 1}" : null,
                  ),
                );
              }
            }

            return Column(children: rowWidgets);
          }),
        ],
      ),
    );
  }

  // Helper to build a row of seats with header
  Widget _buildSeatsRowWithHeader(
    String row,
    List<MapEntry<String, Map<String, dynamic>>> seats,
    Map<String, String> seatStatus,
    Map<String, String> seatStudentIds, {
    bool isSubRow = false,
    String? rowIndicator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of seats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:
                  seats.map((entry) {
                    final seatId = entry.key;
                    final seatData = entry.value;

                    // Extract seat number (removing the row letter)
                    final seatNumber =
                        seatId.length > 1 ? seatId.substring(1) : seatId;

                    // Check shift status for this seat
                    bool isPartiallyBooked = false;
                    String status = 'available';
                    String studentId = '';

                    // First check if there's an active booking for this seat
                    if (seatStatus.containsKey(seatId)) {
                      status = seatStatus[seatId]!;
                      studentId = seatStudentIds[seatId] ?? '';
                    }
                    // Otherwise check the seat data structure
                    else if (seatData.containsKey('shifts')) {
                      Map<String, dynamic> shiftsData = seatData['shifts'];
                      int availableShifts = 0;
                      int bookedShifts = 0;

                      // Check all shifts status
                      for (var shift in shiftsData.entries) {
                        if (shift.value is Map &&
                            shift.value['status'] != null) {
                          if (shift.value['status'] == 'available') {
                            availableShifts++;
                          } else if (shift.value['status'] == 'booked' ||
                              shift.value['status'] == 'confirmed') {
                            bookedShifts++;
                          }
                        }
                      }

                      // Check selected shift status specifically
                      if (_selectedShift != null &&
                          shiftsData.containsKey(_selectedShift)) {
                        final shiftData = shiftsData[_selectedShift];
                        if (shiftData is Map &&
                            shiftData.containsKey('status')) {
                          status = shiftData['status'].toString();
                        }
                      }

                      // Check if partially booked (some shifts available, some booked)
                      isPartiallyBooked =
                          availableShifts > 0 && bookedShifts > 0;
                                        }

                    // Determine color based on status
                    Color seatColor;
                    switch (status.toLowerCase()) {
                      case 'confirmed':
                      case 'booked':
                        seatColor = Colors.red;
                        break;
                      case 'pending':
                        seatColor = Colors.orange;
                        break;
                      case 'unavailable':
                        seatColor = Colors.grey;
                        break;
                      case 'available':
                      default:
                        seatColor =
                            isPartiallyBooked ? Colors.amber : Colors.green;
                    }

                    return Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => _showSeatDetails(seatId, studentId),
                        child: Container(
                          decoration: BoxDecoration(
                            color: seatColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Seat number
                              Text(
                                '$row $seatNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              // Indicator if seat has student
                              if (studentId.isNotEmpty || isPartiallyBooked)
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    height: 8,
                                    width: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // Profile Tab
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Librarian profile card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Image or Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _librarianData['photoURL'] != null &&
                              _librarianData['photoURL'].toString().isNotEmpty
                          ? CircleAvatar(
                            radius: 50,
                            backgroundImage: NetworkImage(
                              _librarianData['photoURL'],
                            ),
                            backgroundColor: Colors.grey[300],
                          )
                          : CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xff1940CC),
                            child: Text(
                              _getInitials(
                                _librarianData['fullName'] ??
                                    _librarianData['name'] ??
                                    'L',
                              ),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () {
                            // Handle photo change
                          },
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Color(0xff1940CC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Librarian Name
                  Text(
                    _librarianData['fullName'] ??
                        _librarianData['name'] ??
                        'Librarian',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(8),

                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff1940CC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _librarianData['role'] ?? 'Librarian',
                      style: const TextStyle(
                        color: Color(0xff1940CC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Gap(12),

                  // Librarian Email and phone
                  Text(
                    _librarianData['email'] ?? SmartLib.email ?? '',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),

                  if (_librarianData['phone'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        _librarianData['phone'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Personal info rows
                  _buildProfileInfoRow(
                    Icons.app_registration,
                    'Member Since',
                    _formatDate(_librarianData['joinDate']),
                  ),

                  _buildProfileInfoRow(
                    Icons.verified_user,
                    'Account Status',
                    'Active',
                    valueColor: Colors.green,
                  ),

                  if (_librarianData['lastLogin'] != null)
                    _buildProfileInfoRow(
                      Icons.access_time,
                      'Last Active',
                      _formatTimeAgo(_librarianData['lastLogin']),
                    ),

                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile"),
                    onPressed: () {
                      // Navigate to edit profile
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff1940CC),
                      side: const BorderSide(color: Color(0xff1940CC)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Gap(20),

          // Libraries managed
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Libraries Managed",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _libraryModels.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "No libraries found",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _libraryModels.length,
                        itemBuilder: (context, index) {
                          final library = _libraryModels[index];
                          final isCurrentLibrary =
                              library.id == _currentLibraryModel?.id;

                          // Get the first letter of the library name for the avatar
                          final String libraryName =
                              library.libraryName ?? 'Library';
                          final String firstLetter =
                              libraryName.isNotEmpty
                                  ? libraryName[0].toUpperCase()
                                  : 'L';

                          // Format address or location for subtitle
                          String address = '';
                          if (library.address != null) {
                            final addressMap = library.address!;
                            final components = <String>[];
                            if (addressMap['street'] != null) {
                              components.add(addressMap['street']);
                            }
                            if (addressMap['city'] != null) {
                              components.add(addressMap['city']);
                            }
                            address = components.join(', ');
                          } else if (library.location != null) {
                            address = library.location!;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color:
                                isCurrentLibrary
                                    ? const Color(0xff1940CC).withOpacity(0.05)
                                    : null,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color:
                                    isCurrentLibrary
                                        ? const Color(
                                          0xff1940CC,
                                        ).withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: CircleAvatar(
                                backgroundColor:
                                    isCurrentLibrary
                                        ? const Color(0xff1940CC)
                                        : Colors.grey[200],
                                child: Text(
                                  firstLetter,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isCurrentLibrary
                                            ? Colors.white
                                            : Colors.black,
                                  ),
                                ),
                              ),
                              title: Text(
                                libraryName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isCurrentLibrary
                                          ? const Color(0xff1940CC)
                                          : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  if (library.totalSeats != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${library.totalSeats} seats • ${library.students ?? 0} students',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing:
                                  isCurrentLibrary
                                      ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                      : IconButton(
                                        icon: const Icon(
                                          Icons.swap_horiz,
                                          color: Color(0xff1940CC),
                                        ),
                                        onPressed: () => _changeLibrary(index),
                                      ),
                              onTap: () {
                                if (!isCurrentLibrary) {
                                  _changeLibrary(index);
                                }
                              },
                            ),
                          );
                        },
                      ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add New Library"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff1940CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        // Navigate to add library screen
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Gap(20),

          // Settings and logout
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _settingsItem("App Settings", Icons.settings, () {
                  // Navigate to settings
                }, showDivider: true),
                _settingsItem("Help & Support", Icons.help_outline, () {
                  // Navigate to help
                }, showDivider: true),
                _settingsItem("About", Icons.info_outline, () {
                  // Show about dialog
                  showAboutDialog(
                    context: context,
                    applicationName: "Library Management App",
                    applicationVersion: "1.0.0",
                    applicationLegalese: "© 2025 All Rights Reserved",
                  );
                }, showDivider: true),
                _settingsItem(
                  "Logout",
                  Icons.logout,
                  () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      // Navigate to login screen after logout
                      Navigator.of(context).pushReplacementNamed('/login');
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error signing out: ${e.toString()}'),
                        ),
                      );
                    }
                  },
                  textColor: Colors.red,
                  iconColor: Colors.red,
                ),
              ],
            ),
          ),

          const Gap(20),

          // Version and current date-time information
          Center(
            child: Column(
              children: [
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Helper widget for profile info rows
  Widget _buildProfileInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for settings items
  Widget _settingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color? textColor,
    Color? iconColor,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor ?? const Color(0xff1940CC)),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  // Helper to get initials from name
  String _getInitials(String name) {
    if (name.isEmpty) return 'L';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }

    return 'L';
  }

  // Format date nicely
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return 'N/A';
      }

      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  // Format time ago
  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays != 1 ? "s" : ""} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours != 1 ? "s" : ""} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes != 1 ? "s" : ""} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'N/A';
    }
  }
}
