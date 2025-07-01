import 'package:flutter/material.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'dart:math' show max, min;

import 'package:smartlib/library/library_edit_screen.dart';

import '../../theme/theme.dart';
import '../library_checkin_classroom.dart';
import '../library_qrcode_gen.dart';
import '../notification_send.dart';

class LibrarianDashboardPage extends StatelessWidget {
  final Map<String, dynamic> currentLibrary;
  final LibraryModel? currentLibraryModel;
  final List<Map<String, dynamic>> todayBookings;
  final List<Map<String, dynamic>> pendingPayments;
  final Map<String, int> occupancyByShift;
  final List<String> shifts;
  final DateTime selectedDate;
  final Function(DateTime) onDateChange;
  final String Function(String) getShiftName;

  const LibrarianDashboardPage({
    Key? key,
    required this.currentLibrary,
    required this.currentLibraryModel,
    required this.todayBookings,
    required this.pendingPayments,
    required this.occupancyByShift,
    required this.shifts,
    required this.selectedDate,
    required this.onDateChange,
    required this.getShiftName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if we have a valid library model
    if (currentLibraryModel == null) {
      return Theme(
        data: darkTheme,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, size: 64, color: DarkColor.orange),
                      SizedBox(height: 16),
                      Text(
                        "No library selected",
                        style: TextStyle(color: DarkColor.text, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Main scrollable content
        Expanded(
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
                                // Access libraryName directly from the root
                                currentLibrary['libraryName'] ?? 'Library',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: DarkColor.text,
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
                                    builder:
                                        (context) => LibraryEditScreen(
                                          librarianId: SmartLib.userId,
                                          libraryId: currentLibrary['id'],
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
                              currentLibrary['location'] ??
                              'Address not available',
                          style: TextStyle(
                            fontSize: 14,
                            color: DarkColor.text.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statItem(
                              "Available Seats",
                              currentLibrary['availableSeats']?.toString() ??
                                  '0',
                              Icons.chair,
                            ),
                            _statItem(
                              "Today's Bookings",
                              todayBookings.length.toString(),
                              Icons.calendar_today,
                            ),
                            _statItem(
                              "Pending Payments",
                              pendingPayments.length.toString(),
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
                    side: BorderSide(color: DarkColor.borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Select Date",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: DarkColor.text,
                          ),
                        ),
                        const Gap(8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(7, (index) {
                              final date = DateTime.now().add(
                                Duration(days: index - 3),
                              );
                              final isSelected = _isSameDay(date, selectedDate);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: GestureDetector(
                                  onTap: () => onDateChange(date),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? DarkColor.primary
                                              : DarkColor.cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? DarkColor.primary
                                                : DarkColor.borderColor,
                                        width: 1,
                                      ),
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
                                                    ? DarkColor.black
                                                    : DarkColor.text,
                                          ),
                                        ),
                                        Text(
                                          date.day.toString(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSelected
                                                    ? DarkColor.black
                                                    : DarkColor.text,
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
                    side: BorderSide(color: DarkColor.borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Occupancy by Shift",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: DarkColor.text,
                          ),
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
                    side: BorderSide(color: DarkColor.borderColor, width: 1),
                  ),
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
                          spacing: 16, // horizontal spacing between items
                          runSpacing: 16, // vertical spacing between lines
                          children: [
                            _actionButton(
                              context,
                              "Run Ads",
                              Icons.add_chart_sharp,
                                  () {
                                // Navigate to Run Ads tab
                              },
                              width: _getActionButtonWidth(context),
                            ),
                            _actionButton(
                              context,
                              "Classroom Check-in",
                              Icons.event_seat,
                                  () {
                                // Navigate to seat management tab
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LibraryCheckinManagementPage(
                                      libraryId: currentLibrary['id'],
                                      libraryName: currentLibrary['libraryName'],
                                    ),
                                  ),
                                );
                              },
                              width: _getActionButtonWidth(context),
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
                                      libraryId: currentLibrary['id'],
                                      libraryName: currentLibrary['libraryName'],
                                      libraryAddress: _formatAddress() ?? 'Address not available',
                                      librarianId: SmartLib.userId,
                                    ),
                                  ),
                                );
                              },
                              width: _getActionButtonWidth(context),
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
                                      libraryId: currentLibrary['id'],
                                    ),
                                  ),
                                );
                              },
                              width: _getActionButtonWidth(context),
                            ),
                          ],
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
                    side: BorderSide(color: DarkColor.borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Recent Activity",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: DarkColor.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        todayBookings.isEmpty
                            ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "No recent activity",
                                  style: TextStyle(color: DarkColor.text),
                                ),
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  todayBookings.length > 5
                                      ? 5
                                      : todayBookings.length,
                              itemBuilder: (context, index) {
                                final booking = todayBookings[index];
                                Icon leadingIcon;
                                Color iconColor;

                                if (booking['checkInTime'] != null &&
                                    booking['checkOutTime'] == null) {
                                  iconColor = DarkColor.green;
                                  leadingIcon = Icon(
                                    Icons.login,
                                    color: iconColor,
                                  );
                                } else if (booking['checkOutTime'] != null) {
                                  iconColor = DarkColor.primary;
                                  leadingIcon = Icon(
                                    Icons.logout,
                                    color: iconColor,
                                  );
                                } else {
                                  iconColor = DarkColor.orange;
                                  leadingIcon = Icon(
                                    Icons.calendar_today,
                                    color: iconColor,
                                  );
                                }

                                // Get shift name from nested data
                                String shiftName = 'Unknown';
                                try {
                                  // Correctly access the shifts as a list (array)
                                  if (booking['shifts'] != null) {
                                    // Check if shifts is a List
                                    if (booking['shifts'] is List &&
                                        booking['shifts'].isNotEmpty) {
                                      final shiftsList =
                                          booking['shifts'] as List;
                                      print("Shifts List: $shiftsList");
                                      // Get first shift from the list (or use appropriate data to select the right one)
                                      if (shiftsList.isNotEmpty) {
                                        final firstShift = shiftsList[0];
                                        if (firstShift is Map &&
                                            firstShift['shiftName'] != null) {
                                          shiftName =
                                              firstShift['shiftName']
                                                  .toString();
                                          print("Shift Name: $shiftName");
                                        }
                                      }
                                    }
                                  }
                                } catch (e) {
                                  print("Error accessing shifts data: $e");
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: DarkColor.cardColor,
                                    child: leadingIcon,
                                  ),
                                  title: Text(
                                    'Seat ${booking['seatNo'] ?? 'Unknown'} - $shiftName shift',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: DarkColor.text,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Student ID: ${booking['studentId'] ?? 'Unknown'}',
                                    style: TextStyle(
                                      color: DarkColor.text.withOpacity(0.7),
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (booking['status'] == 'confirmed')
                                              ? DarkColor.green.withOpacity(0.2)
                                              : DarkColor.orange.withOpacity(
                                                0.2,
                                              ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      booking['status'] ?? 'Unknown',
                                      style: TextStyle(
                                        color:
                                            (booking['status'] == 'confirmed')
                                                ? DarkColor.green
                                                : DarkColor.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        if (todayBookings.length > 5)
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () {
                                // Navigate to view all bookings
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: DarkColor.primary,
                              ),
                              child: const Text("View All"),
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
      ],
    );
  }

  // Helper method to format the address from the address map
  String? _formatAddress() {
    final addressMap = currentLibrary['address'];
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
  double _getActionButtonWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate how many buttons should fit in a row based on screen width
    int buttonsPerRow = 4; // Default for large screens

    if (screenWidth < 600) {
      // Small screens (phones) - 2 buttons per row
      buttonsPerRow = 2;
    } else if (screenWidth < 900) {
      // Medium screens (small tablets) - 3 buttons per row
      buttonsPerRow = 3;
    }

    // Calculate the width considering padding and spacing
    // Total card padding (16 on each side) + spacing between items
    double totalHorizontalPadding = 32 + ((buttonsPerRow - 1) * 16);

    // The available width for buttons
    double availableWidth = screenWidth - totalHorizontalPadding;

    // Width per button
    double buttonWidth = availableWidth / buttonsPerRow;

    // Set a minimum width to prevent too small buttons
    return max(70, buttonWidth);
  }

  // Build custom occupancy chart with enhanced UI
  Widget _buildOccupancyChart() {
    // Use the library model to get total seats
    final maxCapacity = currentLibraryModel?.totalSeats ?? 100;

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 20),
      child:
          shifts.isEmpty
              ? Center(
                child: Text(
                  "No shift data available",
                  style: TextStyle(color: DarkColor.text.withOpacity(0.7)),
                ),
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    shifts.map((shift) {
                      final occupancy = occupancyByShift[shift] ?? 0;
                      // Ensure bar height is at least 20% of container height for visibility
                      final percentage =
                          maxCapacity > 0 ? occupancy / maxCapacity : 0;
                      final barHeight =
                          160 *
                          (percentage > 0.05 ? percentage : 0.05).toDouble();

                      // Get the shift name
                      final shiftName = getShiftName(shift);

                      // Determine color based on shift key
                      Color shiftColor;
                      if (shift == 'morning') {
                        shiftColor = DarkColor.orange;
                      } else if (shift == 'afternoon') {
                        shiftColor = DarkColor.primary;
                      } else if (shift == 'evening') {
                        shiftColor = DarkColor.highlightColor;
                      } else {
                        // Derive color from shift name to ensure consistency
                        final hashCode = shift.hashCode;
                        final hue = (hashCode % 360).toDouble();
                        shiftColor =
                            HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            occupancy.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: DarkColor.text,
                            ),
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
                              shift
                                  .substring(0, min(3, shift.length))
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: DarkColor.text.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
    );
  }

  // Helper widget for action buttons
  Widget _actionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  {required double width,}
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
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

  // Helper for formatting dates (e.g., Mon, Tue)
  String _getWeekdayName(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
