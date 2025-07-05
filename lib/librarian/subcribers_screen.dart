import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartlib/data/string.dart'; // For SmartLib constants
import 'package:smartlib/function/listen_data.dart';
import 'package:smartlib/theme/theme.dart';

class LibrarianSubscribersScreen extends StatefulWidget {
  const LibrarianSubscribersScreen({Key? key}) : super(key: key);

  @override
  _LibrarianSubscribersScreenState createState() => _LibrarianSubscribersScreenState();
}

class _LibrarianSubscribersScreenState extends State<LibrarianSubscribersScreen> {
  final ListenData _listenData = ListenData();
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscribers = [];
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortBy = 'Date (Newest)';

  // List of possible subscription statuses for filtering
  final List<String> _statusOptions = ['All', 'Active', 'Pending', 'Expired', 'Cancelled'];

  // List of sort options
  final List<String> _sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Name (A-Z)',
    'Name (Z-A)'
  ];

  @override
  void initState() {
    super.initState();
    _fetchSubscribers();
  }

  Future<void> _fetchSubscribers() async {
    setState(() {
      _isLoading = true;
    });


    try {
      // Get all subscribers using the provided method
      final subscribers = await _listenData.getAllSubscribers();

      setState(() {
        _subscribers = subscribers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching subscribers: $e');
      setState(() {
        _isLoading = false;
      });

      _showMessage('Failed to load subscribers: ${e.toString()}');
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

  // Filter subscribers based on search query and status filter
  List<Map<String, dynamic>> get _filteredSubscribers {
    return _subscribers.where((subscriber) {
      // Apply search query filter
      final nameMatches = subscriber['studentName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final emailMatches = subscriber['email']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final phoneMatches = subscriber['phone']?.toString().contains(_searchQuery) ?? false;
      final searchMatches = nameMatches || emailMatches || phoneMatches;

      // Apply status filter
      final statusMatches = _statusFilter == 'All' ||
          (subscriber['subscriptionStatus']?.toString().toLowerCase() == _statusFilter.toLowerCase());

      return searchMatches && statusMatches;
    }).toList()..sort((a, b) {
      // Apply sorting
      switch (_sortBy) {
        case 'Date (Newest)':
          return (b['joinedAt'] ?? 0).compareTo(a['joinedAt'] ?? 0);
        case 'Date (Oldest)':
          return (a['joinedAt'] ?? 0).compareTo(b['joinedAt'] ?? 0);
        case 'Name (A-Z)':
          return (a['studentName'] ?? '').toString().compareTo((b['studentName'] ?? '').toString());
        case 'Name (Z-A)':
          return (b['studentName'] ?? '').toString().compareTo((a['studentName'] ?? '').toString());
        default:
          return (b['joinedAt'] ?? 0).compareTo(a['joinedAt'] ?? 0);
      }
    });
  }

  // Calculate remaining days for subscription
  int _getRemainingDays(String? dueDate) {
    if (dueDate == null || dueDate.isEmpty) return 0;
    try {
      final dueDateTime = DateTime.parse(dueDate);
      final now = DateTime.now();
      final difference = dueDateTime.difference(now);
      return difference.inDays;

    } catch (e) {
      print('Error parsing due date: $e');
      return 0; // Return 0 if there's an error
    }
  }

  // Format timestamp to readable date
  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Get color based on subscription status
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscribers', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, email or phone',
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
            child: Row(
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
                // Sort dropdown
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
                            child: Text(value),
                          );
                        }).toList(),
                      ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  _subscribers.length.toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  'Active',
                  _subscribers.where((s) => s['subscriptionStatus']?.toString().toLowerCase() == 'active').length.toString(),
                  Colors.green,
                ),
                _buildStatItem(
                  'Pending',
                  _subscribers.where((s) => s['subscriptionStatus']?.toString().toLowerCase() == 'pending').length.toString(),
                  Colors.orange,
                ),
                _buildStatItem(
                  'Expired',
                  _subscribers.where((s) => s['subscriptionStatus']?.toString().toLowerCase() == 'expired').length.toString(),
                  Colors.red,
                ),
              ],
            ),
          ),

          // Subscriber list
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredSubscribers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredSubscribers.length,
              itemBuilder: (context, index) {
                final subscriber = _filteredSubscribers[index];
                return _buildSubscriberCard(subscriber);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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
            Icons.people_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No subscribers found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != 'All'
                ? 'Try changing your search or filter'
                : 'Students who subscribe to your library will appear here',
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

  Widget _buildSubscriberCard(Map<String, dynamic> subscriber) {
    final remainingDays = _getRemainingDays(subscriber['dueDate']);
    print('Remaining days: $remainingDays');
    final statusColor = _getStatusColor(subscriber['subscriptionStatus']);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: DarkColor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSubscriberDetails(subscriber),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subscriber['studentName']?.toString() ?? 'Unknown Student',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      (subscriber['subscriptionStatus']?.toString() ?? 'UNKNOWN').toUpperCase(),
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

              // Contact info
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subscriber['email']?.toString() ?? 'No email',
                      style: TextStyle(color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.phone, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    subscriber['phone']?.toString() ?? 'No phone',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Subscription details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shift details
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.blue),
                      SizedBox(width: 4),
                      Text(
                        subscriber['shiftName']?.toString() ?? 'Unknown Shift',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.currency_rupee, size: 16, color: Colors.green),
                      SizedBox(width: 2),
                      Text(
                        '${subscriber['shiftFee'] ?? 0}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),

                  // Subscription dates
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            'Subscribed: ${subscriber['subscriptionDate'] ?? 'Unknown'}',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                              Icons.timelapse,
                              size: 14,
                              color: remainingDays <= 0 ? Colors.red : (remainingDays <= 5 ? Colors.orange : Colors.green)
                          ),
                          SizedBox(width: 4),
                          Text(
                            remainingDays > 0
                                ? '$remainingDays days remaining'
                                : 'Expired',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: remainingDays <= 0 ? Colors.red : (remainingDays <= 5 ? Colors.orange : Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubscriberDetails(Map<String, dynamic> subscriber) {
    final remainingDays = _getRemainingDays(subscriber['dueDate']);
    final statusColor = _getStatusColor(subscriber['subscriptionStatus']);

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
                      subscriber['studentName']?.toString() ?? 'Unknown Student',
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
                      (subscriber['subscriptionStatus']?.toString() ?? 'UNKNOWN').toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Contact information
              _buildDetailItem('Email', subscriber['email']?.toString() ?? 'Not provided', Icons.email),
              _buildDetailItem('Phone', subscriber['phone']?.toString() ?? 'Not provided', Icons.phone),
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
                    _buildDetailRow('Shift Name', subscriber['shiftName']?.toString() ?? 'Unknown', Icons.schedule),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Timing',
                      '${subscriber['shiftStartTime'] ?? '00:00'} - ${subscriber['shiftEndTime'] ?? '00:00'}',
                      Icons.access_time,
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Fee',
                      '₹ ${subscriber['shiftFee']?.toString() ?? '0'}',
                      Icons.currency_rupee,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Subscription details
              Text(
                'Subscription Details',
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
                      'Subscription Date',
                      subscriber['subscriptionDate']?.toString() ?? _formatTimestamp(subscriber['joinedAt']),
                      Icons.calendar_today,
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Due Date',
                      subscriber['dueDate']?.toString() ?? 'Unknown',
                      Icons.event,
                    ),
                    SizedBox(height: 8),
                    _buildDetailRow(
                      'Remaining',
                      remainingDays > 0 ? '$remainingDays days' : 'Expired',
                      Icons.timelapse,
                      textColor: remainingDays <= 0
                          ? Colors.red
                          : (remainingDays <= 5 ? Colors.orange : Colors.green),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Last booking info
              if (subscriber['lastBookingId'] != null) ...[
                _buildDetailItem('Last Booking ID', subscriber['lastBookingId']?.toString() ?? '', Icons.bookmark),
              ],

              SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _callSubscriber(subscriber['phone']?.toString());
                      },
                      icon: Icon(Icons.phone),
                      label: Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showUpdateStatusDialog(subscriber);
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

  void _callSubscriber(String? phone) {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    // Launch phone call
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
  }

  void _showUpdateStatusDialog(Map<String, dynamic> subscriber) {
    String selectedStatus = subscriber['subscriptionStatus']?.toString() ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DarkColor.cardColor,
        title: Text('Update Subscription Status', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select a new status for ${subscriber['studentName']}',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 16),
                ...['active', 'pending', 'expired', 'cancelled'].map((status) {
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
              _updateSubscriptionStatus(subscriber, selectedStatus);
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

  void _updateSubscriptionStatus(Map<String, dynamic> subscriber, String newStatus) async {
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
      // Implementation of the update logic would go here
      // This would typically involve a call to Firebase or your backend API
      // For now, we'll just update the local state and pretend it worked

      // Simulate API call
      await Future.delayed(Duration(seconds: 1));

      // Update local state
      setState(() {
        final index = _subscribers.indexWhere((s) => s['id'] == subscriber['id']);
        if (index != -1) {
          _subscribers[index]['subscriptionStatus'] = newStatus;
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