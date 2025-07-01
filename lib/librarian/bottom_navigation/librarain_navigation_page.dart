import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' show min;
import 'package:gap/gap.dart';

import '../../data/string.dart';
import 'librarain_booking_page.dart';
import 'librarain_dashboard_page.dart';
import 'librarain_profile_page.dart';
import 'librarain_seats_page.dart';

class LibrarianNavigationPage extends StatefulWidget {
  const LibrarianNavigationPage({Key? key}) : super(key: key);

  @override
  State<LibrarianNavigationPage> createState() => _LibrarianNavigationPageState();
}

class _LibrarianNavigationPageState extends State<LibrarianNavigationPage> {
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
  //fetch get student id from seatBooking


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
      if (SmartLib.userId == null || SmartLib.userId.isEmpty) {
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
      await _database
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
      final databaseRef = _database.ref();
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
          final firestoreRef = _firestore.collection('libraries');

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
              print('Error fetching library $libraryId: $e');
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
          if (_currentLibraryModel != null &&
              _currentLibraryModel!.shifts != null) {
            if (_currentLibraryModel!.shifts is Map<String, dynamic>) {
              _shifts =
                  (_currentLibraryModel!.shifts as Map<String, dynamic>).keys
                      .toList();
            }
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

    String? libraryId = _currentLibrary['libraryId'];
    if (libraryId == null || libraryId.isEmpty) return;

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

    String? libraryId = _currentLibrary['libraryId'];
    if (libraryId == null || libraryId.isEmpty) return;

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
    String? libraryId = _currentLibrary['libraryId'];
    if (libraryId == null) return;

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

    String? libraryId = _currentLibrary['libraryId'];
    if (libraryId == null) return;

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

  // Change shift - FROM UPDATED CODE
  void _changeShift(String shift) {
    setState(() {
      _selectedShift = shift;
    });
  }

  // Show search bookings dialog - FROM UPDATED CODE
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
              _searchBookings(searchController.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  // Search bookings by student ID or seat number - FROM UPDATED CODE
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


// Confirm payment for a booking - UPDATED with student ID handling and subscriber status update
  Future<void> _confirmPayment(String bookingId) async {
    try {
      // First get the booking details to extract student ID
      final bookingDoc = await _firestore.collection('seatBookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data();
      if (bookingData == null) {
        throw Exception('Booking data is empty');
      }

      // Extract the student ID from the booking
      final String studentId = bookingData['studentId'] ?? '';

      if (studentId.isEmpty) {
        throw Exception('Student ID not found in booking');
      }

      // Extract library ID from booking if available or use widget.library.id
      final String libraryId = bookingData['libraryId'];

      // Start a batch write to ensure consistency across multiple updates
      final WriteBatch batch = _firestore.batch();

      // Update the booking in Firestore
      batch.update(_firestore.collection('seatBookings').doc(bookingId), {
        'paymentStatus': 'paid',
        'status': 'confirmed',
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
      });

      // Update subscriber status in the library's subscribers collection
      final subscribersRef = _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('subscribers')
          .doc(studentId);


        // Update existing subscriber
        batch.update(subscribersRef, {
          'paymentStatus': 'paid',
          'subscriptionStatus': 'active',
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });


      // Commit all the updates atomically
      await batch.commit();

      // Update current status in the Realtime Database with the correct student ID
      await FirebaseDatabase.instance
          .ref()
          .child("${SmartLib.constPath}/students/$studentId/currentStatus")
          .update({
        "paymentStatus": 'paid',
        "subscriptionStatus": 'active',
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment confirmed for Student ID: $studentId'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Optional: Navigate to student details page
              // Navigator.push(context, MaterialPageRoute(builder: (context) => StudentDetailsPage(studentId: studentId)));
            },
          ),
        ),
      );

      // Refresh data
      _fetchBookingHistory();
      _fetchPendingPayments();
    } catch (e) {
      print('Error confirming payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming payment: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _confirmPayment(bookingId),
          ),
        ),
      );
    }
  }
  // Helper to change libraries - FROM UPDATED CODE
  void _changeLibrary(int index) {
    if (index >= 0 && index < _libraryModels.length) {
      setState(() {
        _currentLibraryModel = _libraryModels[index];
        _currentLibrary = _libraries[index]; // Legacy support

        // Reset shift selection and update shifts list
        if (_currentLibraryModel != null &&
            _currentLibraryModel!.shifts != null) {
          if (_currentLibraryModel!.shifts is Map<String, dynamic>) {
            _shifts =
                (_currentLibraryModel!.shifts as Map<String, dynamic>).keys
                    .toList();
          }
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

  // Get shift name from shift ID - FROM UPDATED CODE
  String getShiftName(String shiftId) {
    if (_currentLibraryModel != null && _currentLibraryModel!.shifts != null) {
      // Try to get shift name from library model
      final shifts = _currentLibraryModel!.shifts;
      if (shifts is Map &&
          shifts.containsKey(shiftId) &&
          shifts[shiftId] is Map) {
        final shiftData = shifts[shiftId] as Map;
        if (shiftData.containsKey('shiftName')) {
          return shiftData['shiftName'].toString();
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

  // Format date to string (YYYY-MM-DD)
  String _formatDateToString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
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
                          'Seat ${booking['seatNo'] ?? 'N/A'} - ${booking['shiftName']}',
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
          LibrarianDashboardPage(
            currentLibrary: _currentLibrary,
            currentLibraryModel: _currentLibraryModel,
            todayBookings: _todayBookings,
            pendingPayments: _pendingPayments,
            occupancyByShift: _occupancyByShift,
            shifts: _shifts,
            selectedDate: _selectedDate,
            onDateChange: _changeDate,
            getShiftName: getShiftName,
          ),
          LibrarianBookingsPage(
            bookingHistory: _bookingHistory,
            selectedDateRange: _selectedDateRange,
            selectedStatus: _selectedStatus,
            dateRanges: _dateRanges,
            statuses: _statuses,
            isLoadingBookings: _isLoadingBookings,
            getShiftName: getShiftName,
            onChangeDateRangeFilter: _changeDateRangeFilter,
            onChangeStatusFilter: _changeStatusFilter,
            onShowBookingDetailsDialog: _showBookingDetailsDialog,
            onConfirmPayment: _confirmPayment,
            onShowSearchBookingsDialog: _showSearchBookingsDialog,
            onFetchBookingHistory: _fetchBookingHistory,
          ),
          LibrarianSeatsPage(
            currentLibrary: _currentLibrary,
            currentLibraryModel: _currentLibraryModel,
            seats: _seats,
            todayBookings: _todayBookings,
            shifts: _shifts,
            selectedDate: _selectedDate,
            selectedShift: _selectedShift,
            isLoadingSeats: _isLoadingSeats,
            onDateChange: _changeDate,
            onShiftChange: _changeShift,
            getShiftName: getShiftName,
          ),
          LibrarianProfilePage(
            librarianData: _librarianData,
            libraryModels: _libraryModels,
            currentLibraryModel: _currentLibraryModel,
            onChangeLibrary: _changeLibrary,
            formatTimeAgo: _formatTimeAgo,
          ),
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
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: const Color(0xff1940CC)),
                const SizedBox(height: 16),
                const Text('Loading library data...'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}