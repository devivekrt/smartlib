import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class LibraryCheckinManagementPage extends StatefulWidget {
  final String libraryId;
  final String libraryName;

  const LibraryCheckinManagementPage({
    Key? key,
    required this.libraryId,
    required this.libraryName,
  }) : super(key: key);

  @override
  _LibraryCheckinManagementPageState createState() => _LibraryCheckinManagementPageState();
}

class _LibraryCheckinManagementPageState extends State<LibraryCheckinManagementPage> {

  // Store seat data
  Map<String, dynamic> _seatsData = {};
  Map<String, dynamic> _studentData = {};
  bool _isLoading = true;
  String _selectedShift = 'all'; // 'morning', 'afternoon', 'evening', or 'all'
  String _errorMessage = '';
  int _totalSeats = 0;
  int _occupiedSeats = 0;
  int _availableSeats = 0;
  int _bookedSeats = 0;

  // Filter options
  bool _showAvailable = true;
  bool _showBooked = true;
  bool _showCheckedIn = true;

  @override
  void initState() {
    super.initState();
    _fetchSeatsData();
  }

  // Fetch all seat data from Firestore
  Future<void> _fetchSeatsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get library document with seats data
      final libraryDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .get();

      if (!libraryDoc.exists || !libraryDoc.data()!.containsKey('seats')) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No seat data found for this library';
        });
        return;
      }

      final seatsData = libraryDoc.data()!['seats'] as Map<String, dynamic>;

      // Get all active student data to match with seats
      Map<String, dynamic> studentData = {};
      try {
        // Query the students currently checked into this library
        final studentsSnapshot = await FirebaseDatabase.instance
            .ref('users/students')
            .orderByChild('currentStatus/currentLibraryId')
            .equalTo(widget.libraryId)
            .get();

        if (studentsSnapshot.exists) {
          final studentsMap = studentsSnapshot.value as Map<dynamic, dynamic>;

          studentsMap.forEach((studentId, data) {
            if (data is Map &&
                data.containsKey('currentStatus') &&
                data['currentStatus']['isCheckedIn'] == true) {

              // Extract student info
              studentData[studentId.toString()] = {
                'name': data['name'] ?? data['studentName'] ?? 'Unknown Student',
                'seatNo': data['currentStatus']['currentSeatNo'] ?? '',
                'checkInTime': data['currentStatus']['checkInTime'] ?? '',
                'shiftId': _extractShiftId(data['currentStatus']),
                'profilePic': data['profilePic'] ?? '',
              };
            }
          });
        }
      } catch (e) {
        print('Error fetching student data: $e');
      }

      // Calculate statistics
      int totalSeats = seatsData.length;
      int occupiedSeats = 0;
      int availableSeats = 0;
      int bookedSeats = 0;

      seatsData.forEach((seatId, seatData) {
        if (seatData is Map && seatData.containsKey('shifts')) {
          bool isOccupied = false;
          bool isBooked = false;

          final shiftsData = seatData['shifts'] as Map<String, dynamic>;
          shiftsData.forEach((shiftId, shiftData) {
            if (shiftData is Map) {
              if (shiftData['isCheckedIn'] == true) {
                isOccupied = true;
              } else if (shiftData['status'] == 'booked') {
                isBooked = true;
              }
            }
          });

          if (isOccupied) {
            occupiedSeats++;
          } else if (isBooked) {
            bookedSeats++;
          } else {
            availableSeats++;
          }
        }
      });

      setState(() {
        _seatsData = seatsData;
        _studentData = studentData;
        _totalSeats = totalSeats;
        _occupiedSeats = occupiedSeats;
        _availableSeats = availableSeats;
        _bookedSeats = bookedSeats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load seat data: $e';
      });
      print('Error loading seats: $e');
    }
  }

  // Helper method to extract shift ID from student data
  String _extractShiftId(dynamic currentStatus) {
    if (currentStatus is Map) {
      // Check for multiple shifts
      if (currentStatus.containsKey('shiftIds')) {
        if (currentStatus['shiftIds'] is List && (currentStatus['shiftIds'] as List).isNotEmpty) {
          return (currentStatus['shiftIds'] as List).first.toString();
        } else if (currentStatus['shiftIds'] is Map && (currentStatus['shiftIds'] as Map).isNotEmpty) {
          return (currentStatus['shiftIds'] as Map).values.first.toString();
        }
      }
      // Check for single shift
      else if (currentStatus.containsKey('shiftId')) {
        if (currentStatus['shiftId'] is Map) {
          try {
            final shiftIdMap = currentStatus['shiftId'] as Map;
            if (shiftIdMap.isNotEmpty) {
              return shiftIdMap.values.first.toString();
            }
          } catch (e) {
            print('Error parsing nested shiftId: $e');
          }
        } else if (currentStatus['shiftId'] != null) {
          return currentStatus['shiftId'].toString();
        }
      }
    }
    return '';
  }

  // Refresh data
  Future<void> _refreshData() async {
    await _fetchSeatsData();
  }

  // Change selected shift
  void _changeShift(String shift) {
    setState(() {
      _selectedShift = shift;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Library Check-in Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Library header with statistics
          _buildHeader(),

          // Filter options
          _buildFilterOptions(),

          // Seat chart
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(_errorMessage, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
                : _buildSeatLayout(),
          ),

          // Legend at the bottom
          _buildLegend(),
        ],
      ),
    );
  }

  // Library header with statistics
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF1E40AF)
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                widget.libraryName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Statistics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                  'Total Seats',
                  _totalSeats.toString(),
                  Colors.white
              ),
              _buildStatItem(
                  'Occupied',
                  _occupiedSeats.toString(),
                  Colors.purple
              ),
              _buildStatItem(
                  'Booked',
                  _bookedSeats.toString(),
                  Colors.red
              ),
              _buildStatItem(
                  'Available',
                  _availableSeats.toString(),
                  Colors.green
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Filter options
  Widget _buildFilterOptions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter By:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              // Shift filter chips
              _buildFilterChip(
                  'All Shifts',
                  _selectedShift == 'all',
                      () => _changeShift('all')
              ),
              SizedBox(width: 6),
              _buildFilterChip(
                  'Morning',
                  _selectedShift == 'morning',
                      () => _changeShift('morning')
              ),
              SizedBox(width: 6),
              _buildFilterChip(
                  'Afternoon',
                  _selectedShift == 'afternoon',
                      () => _changeShift('afternoon')
              ),
              SizedBox(width: 6),
              _buildFilterChip(
                  'Evening',
                  _selectedShift == 'evening',
                      () => _changeShift('evening')
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              // Status filter chips
              _buildFilterToggleChip(
                'Available',
                _showAvailable,
                Colors.green,
                    (value) => setState(() => _showAvailable = value),
              ),
              SizedBox(width: 8),
              _buildFilterToggleChip(
                'Booked',
                _showBooked,
                Colors.red,
                    (value) => setState(() => _showBooked = value),
              ),
              SizedBox(width: 8),
              _buildFilterToggleChip(
                'Checked In',
                _showCheckedIn,
                Colors.purple,
                    (value) => setState(() => _showCheckedIn = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Seat layout builder
  Widget _buildSeatLayout() {
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

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          // Screen indicator at the top
          Container(
            margin: EdgeInsets.only(bottom: 40),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 60),
            decoration: BoxDecoration(
              color: Colors.blueGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'SCREEN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Rows of seats
          ...seatsByRow.entries.map((rowEntry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  // Row label
                  Container(
                    width: 30,
                    alignment: Alignment.center,
                    child: Text(
                      rowEntry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Seats in this row
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: rowEntry.value.map((seatEntry) {
                          return _buildSeatItem(seatEntry.key, seatEntry.value);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Individual seat item
  Widget _buildSeatItem(String seatId, dynamic seatData) {
    // Check seat status based on selected shift and filters
    bool isAvailable = true;
    bool isBooked = false;
    bool isOccupied = false;
    String studentId = '';
    String studentName = '';
    String checkInTime = '';

    if (seatData is Map && seatData.containsKey('shifts')) {
      final shiftsData = seatData['shifts'] as Map<String, dynamic>;

      // If a specific shift is selected
      if (_selectedShift != 'all') {
        if (shiftsData.containsKey(_selectedShift)) {
          final shiftData = shiftsData[_selectedShift];
          if (shiftData is Map) {
            if (shiftData['isCheckedIn'] == true) {
              isOccupied = true;
              isAvailable = false;
              studentId = shiftData['studentId']?.toString() ?? '';
            } else if (shiftData['status'] == 'booked') {
              isBooked = true;
              isAvailable = false;
              studentId = shiftData['bookedBy']?.toString() ?? '';
            }
          }
        }
      }
      // If all shifts are selected
      else {
        // Check all shifts - if any are occupied or booked
        shiftsData.forEach((shiftId, shiftData) {
          if (shiftData is Map) {
            if (shiftData['isCheckedIn'] == true) {
              isOccupied = true;
              isAvailable = false;
              studentId = shiftData['studentId']?.toString() ?? '';
            } else if (!isOccupied && shiftData['status'] == 'booked') {
              isBooked = true;
              isAvailable = false;
              studentId = shiftData['bookedBy']?.toString() ?? '';
            }
          }
        });
      }
    }

    // Get student details if occupied
    if (isOccupied && studentId.isNotEmpty) {
      if (_studentData.containsKey(studentId)) {
        studentName = _studentData[studentId]['name'] ?? 'Unknown Student';
        checkInTime = _studentData[studentId]['checkInTime'] ?? '';
      }
    }

    // Determine if this seat should be shown based on filters
    bool showSeat = (isAvailable && _showAvailable) ||
        (isBooked && _showBooked) ||
        (isOccupied && _showCheckedIn);

    if (!showSeat) {
      // Return empty container but keep the spacing
      return Container(
        width: 60,
        height: 80,
        margin: EdgeInsets.all(4),
      );
    }

    // Color for the seat
    Color seatColor = isOccupied
        ? Colors.purple
        : isBooked
        ? Colors.red
        : Colors.green;

    // Extract row and seat number for display
    String rowName = seatId.replaceAll(RegExp(r'[0-9]'), '');
    String seatNum = seatId.replaceAll(RegExp(r'[A-Za-z]'), '');

    return Container(
      width: 60,
      height: 80,
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: seatColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: seatColor, width: 2),
      ),
      child: InkWell(
        onTap: () {
          // Show seat details in a modal
          if (isOccupied) {
            _showSeatDetailsModal(context, seatId, studentName, checkInTime, seatColor);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Seat number
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  seatNum,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: seatColor,
                  ),
                ),
                if (isOccupied && studentName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      studentName.split(' ')[0], // First name only
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: seatColor,
                      ),
                    ),
                  ),
              ],
            ),

            // Status indicator on top right
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: seatColor,
                  shape: BoxShape.circle,
                ),
                child: isOccupied
                    ? Icon(Icons.person, size: 8, color: Colors.white)
                    : isBooked
                    ? Icon(Icons.book, size: 8, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show seat details modal
  void _showSeatDetailsModal(BuildContext context, String seatId, String studentName, String checkInTime, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chair, color: color, size: 30),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seat $seatId',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      Text('Currently Occupied'),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Student info
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                    style: TextStyle(color: color),
                  ),
                ),
                title: Text(studentName),
                subtitle: Text('Student'),
                trailing: Icon(Icons.person),
              ),

              // Check-in time
              if (checkInTime.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.access_time, color: color),
                  title: Text(checkInTime),
                  subtitle: Text('Check-in Time'),
                ),

              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: Size(double.infinity, 45),
                ),
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Legend section
  Widget _buildLegend() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem('Available', Colors.green),
          _buildLegendItem('Booked', Colors.red),
          _buildLegendItem('Checked In', Colors.purple),
        ],
      ),
    );
  }

  // Build legend item
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 2),
          ),
        ),
        SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  // Build statistics item
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Build filter chip
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF1E40AF) : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Build toggle filter chip
  Widget _buildFilterToggleChip(String label, bool isSelected, Color color, Function(bool) onChanged) {
    return FilterChip(
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
        ),
      ),
      label: Text(label),
      onSelected: onChanged,
    );
  }
}