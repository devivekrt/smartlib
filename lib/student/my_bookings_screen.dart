// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-23 10:59:27
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/student/library_market_place.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String _errorMessage = "";
  bool _isCancelling = false;

  // Tab controller for categorized bookings
  late TabController _tabController;

  // Bookings by status
  List<Map<String, dynamic>> _activeBookings = [];
  List<Map<String, dynamic>> _completedBookings = [];
  List<Map<String, dynamic>> _cancelledBookings = [];

  // Library data cache
  Map<String, Map<String, dynamic>> _libraryCache = {};

  // Filter options
  String _selectedFilter = "all";
  final List<String> _filterOptions = ["all", "today", "week", "month"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchBookings();

    // Listen for tab changes
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch all bookings from Firestore
  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      // Get the student ID
      final String studentId = SmartLib.userId ?? '';

      if (studentId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = "User ID not found. Please log in again.";
        });
        return;
      }

      // Get references to user's bookings from RTDB
      final bookingsSnapshot = await _database
          .ref()
          .child("${SmartLib.constPath}/students/$studentId/seatBookings")
          .get();

      if (!bookingsSnapshot.exists || bookingsSnapshot.value == null) {
        setState(() {
          _isLoading = false;
          _bookings = [];
          _categorizeBookings();
        });
        return;
      }

      // Convert RTDB snapshot to a list of booking IDs
      final bookingsData = bookingsSnapshot.value as Map<dynamic, dynamic>;
      final bookingIds = bookingsData.keys.map((key) => key.toString()).toList();

      // Fetch detailed booking information from Firestore
      final List<Map<String, dynamic>> bookingsList = [];

      for (final bookingId in bookingIds) {
        try {
          final bookingDoc = await _firestore
              .collection('seatBookings')
              .doc(bookingId)
              .get();

          if (bookingDoc.exists && bookingDoc.data() != null) {
            final bookingData = bookingDoc.data()!;

            // Add booking ID to the data
            final Map<String, dynamic> bookingWithId = {
              'id': bookingId,
              ...bookingData,
            };

            // Get library details if not already cached
            final String libraryId = bookingData['libraryId'] ?? '';
            if (libraryId.isNotEmpty && !_libraryCache.containsKey(libraryId)) {
              try {
                final libraryDoc = await _firestore
                    .collection('libraries')
                    .doc(libraryId)
                    .get();

                if (libraryDoc.exists && libraryDoc.data() != null) {
                  _libraryCache[libraryId] = libraryDoc.data()!;
                }
              } catch (e) {
                print('Error fetching library details: $e');
              }
            }

            // Add library name to booking data
            if (_libraryCache.containsKey(libraryId)) {
              bookingWithId['libraryName'] = _libraryCache[libraryId]!['libraryName'] ?? 'Unknown Library';
              bookingWithId['libraryAddress'] = _libraryCache[libraryId]!['address'] ?? {};
              bookingWithId['libraryImage'] = _libraryCache[libraryId]!['libraryImageUrl'] ?? '';
            } else {
              bookingWithId['libraryName'] = 'Unknown Library';
            }

            bookingsList.add(bookingWithId);
          }
        } catch (e) {
          print('Error fetching booking $bookingId: $e');
        }
      }

      // Sort bookings by creation date (newest first)
      bookingsList.sort((a, b) {
        final aTimestamp = a['createdAt'] as Timestamp?;
        final bTimestamp = b['createdAt'] as Timestamp?;

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;

        return bTimestamp.compareTo(aTimestamp);
      });

      // Apply filter
      final filtered = _applyFilter(bookingsList, _selectedFilter);

      setState(() {
        _bookings = filtered;
        _isLoading = false;
        _categorizeBookings();
      });
    } catch (e) {
      print('Error fetching bookings: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load bookings. Please try again.";
      });
    }
  }

  // Categorize bookings by their status
  void _categorizeBookings() {
    _activeBookings = _bookings.where((booking) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      return status == 'active' || status == 'confirmed' || status == 'pending';
    }).toList();

    _completedBookings = _bookings.where((booking) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      return status == 'completed';
    }).toList();

    _cancelledBookings = _bookings.where((booking) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      return status == 'cancelled' || status == 'canceled';
    }).toList();
  }

  // Filter bookings based on selected time period
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> bookings, String filter) {
    if (filter == "all") return bookings;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return bookings.where((booking) {
      final timestamp = booking['createdAt'] as Timestamp?;
      if (timestamp == null) return false;

      final bookingDate = timestamp.toDate();

      switch (filter) {
        case "today":
          final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
          return bookingDay.isAtSameMomentAs(today);

        case "week":
          final weekAgo = now.subtract(Duration(days: 7));
          return bookingDate.isAfter(weekAgo);

        case "month":
          final monthAgo = DateTime(now.year, now.month - 1, now.day);
          return bookingDate.isAfter(monthAgo);

        default:
          return true;
      }
    }).toList();
  }

  // Format relative time without using timeago package
  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  // Handle booking cancellation
  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    // Check if already in progress
    if (_isCancelling) return;

    // Get required IDs
    final bookingId = booking['id'];
    final libraryId = booking['libraryId'];
    final seatNo = booking['seatNo'];

    // First show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel this booking?'),
            SizedBox(height: 12),

            // Booking details
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_seat, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Seat ${booking['seatNo']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          booking['shiftName'] ?? 'N/A',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        '${booking['shiftStartTime'] ?? 'N/A'} - ${booking['shiftEndTime'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Cancellation policy
            Container(
              padding: EdgeInsets.all(12),
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
                      Icon(Icons.info_outline, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Cancellation Policy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Once cancelled, this booking cannot be restored. Any payments may be subject to the library\'s refund policy.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Proceed with cancellation
    setState(() => _isCancelling = true);

    try {
      // Create a batch for consistent updates
      final batch = _firestore.batch();

      // 1. Update booking document
      final bookingRef = _firestore.collection('seatBookings').doc(bookingId);
      batch.update(bookingRef, {
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // 2. Check if this was a single shift or multiple shifts
      if (booking['shiftId'] != null) {
        // Single shift booking
        final shiftId = booking['shiftId'];

        // Update seat status in library
        final libraryRef = _firestore.collection('libraries').doc(libraryId);
        batch.update(libraryRef, {
          'seats.$seatNo.shifts.$shiftId.status': 'available',
          'seats.$seatNo.shifts.$shiftId.bookedAt': FieldValue.delete(),
          'availableSeats': FieldValue.increment(1),
        });
      } else if (booking['shiftIds'] != null && booking['shiftIds'] is List) {
        // Multiple shifts booking
        final List<dynamic> shiftIds = booking['shiftIds'];

        // Update each shift
        final libraryRef = _firestore.collection('libraries').doc(libraryId);
        for (final shiftId in shiftIds) {
          batch.update(libraryRef, {
            'seats.$seatNo.shifts.$shiftId.status': 'available',
            'seats.$seatNo.shifts.$shiftId.bookedAt': FieldValue.delete(),
          });
        }

      }

      // 3. Execute the batch
      await batch.commit();
      // 4. Update user's current status if this was the active booking
      final studentId = SmartLib.userId ?? '';
      if (studentId.isNotEmpty) {
        final statusRef = _database
            .ref()
            .child("${SmartLib.constPath}/students/$studentId/currentStatus");

        final statusSnapshot = await statusRef.get();
        if (statusSnapshot.exists) {
          final statusData = statusSnapshot.value as Map<dynamic, dynamic>?;

          if (statusData != null && statusData['bookingId'] == bookingId) {
            // This was the current active booking, clear the status
            await statusRef.update({
              'currentBookingId': null,
              'currentStatus': 'none',
              'subscriptionStatus': "cancelled",
            });
          }
        }
      }

      // 5. Refresh the bookings list
      _fetchBookings();

      // 6. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error cancelling booking: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel booking. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCancelling = false);
    }
  }
  //convert 24hours time format into 12 hours format with am and pm
  String _formatTime(String time) {
    try {
      final dateTime = DateFormat('HH:mm').parse(time);
      return _formatTimeOfDay(dateTime);
    } catch (e) {
      return time; // Return original if parsing fails
    }
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Booking History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Filter dropdown
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'Filter by time',
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
              _fetchBookings();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Text('All Time'),
              ),
              PopupMenuItem(
                value: 'today',
                child: Text('Today'),
              ),
              PopupMenuItem(
                value: 'week',
                child: Text('This Week'),
              ),
              PopupMenuItem(
                value: 'month',
                child: Text('This Month'),
              ),
            ],
          ),

          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchBookings,
            tooltip: 'Refresh bookings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(
              text: 'Active',
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.event_available),
                  if (_activeBookings.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_activeBookings.length}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              text: 'Completed',
              icon: Icon(Icons.check_circle_outline),
            ),
            Tab(
              text: 'Cancelled',
              icon: Icon(Icons.cancel_outlined),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your bookings...'),
          ],
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchBookings,
              child: Text('Try Again'),
            ),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          // Active bookings tab
          _buildBookingsList(_activeBookings, showCancel: true),

          // Completed bookings tab
          _buildBookingsList(_completedBookings),

          // Cancelled bookings tab
          _buildBookingsList(_cancelledBookings),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings, {bool showCancel = false}) {
    if (bookings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildBookingCard(booking, showCancel: showCancel);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {bool showCancel = false}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    // Extract basic booking info
    final String bookingId = booking['id'] ?? '';
    final String seatNo = booking['seatNo'] ?? '';
    final String libraryName = booking['libraryName'] ?? 'Unknown Library';
    final String libraryImage = booking['libraryImage'] ?? '';
    final String shiftName = booking['shiftName'] ?? 'N/A';
    final String startTime = booking['shiftStartTime'] ?? '';
    final String endTime = booking['shiftEndTime'] ?? '';
    final String status = booking['status']?.toString().toLowerCase() ?? '';

    // Format dates
    String timeDisplay = '';
    if (booking['createdAt'] != null) {
      final timestamp = booking['createdAt'] as Timestamp;
      final dateTime = timestamp.toDate();

      // Use custom relative time formatter instead of timeago
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays < 2) {
        timeDisplay = _getRelativeTime(dateTime);
      } else {
        timeDisplay = DateFormat('MMM d, yyyy').format(dateTime);
      }
    }

    // Determine status color
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'active':
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Active';
        break;
      case 'pending':
        statusColor = Colors.amber;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.task_alt;
        statusText = 'Completed';
        break;
      case 'cancelled':
      case 'canceled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = status.isEmpty ? 'Unknown' : capitalize(status);
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header with status indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: statusColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  timeDisplay,
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Main content
          InkWell(
            onTap: () {
              // Navigate to booking details
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingDetailScreen(bookingId: bookingId),
                ),
              ).then((_) {
                // Refresh list when returning from details
                _fetchBookings();
              });
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Library info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Library image
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.withOpacity(0.2),
                          image: libraryImage.isNotEmpty
                              ? DecorationImage(
                            image: NetworkImage(libraryImage),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: libraryImage.isEmpty
                            ? Icon(Icons.account_balance, color: Colors.grey)
                            : null,
                      ),
                      SizedBox(width: 16),

                      // Library name and seat
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              libraryName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.event_seat, size: 16, color: Colors.blue),
                                SizedBox(width: 4),
                                Text(
                                  'Seat $seatNo',
                                  style: TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 16),

                                // Booking ID display
                                Expanded(
                                  child: Text(
                                    '# ${bookingId.substring(0, min(8, bookingId.length))}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),

                            // Timing details
                            Text(
                              'Time: ${_formatTime(startTime)} - ${_formatTime(endTime)}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Divider
                  Divider(height: 1),

                  // Bottom row with pricing and actions
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shift name and price
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.blue.withOpacity(0.1),
                            ),
                            child: Text(
                              shiftName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),

                          // Fee display
                          if (booking['shiftFee'] != null)
                            Text(
                              '₹${booking['shiftFee']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),

                      // View or cancel button
                      if (showCancel && (status == 'active' || status == 'confirmed' || status == 'pending'))
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: Icon(Icons.cancel, size: 16),
                          label: Text('Cancel'),
                          onPressed: _isCancelling
                              ? null
                              : () => _cancelBooking(booking),
                        )
                      else
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text('View Details'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingDetailScreen(bookingId: bookingId),
                              ),
                            ).then((_) {
                              _fetchBookings();
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = '';
    String subMessage = '';
    IconData iconData;

    switch (_tabController.index) {
      case 0: // Active
        message = "No active bookings";
        subMessage = "Book a seat to get started";
        iconData = Icons.event_available;
        break;
      case 1: // Completed
        message = "No completed bookings";
        subMessage = "Your completed bookings will appear here";
        iconData = Icons.check_circle_outline;
        break;
      case 2: // Cancelled
        message = "No cancelled bookings";
        subMessage = "This is a good thing!";
        iconData = Icons.cancel_outlined;
        break;
      default:
        message = "No bookings found";
        subMessage = "Start booking to see your history";
        iconData = Icons.book_online;
    }

    return Center(
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
                child: Icon(
                  iconData,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 24),
              Text(
                message,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                subMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // Action button
              if (_tabController.index == 0)
                ElevatedButton.icon(
                  onPressed: () {
                    //show only snackbar for now
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Go to the marketplace to find libraries'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.search),
                  label: Text('Find a Library'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to capitalize strings
  String capitalize(String s) {
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }
}

// Helper function to get minimum of two integers
int min(int a, int b) {
  return a < b ? a : b;
}

// Booking Detail Screen
class BookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailScreen({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  _BookingDetailScreenState createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _libraryData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

  Future<void> _loadBookingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get booking data
      final bookingDoc = await _firestore
          .collection('seatBookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists || bookingDoc.data() == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Booking not found';
        });
        return;
      }

      final bookingData = bookingDoc.data()!;

      // Get library data
      final String libraryId = bookingData['libraryId'] ?? '';
      Map<String, dynamic>? libraryData;

      if (libraryId.isNotEmpty) {
        final libraryDoc = await _firestore
            .collection('libraries')
            .doc(libraryId)
            .get();

        if (libraryDoc.exists && libraryDoc.data() != null) {
          libraryData = libraryDoc.data();
        }
      }

      setState(() {
        _bookingData = {
          'id': widget.bookingId,
          ...bookingData,
        };
        _libraryData = libraryData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booking data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load booking details';
      });
    }
  }
  //convert 24hours time format into 12 hours format with am and pm
  String _formatTime(String time) {
    try {
      final dateTime = DateFormat('HH:mm').parse(time);
      return _formatTimeOfDay(dateTime);
    } catch (e) {
      return time; // Return original if parsing fails
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBookingData,
              child: Text('Try Again'),
            ),
          ],
        ),
      )
          : _buildBookingDetails(),
    );
  }

  Widget _buildBookingDetails() {
    if (_bookingData == null) {
      return Center(child: Text('No booking data available'));
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardColor = Theme.of(context).cardColor;

    // Extract booking data
    final String bookingId = widget.bookingId;
    final String status = _bookingData!['status']?.toString().toLowerCase() ?? '';
    final String seatNo = _bookingData!['seatNo'] ?? '';
    final String shiftName = _bookingData!['shiftName'] ?? '';
    final String startTime =_formatTime( _bookingData!['shiftStartTime'] )?? '';
    final String endTime = _formatTime(_bookingData!['shiftEndTime']) ?? '';
    final int? fee = _bookingData!['shiftFee'] is int
        ? _bookingData!['shiftFee']
        : int.tryParse(_bookingData!['shiftFee']?.toString() ?? '0');

    // Extract library data
    final String libraryName = _libraryData?['libraryName'] ?? 'Unknown Library';
    final String libraryImage = _libraryData?['libraryImageUrl'] ?? '';
    final Map<String, dynamic>? address = _libraryData?['address'] as Map<String, dynamic>?;
    final String addressText = address != null
        ? '${address['street'] ?? ''}, ${address['city'] ?? ''}'
        : 'Address not available';

    // Determine status color and info
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'active':
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Active';
        break;
      case 'pending':
        statusColor = Colors.amber;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.task_alt;
        statusText = 'Completed';
        break;
      case 'cancelled':
      case 'canceled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = status.isEmpty ? 'Unknown' : capitalize(status);
    }

    // Format dates
    String bookedDate = 'N/A';
    if (_bookingData!['createdAt'] != null) {
      final timestamp = _bookingData!['createdAt'] as Timestamp;
      bookedDate = DateFormat('MMMM d, yyyy - h:mm a').format(timestamp.toDate());
    }

    String updatedDate = 'N/A';
    if (_bookingData!['updatedAt'] != null) {
      final timestamp = _bookingData!['updatedAt'] as Timestamp;
      updatedDate = DateFormat('MMMM d, yyyy - h:mm a').format(timestamp.toDate());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withOpacity(0.7),
                    statusColor.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: $statusText',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Booking ID: #$bookingId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Library & Seat Details
          Text(
            'Library & Seat Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Library info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Library image
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.withOpacity(0.2),
                          image: libraryImage.isNotEmpty
                              ? DecorationImage(
                            image: NetworkImage(libraryImage),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: libraryImage.isEmpty
                            ? Icon(Icons.account_balance, color: Colors.grey)
                            : null,
                      ),
                      SizedBox(width: 16),

                      // Library details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              libraryName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    addressText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                    maxLines: 2,
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

                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),

                  // Seat & timing info
                  Row(
                    children: [
                      // Seat information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event_seat, size: 16, color: Colors.blue),
                                SizedBox(width: 4),
                                Text(
                                  'Seat',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              seatNo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Shift information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  'Shift',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              shiftName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Timing information
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.purple),
                      SizedBox(width: 4),
                      Text(
                        'Timing',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$startTime - $endTime',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Payment Details
          Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Total Fee
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Booking Fee',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '₹${fee ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),

                  // Payment status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Status',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getPaymentStatusColor(_bookingData!['paymentStatus']?.toString() ?? '').withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          capitalize(_bookingData!['paymentStatus']?.toString() ?? 'Not Paid'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getPaymentStatusColor(_bookingData!['paymentStatus']?.toString() ?? ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Payment method
                  if (_bookingData!['paymentMethod'] != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              _getPaymentMethodIcon(_bookingData!['paymentMethod']),
                              size: 18,
                              color: textColor.withOpacity(0.7),
                            ),
                            SizedBox(width: 6),
                            Text(
                              capitalize(_bookingData!['paymentMethod']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Booking History
          Text(
            'Booking History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Booked at
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text('Booked at'),
                        ],
                      ),
                      Text(bookedDate),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Last updated
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.update,
                            size: 16,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text('Last updated'),
                        ],
                      ),
                      Text(updatedDate),
                    ],
                  ),

                  // Show cancelled time if applicable
                  if (status == 'cancelled' || status == 'canceled') ...[
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cancel,
                              size: 16,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Cancelled at'),
                          ],
                        ),
                        Text(
                          _bookingData!['cancelledAt'] != null
                              ? DateFormat('MMMM d, yyyy - h:mm a')
                              .format((_bookingData!['cancelledAt'] as Timestamp).toDate())
                              : updatedDate,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 32),

          // Actions
          if (status == 'active' || status == 'confirmed' || status == 'pending')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Cancel Booking'),
                      content: Text('Are you sure you want to cancel this booking?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('No'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            // Implement cancel booking functionality
                            // This would typically call a function similar to _cancelBooking
                          },
                          child: Text('Yes, Cancel'),
                        ),
                      ],
                    ),
                  );
                },
                child: Text('Cancel Booking'),
              ),
            ),
        ],
      ),
    );
  }

  // Helper function to get color based on payment status
  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.amber;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper function to get icon for payment method
  IconData _getPaymentMethodIcon(String? method) {
    if (method == null) return Icons.payment;

    switch (method.toLowerCase()) {
      case 'card':
        return Icons.credit_card;
      case 'cash':
        return Icons.money;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'bank':
        return Icons.account_balance;
      case 'upi':
        return Icons.smartphone;
      default:
        return Icons.payment;
    }
  }

  // Helper function to capitalize strings
  String capitalize(String s) {
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }
}