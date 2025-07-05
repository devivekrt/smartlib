import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../data/string.dart'; // For SmartLib.userId access

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  // Cache for library names to avoid repeated queries
  final Map<String, String> _libraryNameCache = {};

  // Stream subscriptions management
  final List<StreamSubscription> _subscriptions = [];

  // Pagination control
  int _daysToLoad = 7; // Start with 7 days
  bool _canLoadMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    // Start by loading libraries to cache them
    _loadLibraries().then((_) {
      _setupActivityListeners();
    });
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  // Preload all libraries to cache for faster access
  Future<void> _loadLibraries() async {
    try {
      final librariesSnapshot = await FirebaseFirestore.instance
          .collection('libraries')
          .get();

      for (final doc in librariesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('libraryName')) {
          _libraryNameCache[doc.id] = data['libraryName'];
        }
      }
    } catch (e) {
      print('Error preloading libraries: $e');
    }
  }

  // Setup listeners for activity data using streams
  Future<void> _setupActivityListeners() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final studentId = SmartLib.userId;
      if (studentId == null || studentId.isEmpty) {
        throw Exception('User ID is not available');
      }

      // Get recent dates to check
      final now = DateTime.now();
      final dateFormat = DateFormat('yyyy-MM-dd');
      final datesToCheck = List.generate(_daysToLoad, (index) {
        final date = now.subtract(Duration(days: index));
        return dateFormat.format(date);
      });

      // Clear activities if not loading more
      if (_daysToLoad <= 7) {
        _activities.clear();
      }

      // Cancel existing subscriptions if refreshing
      if (_daysToLoad <= 7) {
        for (var subscription in _subscriptions) {
          subscription.cancel();
        }
        _subscriptions.clear();
      }

      // Create a listener for each date
      for (final date in datesToCheck) {
        // Skip dates we already have listeners for when loading more
        if (_daysToLoad > 7 && _subscriptions.length > (date.hashCode % _subscriptions.length)) {
          continue;
        }

        // Create a stream for this date's activity
        final stream = FirebaseFirestore.instance
            .collection('attendanceHistory')
            .doc(date)
            .collection('records')
            .where('studentId', isEqualTo: studentId)
            .where('type', whereIn: ['Check-In', 'Check-Out'])
            .snapshots();

        // Subscribe to the stream
        final subscription = stream.listen((snapshot) {
          _processActivitySnapshot(snapshot, date);
        }, onError: (e) {
          print('Error in stream for date $date: $e');
        });

        _subscriptions.add(subscription);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error setting up activity listeners: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  // Process snapshot data from Firestore
  void _processActivitySnapshot(QuerySnapshot snapshot, String date) {

    // Get existing activities for this date to check for duplicates
    final existingIds = _activities
        .where((act) => act['date'] == date)
        .map((act) => act['id'])
        .toSet();

    final newActivities = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      // Skip if already processed
      if (existingIds.contains(doc.id)) continue;

      final data = doc.data() as Map<String, dynamic>;

      // Skip records without type field
      if (!data.containsKey('type') || data['type'] == null) continue;

      try {
        // Get library name from cache
        String libraryName = 'Unknown Library';
        final libraryId = data['libraryId'];
        if (libraryId != null && _libraryNameCache.containsKey(libraryId)) {
          libraryName = _libraryNameCache[libraryId]!;
        }

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
        newActivities.add({
          'id': doc.id,
          'date': date,
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

    if (newActivities.isNotEmpty) {
      setState(() {
        _activities.addAll(newActivities);
        // Sort activities by timestamp (newest first)
        _activities.sort((a, b) {
          final DateTime timestampA = a['timestamp'] as DateTime;
          final DateTime timestampB = b['timestamp'] as DateTime;
          return timestampB.compareTo(timestampA);
        });
      });
    }
  }

  // Load more activities (pagination)
  void _loadMore() {
    if (_isLoadingMore || !_canLoadMore) return;

    setState(() {
      _isLoadingMore = true;
      _daysToLoad += 7; // Load 7 more days
    });

    _setupActivityListeners();
  }

  // Group activities by date (YYYY-MM-DD) - memoized for performance
  Map<String, List<Map<String, dynamic>>> _groupActivitiesByDay() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var act in _activities) {
      final dt = act['timestamp'] as DateTime;
      final dateStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(dateStr, () => []).add(act);
    }
    return grouped;
  }

  // Cached date formatting results
  final Map<DateTime, String> _dateFormatCache = {};

  // Format date for header (Today, Yesterday, or e.g. Monday, Jun 8, 2025)
  String _formatDate(DateTime dt) {
    // Check cache first for better performance
    final dateKey = DateTime(dt.year, dt.month, dt.day);
    if (_dateFormatCache.containsKey(dateKey)) {
      return _dateFormatCache[dateKey]!;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);

    String result;
    if (target == today) {
      result = "Today";
    } else if (target == today.subtract(const Duration(days: 1))) {
      result = "Yesterday";
    } else {
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
      result = "$weekdayStr, $monthStr ${dt.day}, ${dt.year}";
    }

    // Cache the result
    _dateFormatCache[dateKey] = result;
    return result;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // Show loading indicator
    if (_isLoading) {
      return _buildScaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: const Color(0xff1940CC),
          ),
        ),
      );
    }


    final grouped = _groupActivitiesByDay();
    final sortedDays = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest day first

    // Show empty state
    if (_activities.isEmpty) {
      return _buildScaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: textColor.withOpacity(0.3),
                ),
                const Gap(16),
                Text(
                  "No activity yet.",
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show activities list
    return _buildScaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: RefreshIndicator(
          onRefresh: () async {
            _daysToLoad = 7;
            await _setupActivityListeners();
          },
          color: const Color(0xff1940CC),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: sortedDays.length + 1, // +1 for load more button
            itemBuilder: (context, idx) {
              // Show load more button at the end
              if (idx == sortedDays.length) {
                return _canLoadMore
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xff1940CC),
                    )
                        : TextButton(
                      onPressed: _loadMore,
                      child: const Text("Load More"),
                    ),
                  ),
                )
                    : const SizedBox.shrink();
              }

              final day = sortedDays[idx];
              final dayActivities = grouped[day]!;
              final dayDate = dayActivities.first['timestamp'] as DateTime;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0) const Gap(18),
                  Text(
                    _formatDate(dayDate),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  const Gap(6),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayActivities.length,
                    itemBuilder: (context, actIdx) {
                      final activity = dayActivities[actIdx];
                      return _buildActivityCard(activity, cardColor, textColor);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Extract scaffold to reduce code duplication
  Widget _buildScaffold({required Widget body}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity"),
        centerTitle: true,
        elevation: 0,
      ),
      body: body,
    );
  }

  // Extract activity card to make code cleaner
  Widget _buildActivityCard(Map<String, dynamic> activity, Color cardColor, Color textColor) {
    final isCheckIn = activity['status'] == 'checked_in';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
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
          const Gap(16),
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
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Multiple Shifts",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _formatTime(activity['timestamp']),
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Gap(3),
                Row(
                  children: [
                    Icon(Icons.apartment, size: 16, color: textColor.withOpacity(0.7)),
                    const SizedBox(width: 5),
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
                const Gap(3),
                Row(
                  children: [
                    Icon(Icons.event_seat, size: 16, color: textColor.withOpacity(0.7)),
                    const SizedBox(width: 5),
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
                        const SizedBox(width: 5),
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
                        const SizedBox(width: 5),
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
  }
}