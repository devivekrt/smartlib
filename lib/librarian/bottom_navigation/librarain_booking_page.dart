import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'dart:math' show min;

import '../../theme/theme.dart';


class LibrarianBookingsPage extends StatelessWidget {
  final List<Map<String, dynamic>> bookingHistory;
  final String selectedDateRange;
  final String selectedStatus;
  final List<String> dateRanges;
  final List<String> statuses;
  final bool isLoadingBookings;
  final Function(String) onChangeDateRangeFilter;
  final Function(String) onChangeStatusFilter;
  final Function(Map<String, dynamic>) onShowBookingDetailsDialog;
  final Function(String) onConfirmPayment;
  final Function() onShowSearchBookingsDialog;
  final Function() onFetchBookingHistory;
  final Function(String) getShiftName;

  const LibrarianBookingsPage({
    Key? key,
    required this.bookingHistory,
    required this.selectedDateRange,
    required this.selectedStatus,
    required this.dateRanges,
    required this.statuses,
    required this.isLoadingBookings,
    required this.onChangeDateRangeFilter,
    required this.onChangeStatusFilter,
    required this.onShowBookingDetailsDialog,
    required this.onConfirmPayment,
    required this.onShowSearchBookingsDialog,
    required this.onFetchBookingHistory,
    required this.getShiftName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter bookings based on current selections
    List<Map<String, dynamic>> filteredBookings = bookingHistory;

    // Apply status filter
    if (selectedStatus != 'All') {
      filteredBookings = filteredBookings.where(
            (booking) => booking['status']?.toString().toLowerCase() == selectedStatus.toLowerCase(),
      ).toList();
    }

    // Apply date range filter
    if (selectedDateRange != 'All') {
      filteredBookings = _applyDateRangeFilter(
        filteredBookings,
        selectedDateRange,
      );
    }



    // Group filtered bookings by date
    final Map<String, List<Map<String, dynamic>>> groupedFilteredBookings = {};
    for (final booking in filteredBookings) {
      final date = booking['bookedAt'] ?? 'Unknown';
      if (!groupedFilteredBookings.containsKey(date)) {
        groupedFilteredBookings[date] = [];
      }
      groupedFilteredBookings[date]!.add(booking);
    }

    // Get sorted dates (most recent first)
    final List<String> sortedDates = groupedFilteredBookings.keys.toList()..sort((a, b) => b.compareTo(a));



    return Theme(
      data: darkTheme,
      child: Column(
        children: [

          // Filter section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date range selector
                Row(
                  children: [
                    Text(
                      'Date Range:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DarkColor.text,
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      decoration: BoxDecoration(
                        color: DarkColor.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DarkColor.borderColor, width: 0.5),
                      ),
                      child: DropdownButton<String>(
                        value: selectedDateRange,
                        dropdownColor: DarkColor.cardColor,
                        style: TextStyle(color: DarkColor.text),
                        underline: SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, color: DarkColor.text),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            onChangeDateRangeFilter(newValue);
                          }
                        },
                        items: dateRanges.map<DropdownMenuItem<String>>(
                                (String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }
                        ).toList(),
                      ),
                    ),
                  ],
                ),

                const Gap(16),

                // Status filter and search button
                Row(
                  children: [
                    // Status filter
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Status:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: DarkColor.text,
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              decoration: BoxDecoration(
                                color: DarkColor.cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: DarkColor.borderColor, width: 0.5),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                dropdownColor: DarkColor.cardColor,
                                value: selectedStatus,
                                style: TextStyle(color: DarkColor.text),
                                underline: SizedBox(),
                                icon: Icon(Icons.arrow_drop_down, color: DarkColor.text),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    onChangeStatusFilter(newValue);
                                  }
                                },
                                items: statuses.map<DropdownMenuItem<String>>(
                                        (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }
                                ).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search button
                    Container(
                      decoration: BoxDecoration(
                        color: DarkColor.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DarkColor.borderColor, width: 0.5),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.search, color: DarkColor.text),
                        onPressed: onShowSearchBookingsDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bookings count summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${filteredBookings.length} bookings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: DarkColor.text,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: onFetchBookingHistory,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(DarkColor.primary),
                    foregroundColor: MaterialStateProperty.all(DarkColor.black),
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: DarkColor.borderColor),

