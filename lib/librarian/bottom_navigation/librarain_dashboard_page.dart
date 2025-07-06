import 'package:flutter/material.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/function/listen_data.dart';
import 'package:smartlib/librarian/bottom_navigation/librarain_booking_page.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'dart:math' show max, min;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:smartlib/library/library_edit_screen.dart';

import '../../theme/theme.dart';
import '../library_checkin_classroom.dart';
import '../library_qrcode_gen.dart';
import '../notification_send.dart';
import '../subcribers_screen.dart';

class LibrarianDashboardPage extends StatefulWidget {
  const LibrarianDashboardPage({Key? key}) : super(key: key);

  @override
  State<LibrarianDashboardPage> createState() => _LibrarianDashboardPageState();
}

class _LibrarianDashboardPageState extends State<LibrarianDashboardPage> {
  final ListenData _listenData = ListenData();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _recentAttendance = [];
  bool _hasMoreAttendance = false;
  static const int _maxAttendanceToShow = 5; // Maximum number of activities to show in the dashboard

  // Current date
  String _currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _formattedCurrentDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // No need to manually unsubscribe; ListenData handles this
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize ListenData service if needed
      await _listenData.getUserData();

      // Load today's attendance data
      await _loadAttendanceData(_currentDate);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print("❌ Error loading dashboard data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load attendance data for a specific date
  Future<void> _loadAttendanceData(String date) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use ListenData service to fetch attendance records
      final attendanceRecords = await _listenData.getAttendanceRecordsForLibrary(date);

      if (mounted) {
        setState(() {
          _hasMoreAttendance = attendanceRecords.length > _maxAttendanceToShow;
          _recentAttendance = attendanceRecords.take(_maxAttendanceToShow).toList();
          _isLoading = false;
        });
      }

      print("✅ Loaded ${attendanceRecords.length} attendance records for $date");

    } catch (e) {
      print("❌ Error loading attendance data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  //address formatting function
  String _formatAddress() {
    Map<String, dynamic> addressMap = SmartLib.addressMap;
    if (addressMap.isNotEmpty) {
      String street = addressMap['street'] ?? '';
      String city = addressMap['city'] ?? '';
      String state = addressMap['state'] ?? '';
      String pincode = addressMap['pincode'] ?? '';

      // Format the address
      List<String> addressParts = [street, city, state, pincode];
      return addressParts.where((part) => part.isNotEmpty).join(', ');
    }
    return 'Address not available';
  }

  String getShiftName(String shiftId) {
    // Simple mapping function, replace with actual mapping logic if needed
    return shiftId.split('_').map((word) => word.capitalize()).join(' ');
  }

  // Format timestamp to readable time
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Invalid date';
      }

      // Check if the date is today
      final now = DateTime.now();
      final bool isToday = dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day;

      if (isToday) {
        // For today, just show the time
        return DateFormat('h:mm a').format(dateTime);
      } else {
        // For other days show date and time
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main scrollable content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Library Overview Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: DarkColor.borderColor, width: 1),
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
                                  // Access libraryName directly from SmartLib
                                  SmartLib.libraryName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: DarkColor.primary,
                                ),
                                onPressed: () {
                                  // Navigate to library settings
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LibraryEditScreen(
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

                          // Address
                          Text(
                            _formatAddress(),
                            style: TextStyle(
                              fontSize: 14,
                              color: DarkColor.text.withOpacity(0.8),
                            ),
                          ),

                          const Gap(16),

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // Navigate to view all subscribers
                                    Navigator.push(context, PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => LibrarianSubscribersScreen(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        var begin = Offset(1.0, 0.0);
                                        var end = Offset.zero;
                                        var curve = Curves.ease;

                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        var offsetAnimation = animation.drive(tween);

                                        return SlideTransition(position: offsetAnimation, child: child);
                                      },
                                    ));
                                  },
                                  icon: const Icon(Icons.people),
                                  label: const Text("Subscribers"),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // Navigate to seat bookings
                                    Navigator.push(context, PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => LibrarianSeatBookingsScreen(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        var begin = Offset(1.0, 0.0);
                                        var end = Offset.zero;
                                        var curve = Curves.ease;

                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        var offsetAnimation = animation.drive(tween);

                                        return SlideTransition(position: offsetAnimation, child: child);
                                      },
                                    ));
                                  },
                                  icon: const Icon(Icons.calendar_today),
                                  label: const Text("Bookings"),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                      side: BorderSide(color: DarkColor.borderColor, width: 1),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quick Actions",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: DarkColor.text,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8, // horizontal spacing between items
                              runSpacing: 8, // vertical spacing between lines
                              children: [
                                _actionButton(
                                  context,
                                  "Run Ads",
                                  Icons.add_chart_sharp,
                                      () {
                                    // Navigate to Run Ads tab
                                  },
                                ),
                                _actionButton(
                                  context,
                                  "Classroom",
                                  Icons.event_seat,
                                      () {
                                    // Navigate to seat management tab
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LibraryCheckinManagementPage(
                                          libraryId: SmartLib.libraryId,
                                          libraryName: SmartLib.libraryName,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _actionButton(
                                  context,
                                  "QR Code",
                                  Icons.qr_code_2_rounded,
                                      () {
                                    // Navigate to QR code generator
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LibraryQRGeneratorScreen(
                                          libraryId: SmartLib.libraryId,
                                          libraryName: SmartLib.libraryName,
                                          libraryAddress: _formatAddress(),
                                          librarianId: SmartLib.userId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _actionButton(
                                  context,
                                  "Notifications",
                                  Icons.notification_add,
                                      () {
                                    // Navigate to notifications screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LibrarianNotificationScreen(
                                          librarianId: SmartLib.userId,
                                          libraryId: SmartLib.libraryId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Recent Activity - shows check-in or checkout student data
                  const Gap(20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: DarkColor.borderColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Today's Activity",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: DarkColor.text,
                                ),
                              ),
                              if (_hasMoreAttendance)
                                TextButton(
                                  onPressed: () {
                                    // Navigate to a full activity log screen
                                    _navigateToAllActivities();
                                  },
                                  child: Text(
                                    "View All",
                                    style: TextStyle(
                                      color: DarkColor.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Recent attendance list
                          _isLoading
                              ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                              : _buildRecentActivityList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build recent activity list
  Widget _buildRecentActivityList() {
    if (_recentAttendance.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: Colors.grey.withOpacity(0.6),
            ),
            SizedBox(height: 16),
            Text(
              "No activity today",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Check-ins and check-outs will appear here",
              style: TextStyle(
                color: Colors.grey.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _recentAttendance.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.withOpacity(0.2),
      ),
      itemBuilder: (context, index) {
        final activity = _recentAttendance[index];

        // Determine activity type and icon
        final isCheckIn = activity['type'] == 'check-in';
        final activityIcon = isCheckIn
            ? Icons.login
            : Icons.logout;
        final activityColor = isCheckIn
            ? Colors.green
            : Colors.orange;

        // Format student name and seat
        final studentName = activity['studentName'] ?? 'Unknown Student';
        final seatId = activity['seatId'] ?? activity['seatNo'] ?? 'Unknown';
        final timestamp = activity['timestamp'];

        return ListTile(
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activityColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activityIcon,
              color: activityColor,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  studentName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${isCheckIn ? "Checked in to" : "Checked out from"} seat $seatId',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: () {
            // Show full details of this activity
            _showActivityDetails(activity);
          },
        );
      },
    );
  }

  // Navigate to view all activities
  void _navigateToAllActivities() {
    // Navigate to the ActivityLogScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivityLogScreen(
          libraryId: SmartLib.libraryId,
          libraryName: SmartLib.libraryName,
        ),
      ),
    );
  }

  // Show activity details in a bottom sheet
  void _showActivityDetails(Map<String, dynamic> activity) {
    final isCheckIn = activity['type'] == 'check-in';
    final studentName = activity['studentName'] ?? 'Unknown Student';
    final studentId = activity['studentId'] ?? 'Unknown ID';
    final seatId = activity['seatId'] ?? activity['seatNo'] ?? 'Unknown';
    final timestamp = activity['timestamp'];
    final shiftName = activity['shiftName'] ?? 'Unknown Shift';

    showModalBottomSheet(
      context: context,
      backgroundColor: DarkColor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCheckIn ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCheckIn ? Icons.login : Icons.logout,
                      color: isCheckIn ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCheckIn ? "Check In" : "Check Out",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(color: Colors.grey.shade800),
              SizedBox(height: 16),
              _detailRow("Student", studentName, Icons.person),
              SizedBox(height: 8),
              _detailRow("Student ID", studentId, Icons.badge),
              SizedBox(height: 8),
              _detailRow("Seat", seatId, Icons.event_seat),
              SizedBox(height: 8),
              _detailRow("Shift", shiftName, Icons.access_time),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Detail row helper
  Widget _detailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 8),
        Text('$label:', style: TextStyle(color: Colors.grey)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Helper widget for action buttons
  Widget _actionButton(
      BuildContext context,
      String label,
      IconData icon,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 100),
        width: 110,
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DarkColor.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DarkColor.primary.withOpacity(0.3)),
              ),
              child: Icon(icon, color: DarkColor.primary, size: 24),
            ),
            const Gap(8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: DarkColor.text,
              ),
            ),
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
            color: DarkColor.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DarkColor.primary.withOpacity(0.3)),
          ),
          child: Icon(icon, color: DarkColor.primary, size: 24),
        ),
        const Gap(8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: DarkColor.text,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: DarkColor.text.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

// New screen for Activity Log with date filter
class ActivityLogScreen extends StatefulWidget {
  final String libraryId;
  final String libraryName;

  const ActivityLogScreen({
    Key? key,
    required this.libraryId,
    required this.libraryName,
  }) : super(key: key);

  @override
  _ActivityLogScreenState createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final ListenData _listenData = ListenData();

  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];

  // Selected date (default to today)
  DateTime _selectedDate = DateTime.now();
  String _formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _displayDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

  // Filters
  String _activityFilter = "all"; // all, check-in, check-out

  @override
  void initState() {
    super.initState();
    _loadRecordsForDate(_formattedDate);
  }

  // Load records for a specific date
  Future<void> _loadRecordsForDate(String date) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use ListenData to get attendance records
      final records = await _listenData.getAttendanceRecordsForLibrary(date);

      // Apply filters if needed
      List<Map<String, dynamic>> filteredRecords = records;
      if (_activityFilter != "all") {
        filteredRecords = records.where((record) =>
        record['type'] == _activityFilter
        ).toList();
      }

      setState(() {
        _attendanceRecords = filteredRecords;
        _isLoading = false;
      });

    } catch (e) {
      print("❌ Error loading attendance records: $e");
      setState(() {
        _attendanceRecords = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load attendance records"))
      );
    }
  }

  // Show date picker
  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: DarkColor.primary,
              onPrimary: Colors.white,
              surface: DarkColor.cardColor,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: DarkColor.cardColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
        _displayDate = DateFormat('EEEE, MMMM d, yyyy').format(pickedDate);
      });

      // Load records for the selected date
      _loadRecordsForDate(_formattedDate);
    }
  }

  // Format timestamp to readable time
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Invalid date';
      }

      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Activity Log"),
        actions: [
          // Filter button
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
            tooltip: "Filter activities",
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DarkColor.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Date',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _displayDate,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: Icon(Icons.calendar_today, size: 18),
                  label: Text('Change'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip("All", _activityFilter == "all", () {
                  setState(() {
                    _activityFilter = "all";
                  });
                  _loadRecordsForDate(_formattedDate);
                }),
                SizedBox(width: 8),
                _filterChip("Check-ins", _activityFilter == "check-in", () {
                  setState(() {
                    _activityFilter = "check-in";
                  });
                  _loadRecordsForDate(_formattedDate);
                }, color: Colors.green),
                SizedBox(width: 8),
                _filterChip("Check-outs", _activityFilter == "check-out", () {
                  setState(() {
                    _activityFilter = "check-out";
                  });
                  _loadRecordsForDate(_formattedDate);
                }, color: Colors.orange),
              ],
            ),
          ),

          // Records counter
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  _isLoading
                      ? "Loading activities..."
                      : "${_attendanceRecords.length} activities found",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Activity list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _attendanceRecords.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              itemCount: _attendanceRecords.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              itemBuilder: (context, index) {
                final activity = _attendanceRecords[index];

                // Determine activity type and icon
                final isCheckIn = activity['type'] == 'check-in';
                final activityIcon = isCheckIn
                    ? Icons.login
                    : Icons.logout;
                final activityColor = isCheckIn
                    ? Colors.green
                    : Colors.orange;

                // Format student name and seat
                final studentName = activity['studentName'] ?? 'Unknown Student';
                final seatId = activity['seatId'] ?? activity['seatNo'] ?? 'Unknown';
                final timestamp = activity['timestamp'];

                return ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activityColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activityIcon,
                      color: activityColor,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          studentName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${isCheckIn ? "Checked in to" : "Checked out from"} seat $seatId',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  dense: true,
                  onTap: () {
                    _showActivityDetails(activity);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey.withOpacity(0.6),
          ),
          SizedBox(height: 16),
          Text(
            "No activities found",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _activityFilter == "all"
                ? "No check-ins or check-outs on this date"
                : _activityFilter == "check-in"
                ? "No check-ins on this date"
                : "No check-outs on this date",
            style: TextStyle(
              color: Colors.grey.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _selectDate,
            icon: Icon(Icons.calendar_today),
            label: Text('Choose Another Date'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DarkColor.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Filter chip widget
  Widget _filterChip(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? DarkColor.primary).withOpacity(0.2)
              : DarkColor.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? DarkColor.primary)
                : Colors.grey.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (color ?? DarkColor.primary)
                : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Show filter options dialog
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DarkColor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filter Activities",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),

                // Activity type filters
                Text(
                  "Activity Type",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8),
                ListTile(
                  title: Text("All Activities"),
                  leading: Radio<String>(
                    value: "all",
                    groupValue: _activityFilter,
                    onChanged: (value) {
                      setState(() {
                        _activityFilter = value!;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: Text("Check-ins Only"),
                  leading: Radio<String>(
                    value: "check-in",
                    groupValue: _activityFilter,
                    onChanged: (value) {
                      setState(() {
                        _activityFilter = value!;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: Text("Check-outs Only"),
                  leading: Radio<String>(
                    value: "check-out",
                    groupValue: _activityFilter,
                    onChanged: (value) {
                      setState(() {
                        _activityFilter = value!;
                      });
                    },
                  ),
                ),

                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("Cancel"),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadRecordsForDate(_formattedDate);
                      },
                      child: Text("Apply"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show activity details in a bottom sheet
  void _showActivityDetails(Map<String, dynamic> activity) {
    final isCheckIn = activity['type'] == 'check-in';
    final studentName = activity['studentName'] ?? 'Unknown Student';
    final studentId = activity['studentId'] ?? 'Unknown ID';
    final seatId = activity['seatId'] ?? activity['seatNo'] ?? 'Unknown';
    final timestamp = activity['timestamp'];
    final shiftName = activity['shiftName'] ?? 'Unknown Shift';

    showModalBottomSheet(
      context: context,
      backgroundColor: DarkColor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCheckIn ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCheckIn ? Icons.login : Icons.logout,
                      color: isCheckIn ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCheckIn ? "Check In" : "Check Out",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(color: Colors.grey.shade800),
              SizedBox(height: 16),
              _detailRow("Student", studentName, Icons.person),
              SizedBox(height: 8),
              _detailRow("Student ID", studentId, Icons.badge),
              SizedBox(height: 8),
              _detailRow("Seat", seatId, Icons.event_seat),
              SizedBox(height: 8),
              _detailRow("Shift", shiftName, Icons.access_time),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Detail row helper
  Widget _detailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 8),
        Text('$label:', style: TextStyle(color: Colors.grey)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return '${this[0].toUpperCase()}${this.substring(1)}';
  }
}