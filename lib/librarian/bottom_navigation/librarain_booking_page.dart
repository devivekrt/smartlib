import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/function/listen_data.dart';
import 'package:smartlib/theme/theme.dart';

class LibrarianSeatBookingsScreen extends StatefulWidget {
  const LibrarianSeatBookingsScreen({Key? key}) : super(key: key);

  @override
  _LibrarianSeatBookingsScreenState createState() => _LibrarianSeatBookingsScreenState();
}

class _LibrarianSeatBookingsScreenState extends State<LibrarianSeatBookingsScreen> {
  final ListenData _listenData = ListenData();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _paymentFilter = 'All';
  String _sortBy = 'Date (Newest)';

  // List of possible booking statuses for filtering
  final List<String> _statusOptions = ['All', 'Active', 'Pending', 'Completed', 'Cancelled'];

  // List of possible payment statuses for filtering
  final List<String> _paymentOptions = ['All', 'Paid', 'Pending', 'Failed'];

  // List of sort options
  final List<String> _sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Name (A-Z)',
    'Name (Z-A)',
    'Seat Number'
  ];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all seat bookings using the provided method
      final bookings = await _listenData.getSeatBookingsForLibrary();
      print('Fetched ${bookings.length} seat bookings');

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching seat bookings: $e');
      setState(() {
        _isLoading = false;
      });

      _showMessage('Failed to load seat bookings: ${e.toString()}');
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // Filter bookings based on search query and status filter
  List<Map<String, dynamic>> get _filteredBookings {
    return _bookings.where((booking) {
      // Apply search query filter
      final nameMatches = booking['studentName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final seatMatches = booking['seatNo']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final shiftMatches = booking['shiftName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final searchMatches = nameMatches || seatMatches || shiftMatches;

      // Apply status filter
      final statusMatches = _statusFilter == 'All' ||
          (booking['status']?.toString().toLowerCase() == _statusFilter.toLowerCase());

      // Apply payment filter
      final paymentMatches = _paymentFilter == 'All' ||
          (booking['paymentStatus']?.toString().toLowerCase() == _paymentFilter.toLowerCase());

      return searchMatches && statusMatches && paymentMatches;
    }).toList()..sort((a, b) {
      // Apply sorting
      switch (_sortBy) {
        case 'Date (Newest)':
          return (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0);
        case 'Date (Oldest)':
          return (a['createdAt'] ?? 0).compareTo(b['createdAt'] ?? 0);
        case 'Name (A-Z)':
          return (a['studentName'] ?? '').toString().compareTo((b['studentName'] ?? '').toString());
        case 'Name (Z-A)':
          return (b['studentName'] ?? '').toString().compareTo((a['studentName'] ?? '').toString());
        case 'Seat Number':
          return (a['seatNo'] ?? '').toString().compareTo((b['seatNo'] ?? '').toString());
        default:
          return (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0);
      }
    });
  }

  // Calculate days since booking
  int _getDaysSinceBooking(String? bookedAt) {
    if (bookedAt == null || bookedAt.isEmpty) return 0;

    try {
      final parts = bookedAt.split('-');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final month = int.tryParse(parts[1]) ?? 1;
        final year = int.tryParse(parts[2]) ?? 2023;

        final bookingDate = DateTime(year, month, day);
        final today = DateTime.now();

        return today.difference(bookingDate).inDays;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Format timestamp to readable date
  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Get color based on booking status
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      case 'confirmed':
        return Colors.green.shade700;
      default:
        return Colors.purple;
    }
  }

  // Get color based on payment status
  Color _getPaymentStatusColor(String? paymentStatus) {
    switch (paymentStatus?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, seat number or shift',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: DarkColor.cardColor,
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              style: TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filter & Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // First row of filters: Status and Payment
                Row(
                  children: [
                    // Status filter dropdown
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: DarkColor.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[700]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                            isExpanded: true,
                            dropdownColor: DarkColor.cardColor,
                            style: TextStyle(color: Colors.white),
                            hint: Text('Status', style: TextStyle(color: Colors.grey)),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _statusFilter = newValue;
                                });
                              }
                            },
                            items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Payment filter dropdown
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: DarkColor.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[700]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _paymentFilter,
                            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                            isExpanded: true,
                            dropdownColor: DarkColor.cardColor,
                            style: TextStyle(color: Colors.white),
                            hint: Text('Payment', style: TextStyle(color: Colors.grey)),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _paymentFilter = newValue;
                                });
                              }
                            },
                            items: _paymentOptions.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // Second row: Sort options
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: DarkColor.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                      isExpanded: true,
                      dropdownColor: DarkColor.cardColor,
                      style: TextStyle(color: Colors.white),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _sortBy = newValue;
                          });
                        }
                      },
                      items: _sortOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(Icons.sort, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats Summary
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DarkColor.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Total',
                      _bookings.length.toString(),
                      Colors.blue,
                    ),

                    _buildStatItem(
                      'Pending',
                      _bookings.where((b) => b['paymentStatus']?.toString().toLowerCase() == 'pending').length.toString(),
                      Colors.orange,
                    ),
                    _buildStatItem(
                      'Paid',
                      _bookings.where((b) => b['paymentStatus']?.toString().toLowerCase() == 'paid').length.toString(),
                      Colors.green,
                    ),
                    _buildStatItem(
                      'Failed',
                      _bookings.where((b) => b['paymentStatus']?.toString().toLowerCase() == 'failed').length.toString(),
                      Colors.red,
                    ),
                  ],
                ),

              ],
            ),
          ),

          // Bookings list
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredBookings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredBookings.length,
              itemBuilder: (context, index) {
                final booking = _filteredBookings[index];
                return _buildBookingCard(booking);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, {bool showIndicator = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (showIndicator && int.tryParse(value) != null && int.parse(value) > 0)
              Container(
                margin: EdgeInsets.only(left: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return ShimmerLoading(
          child: Container(
            height: 120,
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: DarkColor.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_seat_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No bookings found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != 'All' || _paymentFilter != 'All'
                ? 'Try changing your search or filter'
                : 'Seat bookings will appear here when students make reservations',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final statusColor = _getStatusColor(booking['status']);
    final paymentStatusColor = _getPaymentStatusColor(booking['paymentStatus']);
    final daysSinceBooking = _getDaysSinceBooking(booking['bookedAt']?.toString());

    // Check if payment is pending
    final isPaymentPending = booking['paymentStatus']?.toString().toLowerCase() == 'pending';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: DarkColor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPaymentPending ? Colors.amber.shade800 : Colors.grey[800]!,
          width: isPaymentPending ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBookingDetails(booking),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Name, Status and Seat Number
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Student Name
                      Expanded(
                        child: Text(
                          booking['studentName']?.toString() ?? 'Unknown Student',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Booking Status
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          (booking['status']?.toString() ?? 'UNKNOWN').toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Seat and Payment info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Seat number
                      Row(
                        children: [
                          Icon(Icons.event_seat, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'Seat ${booking['seatNo']?.toString() ?? 'Unknown'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Payment status
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: paymentStatusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: paymentStatusColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              booking['paymentStatus']?.toString().toLowerCase() == 'paid'
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: paymentStatusColor,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              (booking['paymentStatus']?.toString() ?? 'UNKNOWN').toUpperCase(),
                              style: TextStyle(
                                color: paymentStatusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Shift details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shift details
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.amber),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${booking['shiftName']?.toString() ?? 'Unknown'} (${booking['shiftCount'] ?? 1} ${(booking['shiftCount'] ?? 1) > 1 ? 'shifts' : 'shift'})',
                                style: TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Fee
                      Row(
                        children: [
                          Icon(Icons.currency_rupee, size: 14, color: Colors.green),
                          SizedBox(width: 2),
                          Text(
                            '${booking['totalFee'] ?? booking['shiftFee'] ?? 0}',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Booking date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Booked: ${booking['bookedAt']?.toString() ?? _formatTimestamp(booking['createdAt'])}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Due: ${booking['dueDate']?.toString() ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Payment Action Buttons - Show only if payment is pending
            if (isPaymentPending)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmPayment(booking['id']),
                        icon: Icon(Icons.check_circle_outline, size: 18),
                        label: Text('Confirm Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectPayment(booking['id']),
                        icon: Icon(Icons.cancel_outlined, size: 18),
                        label: Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
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

  void _showBookingDetails(Map<String, dynamic> booking) {
    final statusColor = _getStatusColor(booking['status']);
    final paymentStatusColor = _getPaymentStatusColor(booking['paymentStatus']);
    final isPaymentPending = booking['paymentStatus']?.toString().toLowerCase() == 'pending';

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking['studentName']?.toString() ?? 'Unknown Student',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      (booking['status']?.toString() ?? 'UNKNOWN').toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Booking ID
              if (booking['id'] != null) ...[
                _buildDetailItem('Booking ID', booking['id'].toString(), Icons.confirmation_number),
              ],

              // Seat information
              _buildDetailItem(
                'Seat Number',
                booking['seatNo']?.toString() ?? 'Not assigned',
                Icons.event_seat,
              ),
              SizedBox(height: 16),

              // Shift details
              Text(
                'Shift Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DarkColor.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                        'Shift Name',
                        booking['shiftName']?.toString() ?? 'Unknown',
                        Icons.schedule
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Timing',
                      '${booking['shiftStartTime']?.toString() ?? '00:00'} - ${booking['shiftEndTime']?.toString() ?? '00:00'}',
                      Icons.access_time,
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Shift Count',
                      '${booking['shiftCount'] ?? 1} ${(booking['shiftCount'] ?? 1) > 1 ? 'shifts' : 'shift'}',
                      Icons.repeat,
                    ),
                    if (booking['shiftIds'] != null || booking['shiftId'] != null) ...[
                      SizedBox(height: 8),
                      _buildDetailRow(
                        'Shift ID(s)',
                        booking['shiftIds']?.toString() ?? booking['shiftId']?.toString() ?? 'N/A',
                        Icons.tag,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Payment details
              Text(
                'Payment Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DarkColor.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Amount',
                      '₹ ${booking['totalFee']?.toString() ?? booking['shiftFee']?.toString() ?? '0'}',
                      Icons.currency_rupee,
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Status',
                      booking['paymentStatus']?.toString()?.toUpperCase() ?? 'UNKNOWN',
                      Icons.payment,
                      textColor: paymentStatusColor,
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Method',
                      booking['paymentMethod']?.toString() ?? 'Not specified',
                      Icons.account_balance_wallet,
                    ),
                    if (booking['paymentId'] != null) ...[
                      SizedBox(height: 8),
                      _buildDetailRow(
                        'Payment ID',
                        booking['paymentId'].toString(),
                        Icons.receipt_long,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Date details
              Text(
                'Booking Dates',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DarkColor.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Booked On',
                      booking['bookedAt']?.toString() ?? _formatTimestamp(booking['createdAt']),
                      Icons.event,
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Due Date',
                      booking['dueDate']?.toString() ?? 'Not specified',
                      Icons.event_note,
                    ),
                    SizedBox(height: 8),

                  ],
                ),
              ),
              SizedBox(height: 20),

              // Action buttons
              if (isPaymentPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmPayment(booking['id']);
                        },
                        icon: Icon(Icons.check_circle_outline),
                        label: Text('Confirm Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectPayment(booking['id']);
                        },
                        icon: Icon(Icons.cancel_outlined),
                        label: Text('Reject Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showUpdateStatusDialog(booking);
                        },
                        icon: Icon(Icons.update),
                        label: Text('Update Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DarkColor.highlightColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DarkColor.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: DarkColor.highlightColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? textColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showUpdateStatusDialog(Map<String, dynamic> booking) {
    String selectedStatus = booking['status']?.toString() ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DarkColor.cardColor,
        title: Text('Update Booking Status', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select a new status for this booking',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 16),
                ...['active', 'pending', 'completed', 'cancelled'].map((status) {
                  return RadioListTile<String>(
                    title: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: _getStatusColor(status)),
                    ),
                    value: status,
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                    activeColor: _getStatusColor(status),
                  );
                }).toList(),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateBookingStatus(booking, selectedStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DarkColor.highlightColor,
            ),
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _updateBookingStatus(Map<String, dynamic> booking, String newStatus) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Updating status...'),
          ],
        ),
        duration: Duration(seconds: 60), // Long duration as we'll dismiss manually
      ),
    );

    try {
      // Update the booking status in Firestore
      await _firestore
          .collection('seatBookings')
          .doc(booking['id'])
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        final index = _bookings.indexWhere((b) => b['id'] == booking['id']);
        if (index != -1) {
          _bookings[index]['status'] = newStatus;
          _bookings[index]['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        }
      });

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMessage('Status updated successfully', isError: false);
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMessage('Failed to update status: ${e.toString()}');
    }
  }

  // New method to confirm payment
  Future<void> _confirmPayment(String bookingId) async {
    // Show confirmation dialog
    bool proceed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DarkColor.cardColor,
        title: Text('Confirm Payment', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to confirm this payment? This will mark the booking as paid and activate the subscription.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;

    if (!proceed) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Processing payment confirmation...'),
          ],
        ),
        duration: Duration(seconds: 60), // Long duration as we'll dismiss manually
      ),
    );

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

      // Extract library ID from booking
      final String libraryId = bookingData['libraryId'] ?? '';

      if (libraryId.isEmpty) {
        throw Exception('Library ID not found in booking');
      }

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

      // Check if subscriber document exists
      final subscriberDoc = await subscribersRef.get();

      if (subscriberDoc.exists) {
        // Update existing subscriber
        batch.update(subscribersRef, {
          'paymentStatus': 'paid',
          'subscriptionStatus': 'active',
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Handle case where subscriber document doesn't exist
        _showMessage('Warning: Subscriber document not found', isError: true);
      }

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

      // Update local state
      setState(() {
        final index = _bookings.indexWhere((b) => b['id'] == bookingId);
        if (index != -1) {
          _bookings[index]['paymentStatus'] = 'paid';
          _bookings[index]['status'] = 'confirmed';
          _bookings[index]['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        }
      });

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMessage('Payment confirmed successfully', isError: false);

      // Refresh data
      _fetchBookings();
    } catch (e) {
      print('Error confirming payment: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMessage('Error confirming payment: ${e.toString()}');
    }
  }

  // New method to reject payment
  Future<void> _rejectPayment(String bookingId) async {
    // Show rejection dialog with reason input
    String rejectionReason = '';

    bool proceed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DarkColor.cardColor,
        title: Text('Reject Payment', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to reject this payment?',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) {
                rejectionReason = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    ) ?? false;

    if (!proceed) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Processing payment rejection...'),
          ],
        ),
        duration: Duration(seconds: 60), // Long duration as we'll dismiss manually
      ),
    );

    try {
      // Get booking details
      final bookingDoc = await _firestore.collection('seatBookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data();
      if (bookingData == null) {
        throw Exception('Booking data is empty');
      }

      final String studentId = bookingData['studentId'] ?? '';
      if (studentId.isEmpty) {
        throw Exception('Student ID not found in booking');
      }

      // Update booking status
      await _firestore.collection('seatBookings').doc(bookingId).update({
        'paymentStatus': 'failed',
        'status': 'cancelled',
        'rejectionReason': rejectionReason.isNotEmpty ? rejectionReason : 'Payment rejected by librarian',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        final index = _bookings.indexWhere((b) => b['id'] == bookingId);
        if (index != -1) {
          _bookings[index]['paymentStatus'] = 'failed';
          _bookings[index]['status'] = 'cancelled';
          _bookings[index]['rejectionReason'] = rejectionReason.isNotEmpty ? rejectionReason : 'Payment rejected by librarian';
          _bookings[index]['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        }
      });

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMessage('Payment rejected successfully', isError: false);

      // Refresh data
      _fetchBookings();
    } catch (e) {
      print('Error rejecting payment: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMessage('Error rejecting payment: ${e.toString()}');
    }
  }
}

// Simple ShimmerLoading widget for loading state
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({Key? key, required this.child}) : super(key: key);

  @override
  _ShimmerLoadingState createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.grey.shade800,
                Colors.grey.shade500,
                Colors.grey.shade800,
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment(_animation.value, 0),
              end: Alignment(_animation.value + 1, 0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}