          // Bookings list with pull to refresh
          Expanded(
            child: isLoadingBookings
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: DarkColor.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading bookings...',
                    style: TextStyle(color: DarkColor.text),
                  ),
                ],
              ),
            )
                : filteredBookings.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: DarkColor.text.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No bookings found",
                    style: TextStyle(
                      fontSize: 16,
                      color: DarkColor.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Try changing your filters",
                    style: TextStyle(color: DarkColor.text.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                    style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all(DarkColor.primary),
                      side: MaterialStateProperty.all(BorderSide(color: DarkColor.primary)),
                    ),
                    onPressed: onFetchBookingHistory,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: DarkColor.primary,
              backgroundColor: DarkColor.cardColor,
              onRefresh: () async => onFetchBookingHistory(),
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                // Build one item per date group + bookings within that date
                itemCount: sortedDates.length,
                itemBuilder: (context, dateIndex) {
                  final date = sortedDates[dateIndex];
                  final dateBookings = groupedFilteredBookings[date]!;

                  // Format date for display
                  String displayDate = 'Unknown Date';
                  try {
                    final dateObj = DateTime.parse(date);
                    final now = DateTime.now();
                    final yesterday = DateTime.now().subtract(
                      const Duration(days: 1),
                    );

                    if (dateObj.year == now.year &&
                        dateObj.month == now.month &&
                        dateObj.day == now.day) {
                      displayDate = 'Today';
                    } else if (dateObj.year == yesterday.year &&
                        dateObj.month == yesterday.month &&
                        dateObj.day == yesterday.day) {
                      displayDate = 'Yesterday';
                    } else {
                      displayDate = DateFormat('EEE, MMM d, yyyy').format(dateObj);
                    }
                  } catch (e) {
                    // Keep default if parsing fails
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 16.0,
                          bottom: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: DarkColor.text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: DarkColor.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: DarkColor.primary.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                '${dateBookings.length}',
                                style: TextStyle(
                                  color: DarkColor.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bookings for this date
                      ...dateBookings.map((booking) {
                        // Define the card background color based on status
                        Color cardColor = DarkColor.cardColor;
                        Color statusColor;
                        String status = booking['status'] ?? 'pending';

                        if (status == 'confirmed') {
                          statusColor = DarkColor.green;
                        } else if (status == 'pending') {
                          statusColor = DarkColor.orange;
                        } else if (status == 'canceled' || status == 'cancelled') {
                          statusColor = DarkColor.text.withOpacity(0.5);
                        } else {
                          statusColor = DarkColor.primary;
                        }

                        // Check if payment needs confirmation
                        final needsPaymentConfirmation =
                            (booking['paymentMethod'] == 'cash' ||
                                booking['paymentMethod'] == 'pay to owner') &&
                                booking['paymentStatus'] == 'pending';

                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: 8.0,
                            left: 8.0,
                            right: 8.0,
                          ),
                          color: cardColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: statusColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withOpacity(0.2),
                                  child: Text(
                                    booking['seatNo'] ?? 'N/A',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Student: ${booking['studentId'] ?? 'Unknown'}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: DarkColor.text,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 2.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),

                                    // Booking details
                                    Row(
                                      children: [

                                        Icon(
                                          Icons.confirmation_number,
                                          size: 14,
                                          color: DarkColor.text.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Booking ID: ${(booking['bookingId'] ?? 'Unknown').toString().substring(0, min(8, (booking['bookingId'] ?? 'Unknown').toString().length))}...',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: DarkColor.text,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Show payment status - Fixed overflow issue
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.payment,
                                          size: 14,
                                          color: booking['paymentStatus'] == 'paid'
                                              ? DarkColor.green
                                              : DarkColor.red,
                                        ),
                                        const SizedBox(width: 4),
                                        // Wrap the text in Flexible to allow it to shrink if needed
                                        Flexible(
                                          child: Text(
                                            'Payment: ${booking['paymentStatus'] ?? 'pending'}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: booking['paymentStatus'] == 'paid'
                                                  ? DarkColor.green
                                                  : DarkColor.red,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (needsPaymentConfirmation)
                                          Flexible(
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                left: 4,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: DarkColor.orange,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Needs confirmation',
                                                style: TextStyle(
                                                  color: DarkColor.white,
                                                  fontSize: 9,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.more_vert, color: DarkColor.text),
                                  onPressed: () => onShowBookingDetailsDialog(booking),
                                ),
                              ),
                              if (needsPaymentConfirmation)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () {
                                          // Implement reject data
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: DarkColor.cardColor,
                                              title: Text(
                                                'Reject Payment?',
                                                style: TextStyle(color: DarkColor.text),
                                              ),
                                              content: Text(
                                                'Are you sure you want to reject this payment? This will cancel the booking.',
                                                style: TextStyle(color: DarkColor.text),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  style: ButtonStyle(
                                                    foregroundColor: MaterialStateProperty.all(DarkColor.text),
                                                  ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  style: ButtonStyle(
                                                    backgroundColor: MaterialStateProperty.all(DarkColor.red),
                                                    foregroundColor: MaterialStateProperty.all(DarkColor.white),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    // Add rejection implementation
                                                  },
                                                  child: const Text('Reject'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        style: ButtonStyle(
                                          side: WidgetStateProperty.all(BorderSide(color: DarkColor.red)),
                                          foregroundColor: WidgetStateProperty.all(DarkColor.red),
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: () => onConfirmPayment(booking['bookingId']),
                                        style: ButtonStyle(
                                          backgroundColor: WidgetStateProperty.all(DarkColor.green),
                                          foregroundColor: WidgetStateProperty.all(DarkColor.white),
                                        ),
                                        child: const Text('Confirm Payment'),
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

        ],
      ),
    );
  }

  // Helper method to apply date range filter
  List<Map<String, dynamic>> _applyDateRangeFilter(
      List<Map<String, dynamic>> bookings,
      String rangeType,
      ) {
    final now = DateTime.now();

    switch (rangeType) {
      case 'Today':
        final today = _formatDateToString(now);
        return bookings.where((booking) {
          return booking['bookedAt'] == today;
        }).toList();

      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));

        return bookings.where((booking) {
          try {
            final bookingDate = DateTime.parse(booking['bookedAt']);
            return !bookingDate.isBefore(startOfWeek) &&
                !bookingDate.isAfter(endOfWeek);
          } catch (_) {
            return false;
          }
        }).toList();

      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        return bookings.where((booking) {
          try {
            final bookingDate = DateTime.parse(booking['bookedAt']);
            return !bookingDate.isBefore(startOfMonth) &&
                !bookingDate.isAfter(endOfMonth);
          } catch (_) {
            return false;
          }
        }).toList();

      case 'Custom':
      // This would use a date range picker
        return bookings;

      default:
        return bookings;
    }
  }

  // Helper for formatting dates (YYYY-MM-DD)
  String _formatDateToString(DateTime date) {
    return "${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}";
  }

  // Helper for 2-digit formatting
  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }
}

