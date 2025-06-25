// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-22 04:01:36
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../data/string.dart'; // For SmartLib.userId access

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }


  @override
// Fetch activity data from Firestore's attendanceHistory collection
  Future<void> _fetchActivities() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final studentId = SmartLib.userId;
      if (studentId == null || studentId.isEmpty) {
        throw Exception('User ID is not available');
      }

      // Get recent dates to check (last 30 days)
      final now = DateTime.now();
      final dateFormat = DateFormat('yyyy-MM-dd');
      final datesToCheck = List.generate(30, (index) {
        final date = now.subtract(Duration(days: index));
        return dateFormat.format(date);
      });

      List<Map<String, dynamic>> allActivities = [];

      // Query each date's records for this student
      for (final date in datesToCheck) {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('attendanceHistory')
            .doc(date)
            .collection('records')
            .where('studentId', isEqualTo: studentId)
            .where('type', whereIn: ['Check-In', 'Check-Out']) // Only get records with valid type
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Skip records without type field
          if (!data.containsKey('type') || data['type'] == null) {
            continue;
          }

          // Get library name
          String libraryName = 'Unknown Library';
          if (data.containsKey('libraryId') && data['libraryId'] != null) {
            try {
              final libraryDoc = await FirebaseFirestore.instance
                  .collection('libraries')
                  .doc(data['libraryId'])
                  .get();

              if (libraryDoc.exists) {
                libraryName = libraryDoc.data()?['libraryName'] ?? 'Unknown Library';
              }
            } catch (e) {
              print('Error fetching library name: $e');
            }
          }

          try {
            // Parse timestamp to DateTime
            DateTime recordTimestamp;
            if (data.containsKey('timestamp') && data['timestamp'] != null) {
              // Handle different timestamp formats
              if (data['timestamp'] is Timestamp) {
                recordTimestamp = (data['timestamp'] as Timestamp).toDate();
              } else {
                recordTimestamp = DateTime.parse(data['timestamp'].toString());
              }
            } else {
              // Fallback to createdAt or today
              if (data.containsKey('createdAt') && data['createdAt'] != null) {
                if (data['createdAt'] is Timestamp) {
                  recordTimestamp = (data['createdAt'] as Timestamp).toDate();
                } else {
                  recordTimestamp = DateTime.parse(data['createdAt'].toString());
                }
              } else {
                recordTimestamp = DateTime.now();
              }
            }

            // Determine status based on type
            String status = 'unknown';
            if (data['type'] == 'Check-In') {
              status = 'checked_in';
            } else if (data['type'] == 'Check-Out') {
              status = 'checked_out';
            } else {
              status = data['status'] ?? 'unknown';
            }

            // Create activity object
            allActivities.add({
              'type': data['type'],
              'library': libraryName,
              'seat': data['seatNo'] ?? 'Unknown',
              'timestamp': recordTimestamp,
              'status': status,
              'shiftId': data['shiftId'],
              'shiftIds': data['shiftIds'],
              'isMultipleShifts': data['isMultipleShifts'] ?? false,
              'duration': data['type'] == 'Check-Out' ? data['duration'] : null,
            });
          } catch (e) {
            print('Error processing activity record: $e');
          }
        }
      }

      // Sort activities by timestamp (newest first)
      allActivities.sort((a, b) {
        final DateTime timestampA = a['timestamp'] as DateTime;
        final DateTime timestampB = b['timestamp'] as DateTime;
        return timestampB.compareTo(timestampA);
      });

      if (mounted) {
        setState(() {
          _activities = allActivities;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching activity data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load activities: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }
  // Group activities by date (YYYY-MM-DD)
  Map<String, List<Map<String, dynamic>>> _groupActivitiesByDay(List<Map<String, dynamic>> activities) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var act in activities) {
      final dt = act['timestamp'] as DateTime;
      final dateStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(dateStr, () => []).add(act);
    }
    return grouped;
  }

  // Format date for header (Today, Yesterday, or e.g. Monday, Jun 8, 2025)
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) return "Today";
    if (target == today.subtract(const Duration(days: 1))) return "Yesterday";
    // Simple fallback: Day, Mon dd, yyyy
    const weekdays = [
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ];
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    final weekdayStr = weekdays[dt.weekday - 1];
    final monthStr = months[dt.month - 1];
    return "$weekdayStr, $monthStr ${dt.day}, ${dt.year}";
  }

  // Format time as hh:mm AM/PM
  String _formatTime(DateTime dt) {
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? "PM" : "AM";
    if (hour == 0) hour = 12;
    else if (hour > 12) hour -= 12;
    return "$hour:$minute $suffix";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // Show loading indicator
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Activity"),
          centerTitle: true,
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xff1940CC),
          ),
        ),
      );
    }

    // Show error message if any
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Activity"),
          centerTitle: true,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              Gap(16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor.withOpacity(0.7)),
              ),
              Gap(24),
              ElevatedButton(
                onPressed: _fetchActivities,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff1940CC),
                  foregroundColor: Colors.white,
                ),
                child: Text("Try Again"),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupActivitiesByDay(_activities);
    final sortedDays = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest day first

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity"),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchActivities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _activities.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: textColor.withOpacity(0.3),
              ),
              Gap(16),
              Text(
                "No activity yet.",
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _fetchActivities,
          color: Color(0xff1940CC),
          child: ListView.builder(
            physics: AlwaysScrollableScrollPhysics(),
            itemCount: sortedDays.length,
            itemBuilder: (context, dayIdx) {
              final day = sortedDays[dayIdx];
              final dayActivities = grouped[day]!;
              final dayDate = dayActivities.first['timestamp'] as DateTime;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dayIdx > 0) Gap(18),
                  Text(
                    _formatDate(dayDate),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  Gap(6),
                  ...dayActivities.map((activity) {
                    final isCheckIn = activity['status'] == 'checked_in';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isCheckIn ? Colors.green : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCheckIn ? Icons.login : Icons.logout,
                            color: isCheckIn ? Colors.green : Colors.orange,
                            size: 30,
                          ),
                          Gap(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      activity['type'],
                                      style: TextStyle(
                                        color: isCheckIn ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (activity['isMultipleShifts'] == true)
                                      Container(
                                        margin: EdgeInsets.only(left: 8),
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "Multiple Shifts",
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    Spacer(),
                                    Text(
                                      _formatTime(activity['timestamp']),
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Gap(3),
                                Row(
                                  children: [
                                    Icon(Icons.apartment, size: 16, color: textColor.withOpacity(0.7)),
                                    SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        activity['library'],
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Gap(3),
                                Row(
                                  children: [
                                    Icon(Icons.event_seat, size: 16, color: textColor.withOpacity(0.7)),
                                    SizedBox(width: 5),
                                    Text(
                                      "Seat ${activity['seat']}",
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),

                                // Show shift ID
                                if (activity['shiftId'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: [
                                        Icon(Icons.schedule, size: 16, color: textColor.withOpacity(0.7)),
                                        SizedBox(width: 5),
                                        Text(
                                          "Shift ${activity['shiftId']}",
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Show duration if available (for check-out)
                                if (!isCheckIn && activity['duration'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: [
                                        Icon(Icons.timer, size: 16, color: textColor.withOpacity(0.7)),
                                        SizedBox(width: 5),
                                        Text(
                                          _formatDuration(activity['duration']),
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Format duration in minutes to readable format
  String _formatDuration(dynamic durationValue) {
    try {
      final minutes = int.parse(durationValue.toString());
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;

      if (hours > 0) {
        return '$hours hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
      } else {
        return '$minutes min';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}