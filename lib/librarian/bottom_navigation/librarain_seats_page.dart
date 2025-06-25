import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/models/library_model.dart';
import 'dart:math' show min;

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
  final Function(String, String) onShowSeatDetails;
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
    required this.onShowSeatDetails,
    required this.getShiftName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    // Filter bookings for today and selected shift
    final bookingsForToday = todayBookings.where(
            (b) => b['bookedAt'] == _formatDateToString(selectedDate)
    ).toList();

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
      _shiftsData = Map<String, Map<String, dynamic>>.from(currentLibraryModel!.shifts);
    }

    return Column(
      children: [
        // Enhanced but simplified date selection component
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Text(
                'Select Date',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Simple date selection with 7 days
              SizedBox(
                height: 90,
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
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 65,
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [
                              const Color(0xff1940CC),
                              const Color(0xff1940CC).withOpacity(0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                              : null,
                          color: isSelected
                              ? null
                              : isToday
                              ? const Color(0xff1940CC).withOpacity(0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: isToday && !isSelected
                              ? Border.all(color: const Color(0xff1940CC))
                              : null,
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: const Color(0xff1940CC).withOpacity(0.3),
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
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Day number
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                    ? const Color(0xff1940CC)
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Month name (short)
                            Text(
                              _getMonthName(date.month),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
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

        // Shift selection with improved UI
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Shift:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: shifts.map((shiftId) {
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

                      final shiftName = shiftDetails['name'] ?? getShiftName(shiftId);
                      final startTime = shiftDetails['startTime'] ?? '00:00';
                      final endTime = shiftDetails['endTime'] ?? '00:00';

                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () => onShiftChange(shiftId),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: isSelected
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
                                color: isSelected
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
                                      color: isSelected
                                          ? Colors.white
                                          : shiftColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shiftName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.3)
                                        : shiftColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "$startTime - $endTime",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
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
        Gap(20),

        // Enhanced seat legend with partial booking status
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildEnhancedLegendItem(Colors.green, 'Available'),
                  const SizedBox(width: 16),
                  _buildEnhancedLegendItem(Colors.orange, 'Pending'),
                  const SizedBox(width: 16),
                  _buildEnhancedLegendItem(Colors.red, 'Booked'),
                ],
              ),
            ),
          ],
        ),
        Gap(20),

        // Seat map grid
        Expanded(
          child: isLoadingSeats
              ? const Center(child: CircularProgressIndicator())
              : selectedShift == null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_seat_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Select a shift to view seats',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
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
                Icon(Icons.grid_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No seats found for this library',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
              : _buildEnhancedSeatMap(context, typedBookingsForShift),
        ),

      ],
    );
  }

  // Enhanced version of legend item
  Widget _buildEnhancedLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // Enhanced seat map with grid view and partial booking support
  Widget _buildEnhancedSeatMap(BuildContext context, List<Map<String, dynamic>> bookingsForShift) {
    // Create a map of seat status and student IDs based on bookings
    Map<String, String> seatStatus = {};
    Map<String, String> seatStudentIds = {};

    for (final booking in bookingsForShift) {
      final seatNo = booking['seatNo'];
      if (seatNo != null && seatNo is String) {
        seatStatus[seatNo] = booking['status'] ?? 'available';
        seatStudentIds[seatNo] = booking['studentId'] ?? '';
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
            Icon(Icons.event_seat_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No seat layout available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'This library doesn\'t have a configured seat layout',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

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

            // If row has more than 10 seats, split into multiple rows
            List<Widget> rowWidgets = [];
            if (seatsInRow.length <= 10) {
              // Single row layout
              rowWidgets.add(
                _buildSeatsRowWithHeader(
                  context,
                  row,
                  seatsInRow,
                  seatStatus,
                  seatStudentIds,
                ),
              );
            } else {
              // Split into multiple sub-rows
              int chunksCount = (seatsInRow.length / 10).ceil();
              for (int i = 0; i < chunksCount; i++) {
                int startIdx = i * 10;
                int endIdx = min(startIdx + 10, seatsInRow.length);

                List<MapEntry<String, Map<String, dynamic>>> subRow = seatsInRow.sublist(startIdx, endIdx);

                rowWidgets.add(
                  _buildSeatsRowWithHeader(
                    context,
                    i == 0 ? row : '',
                    subRow,
                    seatStatus,
                    seatStudentIds,
                    isSubRow: i > 0,
                    rowIndicator: i > 0 ? "${row}${i + 1}" : null,
                  ),
                );
              }
            }

            return Column(children: rowWidgets);
          }).toList(),
        ],
      ),
    );
  }

  // Helper to build a row of seats with header
  Widget _buildSeatsRowWithHeader(
      BuildContext context,
      String row,
      List<MapEntry<String, Map<String, dynamic>>> seats,
      Map<String, String> seatStatus,
      Map<String, String> seatStudentIds, {
        bool isSubRow = false,
        String? rowIndicator,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of seats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: seats.map((entry) {
                final seatId = entry.key;
                final seatData = entry.value;

                // Extract seat number (removing the row letter)
                final seatNumber = seatId.length > 1 ? seatId.substring(1) : seatId;

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
                      if (shift.value is Map && shift.value['status'] != null) {
                        if (shift.value['status'] == 'available') {
                          availableShifts++;
                        } else if (shift.value['status'] == 'booked' ||
                            shift.value['status'] == 'confirmed') {
                          bookedShifts++;
                        }
                      }
                    });

                    // Check selected shift status specifically
                    if (selectedShift != null && shiftsData.containsKey(selectedShift)) {
                      final shiftData = shiftsData[selectedShift];
                      if (shiftData is Map && shiftData.containsKey('status')) {
                        status = shiftData['status'].toString();
                      }
                    }

                    // Check if partially booked (some shifts available, some booked)
                    isPartiallyBooked = availableShifts > 0 && bookedShifts > 0;
                  }
                }

                // Determine color based on status
                Color seatColor;
                switch (status.toLowerCase()) {
                  case 'booked':
                    seatColor = Colors.red;
                    break;
                  case 'pending':
                    seatColor = Colors.orange;
                    break;
                  case 'available':
                  default:
                    seatColor = isPartiallyBooked ? Colors.amber : Colors.green;
                }

                return Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onShowSeatDetails(seatId, studentId),
                    child: Container(
                      decoration: BoxDecoration(
                        color: seatColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Seat number
                          Text(
                            '$row $seatNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          // Indicator if seat has student
                          if (studentId.isNotEmpty || isPartiallyBooked)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                height: 8,
                                width: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
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
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  // Helper for getting month name
  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '';
    }
  }
}