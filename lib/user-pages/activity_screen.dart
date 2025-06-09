import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

// Dummy activity data
final List<Map<String, dynamic>> _dummyActivities = [
  {
    'type': 'Check-In',
    'library': 'Central University Library',
    'seat': 'A-42',
    'timestamp': DateTime(2025, 6, 8, 9, 30),
    'status': 'checked_in',
  },
  {
    'type': 'Check-Out',
    'library': 'Central University Library',
    'seat': 'A-42',
    'timestamp': DateTime(2025, 6, 8, 13, 15),
    'status': 'checked_out',
  },
  {
    'type': 'Check-In',
    'library': 'Downtown Study Center',
    'seat': 'B-11',
    'timestamp': DateTime(2025, 6, 6, 14, 10),
    'status': 'checked_in',
  },
  {
    'type': 'Check-Out',
    'library': 'Downtown Study Center',
    'seat': 'B-11',
    'timestamp': DateTime(2025, 6, 6, 17, 5),
    'status': 'checked_out',
  },
];

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late List<Map<String, dynamic>> _activities;

  @override
  void initState() {
    super.initState();
    _activities = List.from(_dummyActivities); // Replace with your fetch logic if needed
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
    final cardColor = isDark ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final grouped = _groupActivitiesByDay(_activities);
    final sortedDays = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest day first

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity"),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _activities.isEmpty
            ? Center(
          child: Text(
            "No activity yet.",
            style: TextStyle(color: textColor.withOpacity(0.6)),
          ),
        )
            : ListView.builder(
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
    );
  }
}