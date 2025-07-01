import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/models/library_model.dart';
import 'dart:math' show min;
import 'package:intl/intl.dart';

class LibrarianSeatsPage extends StatelessWidget {
  final Map<String, dynamic> currentLibrary;
  final LibraryModel? currentLibraryModel;
  final Map<String, Map<String, dynamic>> seats;
  final List<Map<String, dynamic>> todayBookings;
  final List<String> shifts;
  final DateTime selectedDate;
  final String? selectedShift;
  final bool isLoadingSeats;
  final Function(DateTime) onDateChange;
  final Function(String) onShiftChange;
  final String Function(String) getShiftName;

  const LibrarianSeatsPage({
    Key? key,
    required this.currentLibrary,
    required this.currentLibraryModel,
    required this.seats,
    required this.todayBookings,
    required this.shifts,
    required this.selectedDate,
    required this.selectedShift,
    required this.isLoadingSeats,
    required this.onDateChange,
    required this.onShiftChange,
    required this.getShiftName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Filter bookings for today and selected shift
    final bookingsForToday =
        todayBookings
            .where((b) => b['bookedAt'] == _formatDateToString(selectedDate))
            .toList();

    // Create a properly typed list for bookingsForShift
    List<Map<String, dynamic>> typedBookingsForShift = [];

    // Only populate if we have a selected shift
    if (selectedShift != null) {
      for (final booking in bookingsForToday) {
        if (booking['shiftId'] == selectedShift) {
          // Ensure each booking is properly typed as Map<String, dynamic>
          typedBookingsForShift.add(Map<String, dynamic>.from(booking));
        }
      }
    }

    // Create shift data structure
    Map<String, Map<String, dynamic>> _shiftsData = {};
    if (currentLibraryModel?.shifts != null) {
      _shiftsData = Map<String, Map<String, dynamic>>.from(
        currentLibraryModel!.shifts,
      );
    }

    return Column(
      children: [
        // Enhanced date selection component with responsive sizing
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          margin: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 12,
            vertical: isSmallScreen ? 4 : 8,
          ),
          decoration: BoxDecoration(
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
              const Text(
                'Select Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              // Responsive date selection
              SizedBox(
                height: isSmallScreen ? 80 : 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7, // Show one week of dates
                  itemBuilder: (context, index) {
                    // Generate dates from 3 days ago to 3 days ahead
                    final date = DateTime.now().add(Duration(days: index - 3));

                    final isToday = _isSameDay(date, DateTime.now());
                    final isSelected = _isSameDay(date, selectedDate);

                    return GestureDetector(
                      onTap: () => onDateChange(date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 4 : 6,
                        ),
                        width: isSmallScreen ? 55 : 65,
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
                              _getWeekdayName(date),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 4 : 6),

                            // Day number
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : isToday
                                        ? const Color(0xff1940CC)
                                        : Colors.black87,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 2 : 4),

                            // Month name (short)
                            Text(
                              _getMonthName(date.month),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 12,
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

              // Help text
              const SizedBox(height: 4),
              Text(
                'Tap on a date to select it',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Improved shift selection with better responsive UI
        Card(
          margin: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 12,
            vertical: isSmallScreen ? 4 : 6,
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Shift:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children:
                        shifts.map((shiftId) {
                          final isSelected = selectedShift == shiftId;

                          // Determine shift color based on index
                          Color shiftColor;
                          int index = shifts.indexOf(shiftId);
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
                          if (_shiftsData.containsKey(shiftId)) {
                            shiftDetails = _shiftsData[shiftId]!;
                          }

                          final shiftName =
                              shiftDetails['shiftName'] ??
                              getShiftName(shiftId);
                          final startTime =
                              shiftDetails['shiftStartTime'] ?? '00:00';
                          final endTime =
                              shiftDetails['shiftEndTime'] ?? '00:00';

                          // Make shift buttons more compact on small screens
                          return Container(
                            margin: EdgeInsets.only(
                              right: isSmallScreen ? 8 : 12,
                            ),
                            child: InkWell(
                              onTap: () => onShiftChange(shiftId),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
                                          size: isSmallScreen ? 16 : 20,
                                        ),
                                        SizedBox(width: isSmallScreen ? 4 : 8),
                                        Text(
                                          shiftName,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isSmallScreen ? 6 : 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 6 : 8,
                                        vertical: isSmallScreen ? 2 : 4,
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
                                          fontSize: isSmallScreen ? 10 : 12,
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
        const Gap(12),

        // Improved seat legend with clearer status indicators
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seat Status:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildImprovedLegendItem(
                      Colors.green,
                      'Available',
                      isSmallScreen,
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    _buildImprovedLegendItem(
                      Colors.orange,
                      'Pending',
                      isSmallScreen,
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    _buildImprovedLegendItem(
                      Colors.red,
                      'Booked',
                      isSmallScreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(12),

        // Improved seat map grid with responsive sizing
        Expanded(
          child:
              isLoadingSeats
                  ? const Center(child: CircularProgressIndicator())
                  : selectedShift == null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_seat_outlined,
                          size: isSmallScreen ? 48 : 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Text(
                          'Select a shift to view seats',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  )
                  : seats.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_off,
                          size: isSmallScreen ? 48 : 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Text(
                          'No seats found for this library',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  )
                  : _buildResponsiveSeatMap(context, typedBookingsForShift),
        ),
      ],
    );
  }

  // Improved legend item with better visibility
  Widget _buildImprovedLegendItem(
    Color color,
    String label,
    bool isSmallScreen,
  ) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: isSmallScreen ? 20 : 24,
              height: isSmallScreen ? 20 : 24,
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
            // Add a seat icon overlay to make the legend clearer
            Icon(
              Icons.event_seat,
              color: Colors.white.withOpacity(0.7),
              size: isSmallScreen ? 12 : 16,
            ),
          ],
        ),
        SizedBox(width: isSmallScreen ? 4 : 6),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Responsive seat map with better layout for small screens
  Widget _buildResponsiveSeatMap(
    BuildContext context,
    List<Map<String, dynamic>> bookingsForShift,
  ) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    // Create maps of seat information based on bookings
    Map<String, String> seatStatus = {};
    Map<String, String> seatStudentIds = {};
    Map<String, Map<String, dynamic>> bookingDetails = {};

    for (final booking in bookingsForShift) {
      final seatNo = booking['seatNo'];
      if (seatNo != null && seatNo is String) {
        seatStatus[seatNo] = booking['status'] ?? 'available';
        seatStudentIds[seatNo] = booking['studentId'] ?? '';
        bookingDetails[seatNo] = booking;
      }
    }

    // Process seats into rows for better organization
    Map<String, List<MapEntry<String, Map<String, dynamic>>>> seatsByRow = {};

    seats.entries.forEach((entry) {
      final seatId = entry.key;
      if (seatId.isNotEmpty) {
        try {
          final row = seatId.substring(0, 1).toUpperCase();
          if (!seatsByRow.containsKey(row)) {
            seatsByRow[row] = [];
          }
          seatsByRow[row]!.add(entry);
        } catch (e) {
          print('Error processing seat ID: $seatId - $e');
        }
      }
    });

    // Sort rows alphabetically
    final sortedRows = seatsByRow.keys.toList()..sort();

    if (sortedRows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_seat_outlined,
              size: isSmallScreen ? 48 : 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              'No seat layout available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'This library doesn\'t have a configured seat layout',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ],
        ),
      );
    }

    // Determine the number of seats to show per row based on screen size
    final seatsPerRow = isSmallScreen ? 5 : 10;

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

            // Split into multiple rows based on screen size
            List<Widget> rowWidgets = [];
            int chunksCount = (seatsInRow.length / seatsPerRow).ceil();

            for (int i = 0; i < chunksCount; i++) {
              int startIdx = i * seatsPerRow;
              int endIdx = min(startIdx + seatsPerRow, seatsInRow.length);

              List<MapEntry<String, Map<String, dynamic>>> subRow = seatsInRow
                  .sublist(startIdx, endIdx);

              rowWidgets.add(
                _buildResponsiveSeatsRow(
                  context,
                  i == 0 ? row : '',
                  subRow,
                  seatStatus,
                  seatStudentIds,
                  bookingDetails,
                  isSubRow: i > 0,
                  rowIndicator: i > 0 ? "$row${i + 1}" : null,
                ),
              );
            }

            return Column(children: rowWidgets);
          }).toList(),
        ],
      ),
    );
  }

  // Helper to build a responsive row of seats
  Widget _buildResponsiveSeatsRow(
    BuildContext context,
    String row,
    List<MapEntry<String, Map<String, dynamic>>> seats,
    Map<String, String> seatStatus,
    Map<String, String> seatStudentIds,
    Map<String, Map<String, dynamic>> bookingDetails, {
    bool isSubRow = false,
    String? rowIndicator,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final seatSize = isSmallScreen ? 40.0 : 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row header with letter indicator
        if (row.isNotEmpty || rowIndicator != null)
          Padding(
            padding: EdgeInsets.only(
              left: isSmallScreen ? 12 : 16,
              top: 12,
              bottom: 4,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 12,
                vertical: isSmallScreen ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xff1940CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xff1940CC).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Row ${rowIndicator ?? row}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 12 : 14,
                  color: const Color(0xff1940CC),
                ),
              ),
            ),
          ),

        // Grid of seats with improved visibility
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 16,
            vertical: isSmallScreen ? 6 : 8,
          ),
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
                      if (shiftsData is Map) {
                        shiftsData.entries.forEach((shift) {
                          if (shift.value is Map &&
                              shift.value['status'] != null) {
                            if (shift.value['status'] == 'available') {
                              availableShifts++;
                            } else if (shift.value['status'] == 'booked' ||
                                shift.value['status'] == 'confirmed') {
                              bookedShifts++;
                              // If this is our selected shift, get the student ID
                              if (selectedShift != null &&
                                  shift.key == selectedShift) {
                                studentId = shift.value['bookedBy'] ?? '';
                              }
                            }
                          }
                        });

                        // Check selected shift status specifically
                        if (selectedShift != null &&
                            shiftsData.containsKey(selectedShift)) {
                          final shiftData = shiftsData[selectedShift];
                          if (shiftData is Map &&
                              shiftData.containsKey('status')) {
                            status = shiftData['status'].toString();
                          }
                        }

                        // Check if partially booked (some shifts available, some booked)
                        isPartiallyBooked =
                            availableShifts > 0 && bookedShifts > 0;
                      }
                    }

                    // Determine color and icon based on status
                    Color seatColor;
                    IconData? seatIcon;

                    switch (status.toLowerCase()) {
                      case 'booked':
                        seatColor = Colors.red.shade600;
                        seatIcon = Icons.person;
                        break;
                      case 'pending':
                        seatColor = Colors.orange.shade500;
                        seatIcon = Icons.hourglass_top;
                        break;
                      case 'available':
                      default:
                        seatColor =
                            isPartiallyBooked
                                ? Colors.amber.shade500
                                : Colors.green.shade500;
                        seatIcon = isPartiallyBooked ? Icons.access_time : null;
                    }

                    return Container(
                      width: seatSize,
                      height: seatSize,
                      margin: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 3 : 4,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          if (studentId.isNotEmpty) {
                            _showModernStudentDetailsDialog(
                              context,
                              seatId,
                              studentId,
                              bookingDetails,
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [seatColor, seatColor.withOpacity(0.8)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: seatColor.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Seat icon if applicable
                              if (seatIcon != null)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Icon(
                                    seatIcon,
                                    size: isSmallScreen ? 10 : 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),

                              // Seat number
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    row,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: isSmallScreen ? 10 : 12,
                                    ),
                                  ),
                                  Text(
                                    seatNumber,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                  ),
                                ],
                              ),

                              // Indicator if seat has student
                              if (studentId.isNotEmpty)
                                Positioned(
                                  bottom: 4,
                                  child: Container(
                                    height: 4,
                                    width: seatSize * 0.6,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(2),
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

  // Improved student details dialog with modern UI
  void _showModernStudentDetailsDialog(
    BuildContext context,
    String seatId,
    String studentId,
    Map<String, Map<String, dynamic>> bookingDetails,
  ) async {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get booking details if available
      Map<String, dynamic>? booking = bookingDetails[seatId];
      String bookingId = booking?['bookingId'] ?? '';

      // Get subscriber data from Firestore
      DocumentSnapshot? subscriberData;

      if (currentLibrary['id'] != null) {
        try {
          subscriberData =
              await FirebaseFirestore.instance
                  .collection('libraries')
                  .doc(currentLibrary['id'])
                  .collection('subscribers')
                  .doc(studentId)
                  .get();
        } catch (e) {
          print('Error fetching subscriber data: $e');
        }
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Extract student data
      final studentName =
          subscriberData?.get('studentName') ??
          booking?['studentName'] ??
          'Not available';
      final studentEmail =
          subscriberData?.exists == true ? subscriberData?.get('email') : null;
      final studentPhone =
          subscriberData?.exists == true ? subscriberData?.get('phone') : null;
      final status =
          booking?['status'] ??
          subscriberData?.get('subscriptionStatus') ??
          'Unknown';
      final paymentStatus =
          booking?['paymentStatus'] ??
          subscriberData?.get('paymentStatus') ??
          'Unknown';
      final shiftName =
          booking?['shiftName'] ??
          subscriberData?.get('shiftName') ??
          'Unknown';
      final shiftStartTime =
          booking?['shiftStartTime'] ??
          subscriberData?.get('shiftStartTime') ??
          'N/A';
      final shiftEndTime =
          booking?['shiftEndTime'] ??
          subscriberData?.get('shiftEndTime') ??
          'N/A';
      final dueDate =
          booking?['dueDate'] ??
          (subscriberData?.exists == true
              ? subscriberData?.get('dueDate')
              : null);

      // Now show the modernized detailed dialog
      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff1940CC),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 16 : 20,
                        horizontal: isSmallScreen ? 16 : 24,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isSmallScreen ? 36 : 48,
                            height: isSmallScreen ? 36 : 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.person,
                                color: const Color(0xff1940CC),
                                size: isSmallScreen ? 20 : 28,
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 16 : 20,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: $studentId',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Contact Information Section
                              if (studentEmail != null || studentPhone != null)
                                _buildModernInfoSection(
                                  'Contact Information',
                                  Icons.contact_mail_outlined,
                                  [
                                    if (studentEmail != null)
                                      _buildModernInfoTile(
                                        'Email',
                                        studentEmail.toString(),
                                        Icons.email_outlined,
                                        isSmallScreen,
                                      ),
                                    if (studentPhone != null)
                                      _buildModernInfoTile(
                                        'Phone',
                                        studentPhone.toString(),
                                        Icons.phone_outlined,
                                        isSmallScreen,
                                      ),
                                  ],
                                  isSmallScreen,
                                ),

                              // Booking Information Section
                              _buildModernInfoSection(
                                'Booking Information',
                                Icons.book_online_outlined,
                                [
                                  _buildModernStatusTile(
                                    'Seat',
                                    seatId,
                                    Icons.event_seat_outlined,
                                    Colors.blue,
                                    isSmallScreen,
                                  ),
                                  _buildModernStatusTile(
                                    'Status',
                                    status,
                                    Icons.info_outline,
                                    status.toLowerCase() == 'booked'
                                        ? Colors.green
                                        : Colors.orange,
                                    isSmallScreen,
                                  ),
                                  _buildModernStatusTile(
                                    'Payment',
                                    paymentStatus,
                                    Icons.payment_outlined,
                                    paymentStatus.toLowerCase() == 'paid'
                                        ? Colors.green
                                        : Colors.orange,
                                    isSmallScreen,
                                  ),
                                ],
                                isSmallScreen,
                              ),

                              // Shift Information Section
                              _buildModernInfoSection(
                                'Shift Information',
                                Icons.schedule_outlined,
                                [
                                  _buildModernInfoTile(
                                    'Shift',
                                    shiftName,
                                    Icons.view_timeline_outlined,
                                    isSmallScreen,
                                  ),
                                  _buildModernInfoTile(
                                    'Time',
                                    '$shiftStartTime - $shiftEndTime',
                                    Icons.access_time_outlined,
                                    isSmallScreen,
                                  ),
                                  if (dueDate != null)
                                    _buildModernInfoTile(
                                      'Due Date',
                                      dueDate.toString(),
                                      Icons.event_outlined,
                                      isSmallScreen,
                                    ),
                                ],
                                isSmallScreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    } catch (e) {
      // Close loading dialog if there was an error
      Navigator.of(context).pop();
      print('Error showing student details: $e');

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: const Text(
                'Failed to load student details. Please try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  // Helper method to build a modern information section
  Widget _buildModernInfoSection(
    String title,
    IconData icon,
    List<Widget> children,
    bool isSmallScreen,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 16 : 18,
                color: const Color(0xff1940CC),
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                  color: const Color(0xff1940CC),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // Helper method to build a modern information tile
  Widget _buildModernInfoTile(
    String label,
    String value,
    IconData icon,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 8 : 10,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: isSmallScreen ? 16 : 18),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: isSmallScreen ? 10 : 12),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a modern status tile with color
  Widget _buildModernStatusTile(
    String label,
    String value,
    IconData icon,
    Color statusColor,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 8 : 10,
        horizontal: 12,
      ),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 1))),
      child: Row(
        children: [
          Icon(icon, size: isSmallScreen ? 16 : 18),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: isSmallScreen ? 10 : 12),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: isSmallScreen ? 2 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            value,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: isSmallScreen ? 10 : 12,
                              color: statusColor,
                            ),
                          ),
                        ],
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
  }

  // Helper for formatting dates (YYYY-MM-DD)
  String _formatDateToString(DateTime date) {
    return "${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}";
  }

  // Helper for 2-digit formatting
  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Helper for getting weekday name
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

  // Helper for getting month name
  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }
}
