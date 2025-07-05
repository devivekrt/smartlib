import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/models/library_model.dart';
import 'dart:math' show min;
import 'package:intl/intl.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/function/listen_data.dart';
import 'package:smartlib/theme/theme.dart';

class LibrarianSeatsPage extends StatefulWidget {
  const LibrarianSeatsPage({Key? key}) : super(key: key);

  @override
  _LibrarianSeatsPageState createState() => _LibrarianSeatsPageState();
}

class _LibrarianSeatsPageState extends State<LibrarianSeatsPage> {
  // Firebase reference
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ListenData _listenData = ListenData();

  // State variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedShift;
  bool _isLoading = true;
  bool _isLoadingSeats = true;

  // Data variables
  Map<String, Map<String, dynamic>> _seats = {};
  List<Map<String, dynamic>> _todayBookings = [];
  List<String> _shifts = [];
  Map<String, dynamic> _libraryData = {};
  LibraryModel? _libraryModel;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load all required data
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load library data
      await _loadLibraryData();

      // Load shifts
      await _loadShifts();

      // Load seats
      await _loadSeats();

      // Load today's bookings
      await _loadBookings();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() {
        _isLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data. Please try again.'))
      );
    }
  }

  // Load library data
  Future<void> _loadLibraryData() async {
    try {
      // Get library data using libraryId from SmartLib
      final libraryDoc = await _firestore
          .collection('libraries')
          .doc(SmartLib.libraryId)
          .get();

      if (!libraryDoc.exists) {
        throw Exception("Library not found");
      }

      _libraryData = libraryDoc.data() ?? {};
      _libraryData['id'] = libraryDoc.id;

      // Create LibraryModel from data
      _libraryModel = LibraryModel.fromMap(_libraryData);

    } catch (e) {
      print("Error loading library data: $e");
      throw e;
    }
  }

  // Load shifts
  Future<void> _loadShifts() async {
    try {
      if (_libraryModel?.shifts != null) {
        final shiftsMap = _libraryModel!.shifts;
        _shifts = shiftsMap.keys.toList();

        // Set default selected shift if none is selected
        if (_selectedShift == null && _shifts.isNotEmpty) {
          _selectedShift = _shifts[0];
        }
      } else if (_libraryData.containsKey('shifts')) {
        final shiftsMap = _libraryData['shifts'] as Map<String, dynamic>;
        _shifts = shiftsMap.keys.toList();

        // Set default selected shift if none is selected
        if (_selectedShift == null && _shifts.isNotEmpty) {
          _selectedShift = _shifts[0];
        }
      } else {
        // Use default shifts if none are configured
        _shifts = ['morning', 'afternoon', 'evening', 'night', 'full_day'];

        // Set default selected shift if none is selected
        if (_selectedShift == null) {
          _selectedShift = 'morning';
        }
      }
    } catch (e) {
      print("Error loading shifts: $e");
      // Use default shifts as fallback
      _shifts = ['morning', 'afternoon', 'evening', 'night', 'full_day'];
      if (_selectedShift == null) {
        _selectedShift = 'morning';
      }
    }
  }

  // Load seats
  Future<void> _loadSeats() async {
    setState(() {
      _isLoadingSeats = true;
    });

    try {
      // Check if seats are in library data
      if (_libraryData.containsKey('seats') && _libraryData['seats'] is Map) {
        _seats = Map<String, Map<String, dynamic>>.from(_libraryData['seats']);
      } else {
        // If no seats found, try to generate them
        final totalSeats = int.tryParse(_libraryData['totalSeats']?.toString() ?? '0') ?? 0;
        if (totalSeats > 0) {
          // Get shifts for seat generation
          Map<String, dynamic> shiftsMap = {};
          if (_libraryModel?.shifts != null) {
            shiftsMap = _libraryModel!.shifts;
          } else if (_libraryData.containsKey('shifts')) {
            shiftsMap = Map<String, dynamic>.from(_libraryData['shifts'] as Map);
          }


          // Reload library data to get the generated seats
          await _loadLibraryData();

          if (_libraryData.containsKey('seats') && _libraryData['seats'] is Map) {
            _seats = Map<String, Map<String, dynamic>>.from(_libraryData['seats']);
          }
        }
      }
    } catch (e) {
      print("Error loading seats: $e");
    } finally {
      setState(() {
        _isLoadingSeats = false;
      });
    }
  }

  // Load bookings
  Future<void> _loadBookings() async {
    try {
      final formattedDate = DateFormat('dd-MM-yyyy').format(_selectedDate);

      final bookingsSnapshot = await _firestore
          .collection('seatBookings')
          .where('libraryId', isEqualTo: SmartLib.libraryId)
          .where('bookedAt', isEqualTo: formattedDate)
          .get();

      List<Map<String, dynamic>> bookings = [];

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        data['bookingId'] = doc.id;
        bookings.add(data);
      }

      setState(() {
        _todayBookings = bookings;
      });
    } catch (e) {
      print("Error loading bookings: $e");
      // If there's an error, use an empty list
      setState(() {
        _todayBookings = [];
      });
    }
  }



  // Handle date change
  void _onDateChange(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadBookings();
  }

  // Handle shift change
  void _onShiftChange(String shiftId) {
    setState(() {
      _selectedShift = shiftId;
    });
  }

  // Get shift name from shift ID
  String _getShiftName(String shiftId) {
    // First check if we have a library model with shift data
    if (_libraryModel?.shifts != null && _libraryModel!.shifts.containsKey(shiftId)) {
      return _libraryModel!.shifts[shiftId]!['shiftName'] ?? shiftId;
    }

    // If not, check the library data directly
    if (_libraryData.containsKey('shifts')) {
      final shiftsMap = _libraryData['shifts'] as Map<dynamic, dynamic>;
      if (shiftsMap.containsKey(shiftId)) {
        return shiftsMap[shiftId]['shiftName'] ?? shiftId;
      }
    }

    // Default transformation: capitalize and replace underscores with spaces
    return shiftId
        .split('_')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Filter bookings for today and selected shift
    final bookingsForToday = _todayBookings
        .where((b) => b['bookedAt'] == DateFormat('dd-MM-yyyy').format(_selectedDate))
        .toList();

    // Create a properly typed list for bookingsForShift
    List<Map<String, dynamic>> typedBookingsForShift = [];

    // Only populate if we have a selected shift
    if (_selectedShift != null) {
      for (final booking in bookingsForToday) {
        if (booking['shiftId'] == _selectedShift) {
          // Ensure each booking is properly typed as Map<String, dynamic>
          typedBookingsForShift.add(Map<String, dynamic>.from(booking));
        }
      }
    }

    // Create shift data structure
    Map<String, Map<String, dynamic>> shiftsData = {};
    if (_libraryModel?.shifts != null) {
      shiftsData = Map<String, Map<String, dynamic>>.from(_libraryModel!.shifts);
    } else if (_libraryData.containsKey('shifts')) {
      shiftsData = Map<String, Map<String, dynamic>>.from(_libraryData['shifts'] as Map);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Enhanced date selection component with responsive sizing
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            margin: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 4 : 8,
            ),
            decoration: BoxDecoration(
              color: DarkColor.cardColor,
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
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                // Responsive date selection
                SizedBox(
                  height: isSmallScreen ? 80 : 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 30, // Show one week of dates
                    itemBuilder: (context, index) {
                      // Generate dates from today to 30days forward
                      final date = DateTime.now().add(Duration(days: index));

                      final isToday = _isSameDay(date, DateTime.now());
                      final isSelected = _isSameDay(date, _selectedDate);

                      return GestureDetector(
                        onTap: () => _onDateChange(date),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 4 : 6,
                          ),
                          width: isSmallScreen ? 55 : 65,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                              colors: [
                                DarkColor.highlightColor,
                                DarkColor.highlightColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                                : null,
                            color: isSelected
                                ? null
                                : isToday
                                ? DarkColor.highlightColor.withOpacity(0.1)
                                : DarkColor.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday && !isSelected
                                ? Border.all(color: DarkColor.highlightColor)
                                : Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: DarkColor.highlightColor.withOpacity(0.3),
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
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[400],
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 4 : 6),

                              // Day number
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : isToday
                                      ? DarkColor.highlightColor
                                      : Colors.white,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 2 : 4),

                              // Month name (short)
                              Text(
                                _getMonthName(date.month),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[400],
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
            ),
          ),

          // Improved shift selection with better responsive UI
          Card(
            margin: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 4 : 6,
            ),
            color: DarkColor.cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Shift:',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _shifts.map((shiftId) {
                        final isSelected = _selectedShift == shiftId;

                        // Determine shift color based on index
                        Color shiftColor;
                        int index = _shifts.indexOf(shiftId);
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

                        // Get shift details from data structures
                        Map<String, dynamic>? shiftDetails;

                        if (shiftsData.containsKey(shiftId)) {
                          shiftDetails = shiftsData[shiftId];
                        }

                        final shiftName = shiftDetails?['shiftName'] ?? _getShiftName(shiftId);
                        final startTime = shiftDetails?['shiftStartTime'] ?? '00:00';
                        final endTime = shiftDetails?['shiftEndTime'] ?? '00:00';

                        // Make shift buttons more compact on small screens
                        return Container(
                          margin: EdgeInsets.only(
                            right: isSmallScreen ? 8 : 12,
                          ),
                          child: InkWell(
                            onTap: () => _onShiftChange(shiftId),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
                                color: isSelected ? null : DarkColor.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? shiftColor
                                      : Colors.grey.shade700,
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
                                        size: isSmallScreen ? 16 : 20,
                                      ),
                                      SizedBox(width: isSmallScreen ? 4 : 8),
                                      Text(
                                        shiftName,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white,
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
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.3)
                                          : shiftColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "$startTime - $endTime",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 10 : 12,
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
          const Gap(12),

          // Improved seat legend with clearer status indicators
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seat Status:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white
                  ),
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
            child: _isLoadingSeats
                ? const Center(child: CircularProgressIndicator())
                : _selectedShift == null
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
                      color: Colors.grey[400],
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ],
              ),
            )
                : _seats.isEmpty
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
                      color: Colors.grey[400],
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ],
              ),
            )
                : _buildResponsiveSeatMap(context, typedBookingsForShift),
          ),
        ],
      ),
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
            color: Colors.white,
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

    _seats.entries.forEach((entry) {
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
                color: Colors.grey[400],
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'This library doesn\'t have a configured seat layout',
              style: TextStyle(
                color: Colors.grey[400],
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
                color: DarkColor.highlightColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DarkColor.highlightColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Row ${rowIndicator ?? row}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 12 : 14,
                  color: DarkColor.highlightColor,
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
              children: seats.map((entry) {
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
                          if (_selectedShift != null &&
                              shift.key == _selectedShift) {
                            studentId = shift.value['bookedBy'] ?? '';
                          }
                        }
                      }
                    });

                    // Check selected shift status specifically
                    if (_selectedShift != null &&
                        shiftsData.containsKey(_selectedShift)) {
                      final shiftData = shiftsData[_selectedShift];
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
                  case 'confirmed':
                  case 'active':
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
                      } else {
                        // Show seat status dialog for available seats
                        _showSeatStatusDialog(
                          context,
                          seatId,
                          status,
                          isPartiallyBooked,
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

  // Show seat status dialog for available seats
  void _showSeatStatusDialog(
      BuildContext context,
      String seatId,
      String status,
      bool isPartiallyBooked,
      ) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DarkColor.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Seat $seatId',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status.toLowerCase() == 'available' ? Icons.check_circle : Icons.info,
              color: status.toLowerCase() == 'available' ? Colors.green : Colors.orange,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              isPartiallyBooked
                  ? 'This seat is partially booked (booked for some shifts)'
                  : status.toLowerCase() == 'available'
                  ? 'This seat is available for booking'
                  : 'This seat is ${status.toLowerCase()}',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_selectedShift != null) ...[
              SizedBox(height: 8),
              Text(
                'Shift: ${_getShiftName(_selectedShift!)}',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: DarkColor.highlightColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to booking creation screen
              // This would be implemented based on your app's navigation structure
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DarkColor.highlightColor,
            ),
            child: Text('Book Seat'),
          ),
        ],
      ),
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
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DarkColor.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: DarkColor.highlightColor),
              SizedBox(height: 16),
              Text('Loading student details...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );

    try {
      // Get booking details if available
      Map<String, dynamic>? booking = bookingDetails[seatId];
      String bookingId = booking?['bookingId'] ?? '';

      // Get subscriber data from Firestore
      DocumentSnapshot? subscriberData;

      if (SmartLib.libraryId.isNotEmpty) {
        try {
          subscriberData =
          await FirebaseFirestore.instance
              .collection('libraries')
              .doc(SmartLib.libraryId)
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
        builder: (context) => Dialog(
          backgroundColor: DarkColor.cardColor,
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
                    color: DarkColor.highlightColor,
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
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person,
                            color: DarkColor.highlightColor,
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
                                DarkColor.highlightColor,
                                isSmallScreen,
                              ),
                              _buildModernStatusTile(
                                'Status',
                                status,
                                Icons.info_outline,
                                status.toLowerCase() == 'active' || status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'booked'
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
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey),
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
        builder: (context) => AlertDialog(
          backgroundColor: DarkColor.cardColor,
          title: Text('Error', style: TextStyle(color: Colors.white)),
          content: Text(
            'Failed to load student details. Please try again.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: DarkColor.highlightColor)),
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
                color: DarkColor.highlightColor,
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                  color: DarkColor.highlightColor,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
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
        border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: isSmallScreen ? 16 : 18, color: Colors.grey),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Colors.grey),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: Colors.white),
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: isSmallScreen ? 16 : 18, color: Colors.grey),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Colors.grey),
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

  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}