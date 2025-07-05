import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:smartlib/student/main_tab_screen.dart';
import 'package:smartlib/theme/theme.dart';

class SeatBookingScreen extends StatefulWidget {
  final LibraryModel library;
  final String userId;

  const SeatBookingScreen({
    Key? key,
    required this.library,
    required this.userId,
  }) : super(key: key);

  @override
  _SeatBookingScreenState createState() => _SeatBookingScreenState();
}

class _SeatBookingScreenState extends State<SeatBookingScreen> {
  // Current UTC time as reference
  final DateTime _currentUtcTime = DateTime.now().toUtc();

  // Date selection
  late DateTime _selectedDate;
  List<DateTime> _availableDates = [];

  // Seat selection
  String? _selectedSeat;
  Map<String, dynamic> _seatsData = {};
  bool _isLoadingSeats = true;

  // Shift selection - Updated for multiple selection
  Set<String> _selectedShifts = {};
  Map<String, dynamic> _shiftsData = {};
  Map<String, bool> _availableShiftsForSelectedSeat = {};

  // Scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = _currentUtcTime;
    _generateAvailableDates();
    _initializeShiftsFromLibraryModel();
    _loadSeats();
  }

  // Initialize shifts from library model
  void _initializeShiftsFromLibraryModel() {
    if (widget.library.shifts is Map) {
      try {
        _shiftsData = Map<String, dynamic>.from(widget.library.shifts);
        print(
          "Loaded shifts from library model: ${_shiftsData.keys.length} shifts found",
        );
      } catch (e) {
        print('Error parsing shifts data: $e');
        _setDefaultShifts();
      }
    } else {
      print('Library shifts not found or not in the expected format');
      _setDefaultShifts();
    }
  }

  // Set default shifts if not available from library model
  void _setDefaultShifts() {
    _shiftsData = {
      'morning': {
        'name': 'Morning',
        'startTime': '08:00',
        'endTime': '12:00',
        'fee': 50,
      },
      'afternoon': {
        'name': 'Afternoon',
        'startTime': '12:00',
        'endTime': '16:00',
        'fee': 50,
      },
      'evening': {
        'name': 'Evening',
        'startTime': '16:00',
        'endTime': '20:00',
        'fee': 75,
      },
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Generate available dates (today + next 30 days)
  void _generateAvailableDates() {
    final now = _currentUtcTime;
    _availableDates = List.generate(
      30,
      (index) => DateTime(now.year, now.month, now.day + index),
    );
  }

  // Load seats for selected date
  Future<void> _loadSeats() async {
    setState(() {
      _isLoadingSeats = true;
      _selectedSeat = null;
      _selectedShifts = {};
      _availableShiftsForSelectedSeat = {};
    });

    try {
      final dateFormatted = _formatDateToString(_selectedDate);

      // Get seats for this library
      final libraryRef = FirebaseFirestore.instance
          .collection("libraries")
          .doc(widget.library.id);

      final librarySnapshot = await libraryRef.get();

      if (!librarySnapshot.exists || !mounted) {
        print('Library document not found or component unmounted');
        setState(() {
          _isLoadingSeats = false;
          _seatsData = {};
        });
        return;
      }

      // Get seats data from the library document
      Map<String, dynamic> processedSeats = {};

      // Check if the library has a seats field
      if (librarySnapshot.data()!.containsKey('seats')) {
        Map<String, dynamic> firestoreSeatsData = Map<String, dynamic>.from(
          librarySnapshot.data()!['seats'],
        );

        // Process each seat data
        firestoreSeatsData.forEach((seatNo, seatData) {
          if (seatData is Map) {
            Map<String, dynamic> processedSeat = {'shifts': {}};

            // If seat has shifts data, use it
            if (seatData.containsKey('shifts') && seatData['shifts'] is Map) {
              processedSeat['shifts'] = Map<String, dynamic>.from(
                seatData['shifts'],
              );
            }

            // Ensure all shifts are available in the seat data
            _shiftsData.forEach((shiftId, shiftInfo) {
              if (!processedSeat['shifts'].containsKey(shiftId)) {
                processedSeat['shifts'][shiftId] = {'status': 'available'};
              }
            });

            processedSeats[seatNo] = processedSeat;
          }
        });
      }

      // If no seats found in Firestore, create default seats
      if (processedSeats.isEmpty) {
        print('No seats found in Firestore, creating default seats');

        final int totalSeats = widget.library.totalSeats ?? 50;
        int seatsPerRow = 10;

        for (int i = 0; i < totalSeats; i++) {
          String rowLetter = String.fromCharCode(
            65 + (i ~/ seatsPerRow),
          ); // A, B, C...
          int seatNumber = (i % seatsPerRow) + 1; // 1-10
          String seatId = '$rowLetter$seatNumber';

          Map<String, dynamic> shiftsMap = {};
          _shiftsData.forEach((shiftId, _) {
            shiftsMap[shiftId] = {'status': 'available'};
          });

          processedSeats[seatId] = {'shifts': shiftsMap};
        }
      }

      // Now check for existing bookings for this date
      final bookingsSnapshot =
          await FirebaseFirestore.instance
              .collection("seatBookings")
              .where("libraryId", isEqualTo: widget.library.id)
              .where("bookedAt", isEqualTo: dateFormatted)
              .get();

      print(
        'Found ${bookingsSnapshot.docs.length} bookings for date: $dateFormatted',
      );

      // Update seat status based on bookings
      for (var doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final seatNo = bookingData['seatNo'];
        final shiftId = bookingData['shiftId'];

        if (seatNo != null &&
            shiftId != null &&
            processedSeats.containsKey(seatNo)) {
          // Create shifts map if it doesn't exist
          if (!processedSeats[seatNo].containsKey('shifts')) {
            processedSeats[seatNo]['shifts'] = {};
          }

          // Create shift entry if it doesn't exist
          if (!processedSeats[seatNo]['shifts'].containsKey(shiftId)) {
            processedSeats[seatNo]['shifts'][shiftId] = {};
          }

          // Mark as booked
          processedSeats[seatNo]['shifts'][shiftId]['status'] = 'booked';
        }
      }

      setState(() {
        _seatsData = processedSeats;
        _isLoadingSeats = false;
      });
    } catch (e) {
      print('Error loading seats: $e');
      setState(() {
        _isLoadingSeats = false;
        _seatsData = {};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading seats: ${e.toString()}')),
      );
    }
  }

  // Handle date selection
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedSeat = null;
      _selectedShifts = {};
      _availableShiftsForSelectedSeat = {};
    });
    _loadSeats();
  }

  // Handle seat selection
  void _selectSeat(String seatNo) {
    // Generate available shifts for this seat
    Map<String, bool> availableShifts = {};

    if (_seatsData.containsKey(seatNo) &&
        _seatsData[seatNo].containsKey('shifts')) {
      _shiftsData.forEach((shiftId, shiftData) {
        // Check if this shift is available for the selected seat
        bool isAvailable = true;

        if (_seatsData[seatNo]['shifts'].containsKey(shiftId) &&
            _seatsData[seatNo]['shifts'][shiftId].containsKey('status')) {
          isAvailable =
              _seatsData[seatNo]['shifts'][shiftId]['status'] == 'available';
        }

        availableShifts[shiftId] = isAvailable;
      });
    }

    setState(() {
      _selectedSeat = seatNo;
      _selectedShifts = {};
      _availableShiftsForSelectedSeat = availableShifts;
    });

    // Scroll to shift section
    Future.delayed(Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // Toggle shift selection
  void _toggleShift(String shiftId) {
    if (!_availableShiftsForSelectedSeat.containsKey(shiftId) ||
        !_availableShiftsForSelectedSeat[shiftId]!) {
      // This shift is not available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This shift is not available for the selected seat'),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedShifts.contains(shiftId)) {
        _selectedShifts.remove(shiftId);
      } else {
        _selectedShifts.add(shiftId);
      }
    });
  }

  // Calculate total fee for selected shifts
  int _calculateTotalFee() {
    int total = 0;
    for (final shiftId in _selectedShifts) {
      if (_shiftsData.containsKey(shiftId)) {
        var fee = _shiftsData[shiftId]['shiftFee'] ?? 0;
        if (fee is String) {
          fee = int.tryParse(fee) ?? 0;
        }
        total += fee is int ? fee : 0;
      }
    }
    return total;
  }

  // Navigate to payment screen
  void _navigateToPayment() {
    if (_selectedSeat == null || _selectedShifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one shift')),
      );
      return;
    }

    // Process each selected shift
    List<Map<String, dynamic>> selectedShiftData = [];
    for (final shiftId in _selectedShifts) {
      if (_shiftsData.containsKey(shiftId)) {
        final shiftData = _shiftsData[shiftId];

        // Normalize fee
        dynamic fee = shiftData['shiftFee'];
        if (fee is String) {
          fee = int.tryParse(fee) ?? 0;
        } else if (fee == null) {
          fee = 0;
        }

        final Map<String, dynamic> validatedShiftData =
            Map<String, dynamic>.from(shiftData);
        validatedShiftData['shiftFee'] = fee;
        validatedShiftData['id'] = shiftId;

        selectedShiftData.add(validatedShiftData);
      }
    }

    // Navigate to payment screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MultiShiftPaymentScreen(
              library: widget.library,
              userId: widget.userId,
              selectedDate: _selectedDate,
              selectedSeat: _selectedSeat!,
              selectedShifts: selectedShiftData,
              totalFee: _calculateTotalFee(),
            ),
      ),
    );
  }

  // Format date to string for database
  String _formatDateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Format date for display
  String _formatDateForDisplay(DateTime date) {
    List<String> weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekday = weekdays[date.weekday - 1]; // weekday is 1-7
    final month = months[date.month - 1]; // month is 1-12

    return '$weekday, $month ${date.day}, ${date.year}';
  }

  // Get month name from month number
  String _getMonthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return monthNames[month - 1]; // month is 1-12, array is 0-11
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Book a Seat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === SECTION 1: DATE SELECTION ===
              Text(
                'Step 1: Select Date',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),

              _buildDateSelection(),
              SizedBox(height: 30),

              // === SECTION 2: SEAT SELECTION ===
              Text(
                'Step 2: Select Seat',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Date: ${_formatDateForDisplay(_selectedDate)}',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              SizedBox(height: 16),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(Colors.green, 'Available'),
                  SizedBox(width: 20),
                  _buildLegendItem(Colors.red, 'Booked'),
                  SizedBox(width: 20),
                  _buildLegendItem(Colors.blue, 'Selected'),
                ],
              ),
              SizedBox(height: 24),

              // Screen indicator
              Center(
                child: Container(
                  width: 120,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  'SCREEN',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Seats grid
              _isLoadingSeats
                  ? Center(
                    child: Container(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      ),
                    ),
                  )
                  : _seatsData.isEmpty
                  ? Center(
                    child: Container(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No seats available for this date',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  )
                  : _buildSeatsGrid(),
              SizedBox(height: 30),

              // === SECTION 3: SHIFT SELECTION ===
              Text(
                'Step 3: Select Shifts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'You can select multiple shifts',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              SizedBox(height: 16),

              _selectedSeat == null
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        'Select a seat to view available shifts',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ),
                  )
                  : _shiftsData.isEmpty
                  ? Center(
                    child: Text(
                      "No shifts available",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : _buildShiftSelectionForSeat(),

              SizedBox(height: 20),

              // Show continue button if shifts are selected
              if (_selectedSeat != null && _selectedShifts.isNotEmpty)
                _buildContinueButton(),

              SizedBox(height: 30),

              // Help text at bottom
              if (_selectedSeat != null &&
                  !_isLoadingSeats &&
                  _selectedShifts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Select one or more available shifts',
                      style: TextStyle(color: Colors.amber, fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Continue button to proceed to payment
  Widget _buildContinueButton() {
    final totalFee = _calculateTotalFee();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_selectedShifts.length} shift${_selectedShifts.length > 1 ? 's' : ''} selected",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Total fee: ₹$totalFee",
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _navigateToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Date selection widget
  Widget _buildDateSelection() {
    final today = _currentUtcTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendar header (Month, Year)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Days of the week header
        Container(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        SizedBox(height: 8),

        // Calendar grid as horizontal scrolling dates
        Container(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableDates.length,
            itemBuilder: (context, index) {
              final date = _availableDates[index];
              final isPast = date.isBefore(
                DateTime(today.year, today.month, today.day),
              );
              final isToday =
                  date.day == today.day &&
                  date.month == today.month &&
                  date.year == today.year;
              final isSelected =
                  date.day == _selectedDate.day &&
                  date.month == _selectedDate.month &&
                  date.year == _selectedDate.year;

              return GestureDetector(
                onTap: !isPast ? () => _selectDate(date) : null,
                child: Container(
                  width: 60,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Colors.amber
                            : isToday
                            ? Colors.amber.withOpacity(0.2)
                            : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border:
                        isToday && !isSelected
                            ? Border.all(color: Colors.amber)
                            : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ][date.weekday - 1],
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.black : Colors.grey[400],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              isPast
                                  ? Colors.grey[700]
                                  : isSelected
                                  ? Colors.black
                                  : Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                          'Jul',
                          'Aug',
                          'Sep',
                          'Oct',
                          'Nov',
                          'Dec',
                        ][date.month - 1],
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.black : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Shift selection widget - Updated for multiple selection
  Widget _buildShiftSelectionForSeat() {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: _shiftsData.length,
        itemBuilder: (context, index) {
          final shiftId = _shiftsData.keys.elementAt(index);
          final shift = _shiftsData[shiftId];
          final isSelected = _selectedShifts.contains(shiftId);

          // Check if this shift is available for the selected seat
          final isAvailable = _availableShiftsForSelectedSeat[shiftId] ?? false;

          // Normalize fee
          var fee = shift['shiftFee'] ?? 0;
          if (fee is String) {
            fee = int.tryParse(fee) ?? 0;
          }

          // Get a color for the shift
          Color shiftColor;
          switch (index % 3) {
            case 0:
              shiftColor = Colors.blue;
              break;
            case 1:
              shiftColor = Colors.amber;
              break;
            default:
              shiftColor = Colors.deepPurple;
              break;
          }

          return Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.7,
                margin: EdgeInsets.only(right: 16, top: 8),
                decoration: BoxDecoration(
                  gradient:
                      isSelected
                          ? LinearGradient(
                            colors: [
                              shiftColor.withOpacity(0.3),
                              shiftColor.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  border: Border.all(
                    color:
                        isSelected
                            ? shiftColor
                            : isAvailable
                            ? Colors.grey.shade700
                            : Colors.grey.shade900,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color:
                      isAvailable
                          ? null
                          : Colors.grey.shade900.withOpacity(0.5),
                ),
                child: Opacity(
                  opacity: isAvailable ? 1.0 : 0.5,
                  child: InkWell(
                    onTap: isAvailable ? () => _toggleShift(shiftId) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isAvailable
                                        ? Icons.access_time
                                        : Icons.block,
                                    color:
                                        isSelected
                                            ? shiftColor
                                            : isAvailable
                                            ? Colors.grey
                                            : Colors.red.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    shift['shiftName'] ?? 'Unnamed Shift',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : isAvailable
                                              ? Colors.grey[300]
                                              : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: shiftColor.withOpacity(
                                    isAvailable ? 0.2 : 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "₹$fee",
                                  style: TextStyle(
                                    color:
                                        isAvailable ? shiftColor : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${shift['shiftStartTime'] ?? '00:00'} - ${shift['shiftEndTime'] ?? '00:00'}",
                                  style: TextStyle(
                                    color:
                                        isAvailable
                                            ? Colors.white
                                            : Colors.grey[500],
                                  ),
                                ),
                                if (!isAvailable) ...[
                                  SizedBox(width: 8),
                                  Text(
                                    "Booked",
                                    style: TextStyle(
                                      color: Colors.red.withOpacity(0.7),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Selection indicator with checkbox
              if (isAvailable)
                Positioned(
                  top: 0,
                  right: 26,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? shiftColor
                              : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child:
                        isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Seats grid
  Widget _buildSeatsGrid() {
    // Sort seats by row and number
    List<MapEntry<String, dynamic>> sortedSeats = _seatsData.entries.toList();
    sortedSeats.sort((a, b) {
      // Extract row letters
      String rowA = a.key.replaceAll(RegExp(r'[0-9]'), '');
      String rowB = b.key.replaceAll(RegExp(r'[0-9]'), '');

      // Extract seat numbers
      int numA = int.tryParse(a.key.replaceAll(RegExp(r'[A-Za-z]'), '')) ?? 0;
      int numB = int.tryParse(b.key.replaceAll(RegExp(r'[A-Za-z]'), '')) ?? 0;

      // First compare by row
      int rowCompare = rowA.compareTo(rowB);
      if (rowCompare != 0) return rowCompare;

      // Then compare by number
      return numA.compareTo(numB);
    });

    // Organize seats by row
    Map<String, List<MapEntry<String, dynamic>>> seatsByRow = {};

    for (var entry in sortedSeats) {
      String seatNo = entry.key;
      String row = seatNo.replaceAll(RegExp(r'[0-9]'), '');

      if (!seatsByRow.containsKey(row)) {
        seatsByRow[row] = [];
      }

      seatsByRow[row]!.add(entry);
    }

    // Build rows with scrollable sub-rows
    List<Widget> rows = [];

    seatsByRow.forEach((row, seats) {
      // If row has more than 10 seats, split into multiple rows
      if (seats.length <= 10) {
        // Single row layout
        rows.add(_buildSeatRowWithScroll(row, seats));
      } else {
        // Split into multiple sub-rows
        int chunksCount = (seats.length / 10).ceil();
        for (int i = 0; i < chunksCount; i++) {
          int startIdx = i * 10;
          int endIdx = math.min(startIdx + 10, seats.length);

          List<MapEntry<String, dynamic>> subRow = seats.sublist(
            startIdx,
            endIdx,
          );
          rows.add(
            _buildSeatRowWithScroll(
              i == 0 ? row : '', // Only show row label for first row
              subRow,
              isSubRow: i > 0,
              rowIndicator: i > 0 ? "${row}${i + 1}" : null,
            ),
          );
        }
      }
    });

    return Container(
      constraints: BoxConstraints(minHeight: 200, maxHeight: 400),
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(children: rows),
      ),
    );
  }

  // Helper to build a scrollable row of seats with partial booking support
  Widget _buildSeatRowWithScroll(
    String row,
    List<MapEntry<String, dynamic>> seats, {
    bool isSubRow = false,
    String? rowIndicator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Row label
          Container(
            width: 40,
            child: Text(
              isSubRow ? (rowIndicator ?? '↳') : row,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Seats in this row
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: Row(
                children:
                    seats.map((entry) {
                      String seatNo = entry.key;
                      Map<String, dynamic> seatData = entry.value;

                      // Check shift status for this seat
                      int availableShifts = 0;
                      int bookedShifts = 0;

                      if (seatData.containsKey('shifts')) {
                        _shiftsData.keys.forEach((shiftId) {
                          if (seatData['shifts'].containsKey(shiftId)) {
                            if (seatData['shifts'][shiftId]['status'] ==
                                'available') {
                              availableShifts++;
                            } else if (seatData['shifts'][shiftId]['status'] ==
                                'booked') {
                              bookedShifts++;
                            }
                          } else {
                            // If shift is not explicitly listed, consider it available
                            availableShifts++;
                          }
                        });
                      }

                      // Determine seat status
                      bool isSelected = _selectedSeat == seatNo;
                      bool isPartiallyBooked =
                          bookedShifts > 0 && availableShifts > 0;
                      bool isFullyBooked = availableShifts == 0;

                      // Get color based on seat status
                      Color seatColor;
                      if (isSelected) {
                        seatColor = Colors.blue;
                      } else if (isPartiallyBooked) {
                        // New color for partially booked seats
                        seatColor = Colors.amber;
                      } else if (isFullyBooked) {
                        seatColor = Colors.red;
                      } else {
                        seatColor = Colors.green;
                      }

                      // Extract seat number (digits only)
                      String displayNumber = seatNo.replaceAll(
                        RegExp(r'[A-Za-z]'),
                        '',
                      );

                      return Container(
                        width: 40,
                        height: 40,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: seatColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap:
                              !isFullyBooked ? () => _selectSeat(seatNo) : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Center(
                            child: Text(
                              displayNumber, // Show only the number
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Legend section with partially booked status added
  Row _buildUpdatedLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.green, 'Available'),
        SizedBox(width: 12),
        _buildLegendItem(Colors.amber, 'Partially Booked'),
        SizedBox(width: 12),
        _buildLegendItem(Colors.red, 'Fully Booked'),
        SizedBox(width: 12),
        _buildLegendItem(Colors.blue, 'Selected'),
      ],
    );
  }

  // Legend item
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      ],
    );
  }
}

// Payment Screen for multiple shifts
class MultiShiftPaymentScreen extends StatefulWidget {
  final LibraryModel library;
  final String userId;
  final DateTime selectedDate;
  final String selectedSeat;
  final List<Map<String, dynamic>> selectedShifts;
  final int totalFee;

  const MultiShiftPaymentScreen({
    Key? key,
    required this.library,
    required this.userId,
    required this.selectedDate,
    required this.selectedSeat,
    required this.selectedShifts,
    required this.totalFee,
  }) : super(key: key);

  @override
  _MultiShiftPaymentScreenState createState() =>
      _MultiShiftPaymentScreenState();
}

class _MultiShiftPaymentScreenState extends State<MultiShiftPaymentScreen> {
  String _paymentMethod = ''; // wallet, card, cash
  bool _isProcessing = false;

  // Format date to string for database
  String _formatDateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Format date for display
  String _formatDateForDisplay(DateTime date) {
    List<String> weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];

    return '$weekday, $month ${date.day}, ${date.year}';
  }

  // Handle payment method selection
  void _selectPaymentMethod(String method) {
    setState(() {
      _paymentMethod = method;
    });
  }

  // Determine payment method for database
  String _getPaymentMethodForDB() {
    switch (_paymentMethod) {
      case 'wallet':
      case 'card':
        return 'online';
      case 'cash':
        return 'pay to owner';
      default:
        return 'online';
    }
  }

  // Calculate expiry date (30 days from now)
  String calculateDueDate() {
    // Get current date
    final now = DateTime.now();

    // Add 30 days to get the due date
    final dueDate = now.add(Duration(days: 30));

    // Format the date as YYYY-MM-DD
    String formattedDueDate =
        "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";

    return formattedDueDate;
  }

  // Process bookings for all selected shifts
  Future<void> _processBookings() async {
    setState(() {
      _isProcessing = true;
    });

    // Validate payment method before proceeding
    if (_paymentMethod.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a payment method')));
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    try {
      final timestamp = Timestamp.now();

      // Get payment status based on selected method
      String paymentStatus;
      String? paymentId;
      String paymentMethod = _getPaymentMethodForDB();

      switch (_paymentMethod) {
        case 'wallet':
          paymentStatus = 'paid';
          paymentId = 'wallet_${DateTime.now().millisecondsSinceEpoch}';
          break;
        case 'card':
          paymentStatus = 'paid';
          paymentId = 'card_${DateTime.now().millisecondsSinceEpoch}';
          break;
        case 'cash':
          paymentStatus = 'pending';
          break;
        default:
          paymentStatus = 'pending';
      }

      // First check if seats are still available for all shifts
      final libraryRef = FirebaseFirestore.instance
          .collection("libraries")
          .doc(widget.library.id);

      final librarySnapshot = await libraryRef.get();

      if (librarySnapshot.exists) {
        final seatsData =
        librarySnapshot.data()?['seats'] as Map<String, dynamic>?;

        if (seatsData != null && seatsData[widget.selectedSeat] != null) {
          for (final shiftData in widget.selectedShifts) {
            final shiftId = shiftData['id'];

            if (seatsData[widget.selectedSeat]['shifts'] != null &&
                seatsData[widget.selectedSeat]['shifts'][shiftId] != null &&
                seatsData[widget.selectedSeat]['shifts'][shiftId]['status'] ==
                    'booked') {
              setState(() {
                _isProcessing = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Sorry, the ${shiftData['name']} shift was just booked by someone else',
                  ),
                ),
              );
              return;
            }
          }
        }
      }

      // Start a batch write for all bookings
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // Create a single booking document in Firestore
      final bookingRef =
      FirebaseFirestore.instance.collection('seatBookings').doc();
      final bookingId = bookingRef.id;

      // Create a list of shift details to store in the single booking
      List<Map<String, dynamic>> shiftDetails = [];
      int totalFee = 0;

      // Process shift data for booking
      // Here we need to determine if we're dealing with single or multiple shifts
      if (widget.selectedShifts.length == 1) {
        // Single shift - use direct data
        final shiftData = widget.selectedShifts[0];
        final shiftId = shiftData['id'];
        final shiftName = shiftData['shiftName'];
        final shiftStartTime = shiftData['shiftStartTime'];
        final shiftEndTime = shiftData['shiftEndTime'];

        // Normalize the fee value to ensure it's an integer
        int fee = 0;
        var rawFee = shiftData['shiftFee'];
        if (rawFee is int) {
          fee = rawFee;
        } else if (rawFee is String) {
          fee = int.tryParse(rawFee) ?? 0;
        } else if (rawFee is double) {
          fee = rawFee.toInt();
        }

        totalFee = fee;

        shiftDetails.add({
          'shiftName': shiftName,
          'shiftStartTime': shiftStartTime,
          'shiftEndTime': shiftEndTime,
          'shiftFee': fee,
        });

        // Update the seat status in the library document
        Map<String, dynamic> updateData = {};
        updateData['seats.${widget.selectedSeat}.shifts.${shiftId}.status'] =
        'booked';
        updateData['seats.${widget.selectedSeat}.shifts.${shiftId}.bookedBy'] =
            widget.userId;
        updateData['seats.${widget.selectedSeat}.shifts.${shiftId}.bookingId'] =
            bookingId;
        updateData['seats.${widget.selectedSeat}.shifts.${shiftId}.bookedAt'] =
            timestamp;

        batch.update(libraryRef, updateData);
      } else {
        // Multiple shifts - we need to merge them
        String combinedShiftName = "";
        String earliestStartTime = "23:59";
        String latestEndTime = "00:00";
        int combinedFee = 0;
        List<String> shiftIds = [];

        // First collect all shift data
        for (final shiftData in widget.selectedShifts) {
          final shiftId = shiftData['id'];
          final shiftName = shiftData['shiftName'];
          final startTime = shiftData['shiftStartTime'];
          final endTime = shiftData['shiftEndTime'];

          // Build combined shift name
          if (combinedShiftName.isEmpty) {
            combinedShiftName = shiftName;
          } else {
            combinedShiftName += "$shiftName";
          }

          // Track shift IDs
          shiftIds.add(shiftId);

          // Find earliest start time
          if (_compareTimeStrings(startTime, earliestStartTime) < 0) {
            earliestStartTime = startTime;
          }

          // Find latest end time
          if (_compareTimeStrings(endTime, latestEndTime) > 0) {
            latestEndTime = endTime;
          }

          // Sum up fees
          int fee = 0;
          var rawFee = shiftData['shiftFee'];
          if (rawFee is int) {
            fee = rawFee;
          } else if (rawFee is String) {
            fee = int.tryParse(rawFee) ?? 0;
          } else if (rawFee is double) {
            fee = rawFee.toInt();
          }
          combinedFee += fee;

        }

        totalFee = combinedFee;

        // Store the combined shift details
        shiftDetails.add({
          'shiftName': combinedShiftName,
          'shiftStartTime': earliestStartTime,
          'shiftEndTime': latestEndTime,
          'shiftFee': combinedFee,
          'shiftIds': shiftIds, // Store all included shift IDs
        });
      }

      // Create a single booking document with proper shift data
      final bookingData = {
        'libraryId': widget.library.id,
        'studentId': widget.userId,
        'studentName': SmartLib.studentName,
        'seatNo': widget.selectedSeat,

        // Use the merged shift data for combined shifts or the single shift data
        'shiftStartTime': shiftDetails[0]['shiftStartTime'],
        'shiftEndTime': shiftDetails[0]['shiftEndTime'],
        'shiftName': shiftDetails[0]['shiftName'],
        'shiftFee': shiftDetails[0]['shiftFee'],

        // For multiple shifts, store the shift IDs
        if (widget.selectedShifts.length > 1 &&
            shiftDetails[0].containsKey('shiftIds'))
          'shiftIds': shiftDetails[0]['shiftIds'],
        // For a single shift, store the shift ID
        if (widget.selectedShifts.length == 1)
          'shiftId': widget.selectedShifts[0]['id'],

        'totalFee': totalFee,
        'status': 'pending',
        'bookedAt':
        '${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
        'dueDate': calculateDueDate(),
        'paymentStatus': paymentStatus,
        'paymentMethod': paymentMethod,
        'paymentId': paymentId,
        'shiftCount': widget.selectedShifts.length,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };

      // Add booking to Firestore
      batch.set(bookingRef, bookingData);

      // Add user to joined libraries if not already joined
      await FirebaseDatabase.instance
          .ref()
          .child(
        "users/students/${widget.userId}/joinedLibraries/${widget.library.id}",
      )
          .set({
        'joinedAt': DateTime.now().toIso8601String(),
      });

      // ===== ADD STUDENT TO SUBSCRIBERS COLLECTION =====
      // Get current date in YYYY-MM-DD format
      final currentDate = DateTime.now();
      final formattedDate = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

      // Reference to the library subscribers collection
      final subscribersRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.library.id)
          .collection('subscribers')
          .doc(widget.userId);

      // Add the student to subscribers with subscription data
      batch.set(subscribersRef, {
        'email': SmartLib.email,
        'phone': SmartLib.phone,
        'dueDate': calculateDueDate(),
        'studentId': widget.userId,
        'studentName': SmartLib.studentName,
        'subscriptionDate': formattedDate,
        'lastBookingId': bookingId,
        'subscriptionStatus': 'pending',
        'shiftStartTime': shiftDetails[0]['shiftStartTime'],
        'shiftEndTime': shiftDetails[0]['shiftEndTime'],
        'shiftName': shiftDetails[0]['shiftName'],
        'shiftFee': shiftDetails[0]['shiftFee'],
        'joinedAt': timestamp,
      }, SetOptions(merge: true)); // Use merge option to avoid overwriting existing data
      // ===== END OF SUBSCRIBERS ADDITION =====

      // Update student count in library if this is a new student
      final libraryDocRef = FirebaseFirestore.instance
          .collection("libraries")
          .doc(widget.library.id);
      batch.update(libraryDocRef, {'students': FieldValue.increment(1),'availableSeats': FieldValue.increment(-1)});


      // Execute the batch
      await batch.commit();

      // Update user's realtime database status
      await FirebaseDatabase.instance
          .ref()
          .child("users/students/${widget.userId}/seatBookings/${bookingId}")
          .set(true);

      // Update current status with merged shift data
      await FirebaseDatabase.instance
          .ref()
          .child("users/students/${widget.userId}/currentStatus")
          .set({
        "currentLibraryId": widget.library.id,
        "currentSeatNo": widget.selectedSeat,
        "shiftStartTime": shiftDetails[0]['shiftStartTime'],
        "shiftEndTime": shiftDetails[0]['shiftEndTime'],
        "shiftName": shiftDetails[0]['shiftName'],
        "libraryName": widget.library.libraryName,
        if (widget.selectedShifts.length == 1)
          "shiftId": widget.selectedShifts[0]['id'],
        if (widget.selectedShifts.length > 1 &&
            shiftDetails[0].containsKey('shiftIds'))
          "shiftIds": shiftDetails[0]['shiftIds'],
        "dueDate": calculateDueDate(),
        "totalFee": totalFee,
        "paymentStatus": paymentStatus,
        "currentStatus": "joined",
        "shiftCount": widget.selectedShifts.length,
        "isMultipleShifts": widget.selectedShifts.length > 1,
        "bookingId": bookingId, // Add the booking ID to current status
      });

      // Show success screen with the single bookingId
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => MultiBookingConfirmationScreen(
            library: widget.library,
            bookingIds: [bookingId], // Passing a list with a single ID
            seatNo: widget.selectedSeat,
            selectedShifts: widget.selectedShifts,
            date: widget.selectedDate,
            paymentStatus: paymentStatus,
            paymentMethod: paymentMethod,
            totalFee: totalFee, // Use our calculated totalFee
          ),
        ),
      ).then((_) {
        // Return to library screen with success result
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    } catch (e) {
      print('Error processing bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing bookings: ${e.toString()}')),
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Helper method to compare time strings (e.g. "08:00" vs "12:00")
  int _compareTimeStrings(String time1, String time2) {
    // Convert to 24-hour format if needed and extract hours and minutes
    int getHours(String time) {
      if (time.toLowerCase().contains('am') ||
          time.toLowerCase().contains('pm')) {
        // Handle 12-hour format
        final parts = time.toLowerCase().split(':');
        int hour = int.tryParse(parts[0]) ?? 0;
        bool isPm = time.toLowerCase().contains('pm');

        // Convert to 24-hour
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;

        return hour;
      } else {
        // Already in 24-hour format
        final parts = time.split(':');
        return int.tryParse(parts[0]) ?? 0;
      }
    }

    int getMinutes(String time) {
      if (time.toLowerCase().contains('am') ||
          time.toLowerCase().contains('pm')) {
        // Handle 12-hour format with am/pm
        final parts = time.toLowerCase().split(':');
        if (parts.length < 2) return 0;

        final minutesPart = parts[1].replaceAll(RegExp(r'[^\d]'), '');
        return int.tryParse(minutesPart) ?? 0;
      } else {
        // 24-hour format
        final parts = time.split(':');
        if (parts.length < 2) return 0;
        return int.tryParse(parts[1]) ?? 0;
      }
    }

    final hours1 = getHours(time1);
    final hours2 = getHours(time2);

    if (hours1 != hours2) {
      return hours1 - hours2;
    }

    final minutes1 = getMinutes(time1);
    final minutes2 = getMinutes(time2);

    return minutes1 - minutes2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Payment',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking Summary',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              // Booking summary card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Library info
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.amber, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.library.libraryName ?? 'Unknown Library',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Date and seat info
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Date",
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatDateForDisplay(widget.selectedDate),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Seat",
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.selectedSeat,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),
                    Text(
                      "Selected Shifts",
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    SizedBox(height: 8),

                    // Shifts list
                    Column(
                      children:
                          widget.selectedShifts.map((shift) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 10),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shift['shiftName'] ?? 'Unknown Shift',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "${shift['shiftStartTime'] ?? '00:00'} - ${shift['shiftEndTime'] ?? '00:00'}",
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "₹${shift['shiftFee'] ?? 0}",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),

                    Divider(color: Colors.grey[800]),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "₹${widget.totalFee}",
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),

              // Payment options
              /*_buildPaymentOption(
                'wallet',
                'Pay with Wallet',
                'Balance: ₹500',
                Icons.account_balance_wallet,
              ),

              _buildPaymentOption(
                'card',
                'Pay with Card',
                'Credit/Debit Card',
                Icons.credit_card,
              ),*/
              _buildPaymentOption(
                'cash',
                'Pay Later',
                'Pay to Library Owner',
                Icons.money,
              ),

              SizedBox(height: 30),

              // User information
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      radius: 20,
                      child: Text(
                        '${SmartLib.studentName.substring(0, 1).toUpperCase()}',
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student ID: ${widget.userId.substring(0, math.min(6, widget.userId.length))}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Student Name: ${SmartLib.studentName}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // Process booking button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processBookings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.grey[700],
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isProcessing
                          ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Confirm & Pay',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Payment option widget
  Widget _buildPaymentOption(
    String method,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _paymentMethod == method;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.amber : Colors.grey[800]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectPaymentMethod(method),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.amber : Colors.grey[400],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.amber : Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              Radio(
                value: method,
                groupValue: _paymentMethod,
                onChanged: (value) => _selectPaymentMethod(value.toString()),
                activeColor: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Confirmation screen for multiple bookings
class MultiBookingConfirmationScreen extends StatelessWidget {
  final LibraryModel library;
  final List<String> bookingIds;
  final String seatNo;
  final List<Map<String, dynamic>> selectedShifts;
  final DateTime date;
  final String paymentStatus;
  final String paymentMethod;
  final int totalFee;

  const MultiBookingConfirmationScreen({
    Key? key,
    required this.library,
    required this.bookingIds,
    required this.seatNo,
    required this.selectedShifts,
    required this.date,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.totalFee,
  }) : super(key: key);

  // Format date for display
  String _formatDateForDisplay(DateTime date) {
    List<String> weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];

    return '$weekday, $month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 16),

                    // Success icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 60,
                      ),
                    ),
                    SizedBox(height: 24),

                    // Success title
                    Text(
                      'Bookings Confirmed!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),

                    Text(
                      'Your seat has been reserved for ${bookingIds.length} shifts.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),

                    // Booking details card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Library name
                          Text(
                            library.libraryName ?? 'Library',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16),

                          // Booking IDs summary
                          Row(
                            children: [
                              Text(
                                'Bookings: ',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${bookingIds.length} shifts booked',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: () {
                                  // Copy booking IDs to clipboard
                                  final textToCopy = bookingIds.join(', ');
                                  Clipboard.setData(
                                    ClipboardData(text: textToCopy),
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Booking IDs copied to clipboard',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.copy,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Details
                          _buildDetailRow(
                            'Date',
                            _formatDateForDisplay(date),
                            Icons.calendar_today,
                            Colors.white,
                          ),

                          _buildDetailRow(
                            'Seat',
                            seatNo,
                            Icons.event_seat,
                            Colors.white,
                          ),

                          _buildDetailRow(
                            'Payment Status',
                            _formatPaymentStatus(paymentStatus),
                            Icons.payment,
                            _paymentStatusColor(paymentStatus),
                          ),

                          _buildDetailRow(
                            'Payment Method',
                            _formatPaymentMethod(paymentMethod),
                            Icons.credit_card,
                            Colors.white,
                          ),

                          _buildDetailRow(
                            'Total Fee',
                            '₹$totalFee',
                            Icons.attach_money,
                            Colors.amber,
                          ),

                          Divider(color: Colors.grey[800], height: 30),

                          // Shifts list
                          Text(
                            "Booked Shifts",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),

                          // List of booked shifts
                          Column(
                            children:
                                selectedShifts.map((shift) {
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 10),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[850],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey[700]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Shift icon
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.access_time,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 12),

                                        // Shift details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                shift['shiftName'] ??
                                                    'Unknown Shift',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                "${shift['shiftStartTime'] ?? '00:00'} - ${shift['shiftEndTime'] ?? '00:00'}",
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Fee badge
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            "₹${shift['shiftFee'] ?? 0}",
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Back to home button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Return to library screen with success result
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => MainTabScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back to Library',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Detail row helper widget
  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.amber, size: 18),
          ),
          SizedBox(width: 16),

          // Label and value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format payment status for display
  String _formatPaymentStatus(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pay at Library';
      case 'free':
        return 'Free';
      default:
        return status.isEmpty
            ? 'Unknown'
            : status.substring(0, 1).toUpperCase() + status.substring(1);
    }
  }

  // Format payment method for display
  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'online':
        return 'Online Payment';
      case 'pay to owner':
        return 'Pay at Library';
      case 'wallet':
        return 'Wallet';
      case 'card':
        return 'Credit/Debit Card';
      case 'cash':
        return 'Cash';
      default:
        return method.isEmpty
            ? 'Unknown'
            : method.substring(0, 1).toUpperCase() + method.substring(1);
    }
  }

  // Get color for payment status
  Color _paymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'free':
        return Colors.green;
      default:
        return Colors.white;
    }
  }
}
