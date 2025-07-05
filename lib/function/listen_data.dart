import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' as firebase_db;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/function/student_function.dart';
import 'package:smartlib/models/library_model.dart';

/// A centralized data management class that handles data listening and caching
/// for the SmartLib application. This reduces Firebase reads and improves app performance.
class ListenData {
  // MARK: - Singleton Pattern
  static final ListenData _instance = ListenData._internal();
  factory ListenData() => _instance;
  ListenData._internal();

  // MARK: - Properties
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_db.FirebaseDatabase _database = firebase_db.FirebaseDatabase.instance;

  // Stream subscriptions management
  final Map<String, StreamSubscription> _subscriptions = {};

  // Cache management
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimes = {};
  final int _cacheDurationMinutes = 5;

  // Network status
  bool _isOnline = true;

  // MARK: - Public Methods



  /// Set up listeners based on the user's role
  Future<void> getUserData() async {
    try {
      String? userId = await AuthService.getUserId();
      String? userRole = await AuthService.getUserRole();

      if (userId == null || userRole == null) {
        return;
      }

      // Set up student listeners
      if (userRole == 'student') {
        SmartLib.studentId = userId;
        SmartLib.userType = 'student';
        SmartLib.userId = userId;

        _setupStudentListeners();
      }
      // Set up librarian listeners
      else if (userRole == 'librarian') {
        SmartLib.librarianId = userId;
        SmartLib.userType = 'librarian';
        SmartLib.userId = userId;

        _setupLibrarianListeners();
      }
    } catch (e) {
    }
  }

  /// Clean up all listeners to prevent memory leaks
  void dispose() {
    try {
      _subscriptions.forEach((key, subscription) {
        subscription.cancel();
      });
      _subscriptions.clear();
    } catch (e) {

    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedKeys = prefs.getStringList('cachedKeys') ?? [];

      for (final key in cachedKeys) {
        await prefs.remove(key);
        await prefs.remove('${key}_time');
      }

      await prefs.remove('cachedKeys');
      _memoryCache.clear();
      _cacheTimes.clear();

    } catch (e) {
    }
  }

  // MARK: - Data Fetch Methods



  /// Get attendance records for a specific date and student
  Future<List<Map<String, dynamic>>> getAttendanceRecordsForDate(
      String date, String studentId) async {
    if (date.isEmpty || studentId.isEmpty) {
      return [];
    }

    final cacheKey = 'attendance_${date}_${studentId}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('attendance')
          .doc(date)
          .collection('records')
          .where('studentId', isEqualTo: studentId)

          .get();

      final attendanceRecords = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final recordData = doc.data();
        final recordId = doc.id;
        recordData['id'] = recordId;

        // Process timestamps
        if (recordData['timestamp'] != null) {
          try {
            recordData['timestampDateTime'] =
                (recordData['timestamp'] as Timestamp).toDate().toString();
          } catch (e) {
          }
        }

        attendanceRecords.add(recordData);
      }

      // Cache the results
      await _cacheData(cacheKey, attendanceRecords);

      return attendanceRecords;
    } catch (e) {

      // Return cached data on error if available
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      return [];
    }
  }

  /// Get all libraries data
  Future<List<Map<String, dynamic>>> getAllLibraries() async {
    final cacheKey = 'all_libraries';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('libraries')
          .orderBy('libraryName')
          .get();

      final allLibraries = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final libraryData = doc.data();
        final libraryId = doc.id;
        libraryData['id'] = libraryId;
        allLibraries.add(libraryData);
      }

      // Cache the results
      await _cacheData(cacheKey, allLibraries);

      // Update SmartLib
      SmartLib.allLibraryList = allLibraries;

      return allLibraries;
    } catch (e) {

      // Return cached data on error if available
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      return [];
    }
  }

  /// Get seat bookings for a specific library
  Future<List<Map<String, dynamic>>> getSeatBookingsForLibrary() async {
    if (SmartLib.libraryId.isEmpty) {
      return [];
    }

    final cacheKey = 'seat_bookings_${SmartLib.libraryId}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('seatBookings')
          .where('libraryId', isEqualTo: SmartLib.libraryId)
          .get();

      final seatBookings = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final bookingData = doc.data();
        final bookingId = doc.id;
        bookingData['id'] = bookingId;
        // Process timestamps
        if (bookingData['createdAt'] != null) {
          try {
            bookingData['createdAtDateTime'] =
                (bookingData['createdAt'] as Timestamp).toDate().toString();
          } catch (e) {
          }
        }



        seatBookings.add(bookingData);
      }

      // Cache the results
      await _cacheData(cacheKey, seatBookings);

      // Update SmartLib
      SmartLib.allSeatBookingList = seatBookings;

      return seatBookings;
    } catch (e) {

      // Return cached data on error if available
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      return [];
    }
  }

  /// Get attendance records for a specific library on a specific date
  Future<List<Map<String, dynamic>>> getAttendanceRecordsForLibrary(
      String date) async {
    if (SmartLib.libraryId.isEmpty || date.isEmpty) {
      return [];
    }

    final cacheKey = 'attendance_lib_${SmartLib.libraryId}_${date}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('attendance')
          .doc(date)
          .collection('records')
          .where('libraryId', isEqualTo: SmartLib.libraryId)
          .orderBy('timestamp', descending: true)
          .get();

      final attendanceRecords = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final recordData = doc.data();
        final recordId = doc.id;
        recordData['id'] = recordId;

        // Process timestamps
        if (recordData['timestamp'] != null) {
          try {
            recordData['timestampDateTime'] =
                (recordData['timestamp'] as Timestamp).toDate().toString();
          } catch (e) {
          }
        }

        attendanceRecords.add(recordData);
      }

      // Cache the results
      await _cacheData(cacheKey, attendanceRecords);

      return attendanceRecords;
    } catch (e) {

      // Return cached data on error if available
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      return [];
    }
  }

  ///get all subcribers for a specific library
  Future<List<Map<String, dynamic>>> getAllSubscribers() async {
    if (SmartLib.libraryId.isEmpty) {
      return [];
    }

    final cacheKey = 'subscribers_${SmartLib.libraryId}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('libraries')
          .doc(SmartLib.libraryId)
          .collection('subscribers')
          .get();

      final allSubscribers = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final subscriberData = doc.data();
        final subscriberId = doc.id;
        subscriberData['id'] = subscriberId;


        allSubscribers.add(subscriberData);
      }

      // Cache the results
      await _cacheData(cacheKey, allSubscribers);

      return allSubscribers;
    } catch (e) {

      // Return cached data on error if available
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      return [];
    }
  }

  // MARK: - Private Helper Methods

  /// Set up all listeners for student role
  void _setupStudentListeners() {
    _startListener(
      name: 'student_data',
      listener: () => listenToStudentData(),
    );

    _startListener(
      name: 'current_status',
      listener: () => listenToCurrentStatus(),
    );



  }

  /// Set up all listeners for librarian role
  void _setupLibrarianListeners() {
    _startListener(
      name: 'librarian_data',
      listener: () => listenToLibrarianData(),
    );

    _startListener(
      name: 'library_data',
      listener: () => listenToLibraryData(),

    );


  }

  /// Start a listener with retry logic
  void _startListener({
    required String name,
    required Function listener,
    Function? onSuccess,
    int maxRetries = 3
  }) {
    // Cancel existing subscription if any
    if (_subscriptions.containsKey(name)) {
      _subscriptions[name]?.cancel();
      _subscriptions.remove(name);
    }

    int retries = 0;

    void tryStartListener() {
      try {
        listener();
        if (onSuccess != null) {
          onSuccess();
        }
      } catch (e) {
        if (retries < maxRetries) {
          retries++;
          Future.delayed(Duration(seconds: 2 * retries), tryStartListener);
        } else {
        }
      }
    }

    tryStartListener();
  }

  /// Load cached data from SharedPreferences
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedKeys = prefs.getStringList('cachedKeys') ?? [];

      for (final key in cachedKeys) {
        final cachedData = prefs.getString(key);
        if (cachedData != null) {
          final cacheTimeStr = prefs.getString('${key}_time');
          DateTime? cacheTime;

          if (cacheTimeStr != null) {
            try {
              cacheTime = DateTime.parse(cacheTimeStr);
            } catch (e) {
            }
          }

          try {
            _memoryCache[key] = json.decode(cachedData);
            _cacheTimes[key] = cacheTime ?? DateTime.now();

            // Apply cached data to SmartLib if it's not expired
            if (_isCacheValid(key)) {
              _applyCachedDataToSmartLib(key);
            }
          } catch (e) {
          }
        }
      }
    } catch (e) {
    }
  }

  /// Check if cache for a specific key is still valid
  bool _isCacheValid(String key) {
    final cacheTime = _cacheTimes[key];
    if (cacheTime == null) return false;

    final now = DateTime.now();
    return now.difference(cacheTime).inMinutes < _cacheDurationMinutes;
  }

  /// Apply cached data to SmartLib
  void _applyCachedDataToSmartLib(String key) {
    final data = _memoryCache[key];
    if (data == null) return;

    try {
      if (key == 'student_data' && data is Map) {
        _applyStudentData(Map<String, dynamic>.from(data));
      } else if (key == 'librarian_data' && data is Map) {
        _applyLibrarianData(Map<String, dynamic>.from(data));
      } else if (key == 'library_data' && data is Map) {
        _applyLibraryData(Map<String, dynamic>.from(data));
      } else if (key == 'current_status' && data is Map) {
        _applyCurrentStatusData(Map<String, dynamic>.from(data));
      } else if (key == 'seat_booking' && data is Map) {
        _applySeatBookingData(Map<String, dynamic>.from(data));
      } else if (key == 'all_libraries' && data is List) {
        SmartLib.allLibraryList = List<Map<String, dynamic>>.from(
            data.map((item) => Map<String, dynamic>.from(item as Map))
        );
      }
    } catch (e) {
    }
  }

  /// Save data to cache
  /// Save data to cache
  Future<void> _cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedKeys = prefs.getStringList('cachedKeys') ?? [];

      if (!cachedKeys.contains(key)) {
        cachedKeys.add(key);
        await prefs.setStringList('cachedKeys', cachedKeys);
      }

      // Store in memory cache
      _memoryCache[key] = data;
      _cacheTimes[key] = DateTime.now();

      // Convert data to JSON string before saving to SharedPreferences
      try {
        final String jsonData = json.encode(data);
        await prefs.setString(key, jsonData);
        await prefs.setString('${key}_time', DateTime.now().toIso8601String());
      } catch (jsonError) {
        // Try to identify the problematic fields
        if (data is Map) {
          _debugInspectMapForJsonIssues(key, data);
        } else if (data is List) {
          _debugInspectListForJsonIssues(key, data);
        }
      }
    } catch (e) {
    }
  }

  /// Helper method to debug JSON serialization issues in Maps
  void _debugInspectMapForJsonIssues(String key, Map data) {
    try {
      data.forEach((k, v) {
        try {
          json.encode({k.toString(): v});
        } catch (e) {
          // If value is a nested map or list, recursively inspect it
          if (v is Map) {
            _debugInspectMapForJsonIssues("$key.$k", v);
          } else if (v is List) {
            _debugInspectListForJsonIssues("$key.$k", v);
          }
        }
      });
    } catch (e) {
    }
  }

  /// Helper method to debug JSON serialization issues in Lists
  void _debugInspectListForJsonIssues(String key, List data) {
    try {
      for (int i = 0; i < data.length; i++) {
        try {
          json.encode([data[i]]);
        } catch (e) {
          // If value is a nested map or list, recursively inspect it
          if (data[i] is Map) {
            _debugInspectMapForJsonIssues("$key[$i]", data[i]);
          } else if (data[i] is List) {
            _debugInspectListForJsonIssues("$key[$i]", data[i]);
          }
        }
      }
    } catch (e) {
    }
  }

  // MARK: - Listener Methods

  /// Listen for student data changes
  void listenToStudentData() {
    if (SmartLib.studentId.isEmpty) {
      return;
    }

    _subscriptions['student_data'] = _database
        .ref('users/students/${SmartLib.studentId}')
        .onValue
        .listen((firebase_db.DatabaseEvent event) {
      final data = event.snapshot.value;

      if (data != null) {
        try {
          // Make sure data is a Map before casting
          if (data is Map) {
            final studentData = Map<String, dynamic>.from(data);

            // Cache the data
            _cacheData('student_data', studentData);

            // Update SmartLib
            _applyStudentData(studentData);
          } else {
          }
        } catch (e) {
        }
      } else {
      }
    }, onError: (error) {
    });
  }

  /// Listen for librarian data changes
  void listenToLibrarianData() {
    if (SmartLib.librarianId.isEmpty) {
      return;
    }

    _subscriptions['librarian_data'] = _database
        .ref('users/librarians/${SmartLib.librarianId}')
        .onValue
        .listen((firebase_db.DatabaseEvent event) {
      final data = event.snapshot.value;

      if (data != null) {
        try {
          // Make sure data is a Map before casting
          if (data is Map) {
            final librarianData = Map<String, dynamic>.from(data);

            // Cache the data
            _cacheData('librarian_data', librarianData);

            // Update SmartLib
            _applyLibrarianData(librarianData);
          } else {
          }
        } catch (e) {
        }
      } else {
      }
    }, onError: (error) {
    });
  }

  /// Listen for library data changes
  void listenToLibraryData() {
    if (SmartLib.librarianId.isEmpty) {
      return;
    }

    _subscriptions['library_data'] = _firestore
        .collection('libraries')
        .where('librarianId', isEqualTo: SmartLib.librarianId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        return;
      }

      try {
        // Process the first library document
        final doc = snapshot.docs[0];
        final libraryData = doc.data();
        final libraryId = doc.id;

        // Add ID to the data
        libraryData['id'] = libraryId;


        // Cache the data
        _cacheData('library_data', libraryData);

        // Update SmartLib
        _applyLibraryData(libraryData);
      } catch (e) {
      }
    }, onError: (error) {
    });
  }


  /// Listen for current status updates for a student
  void listenToCurrentStatus() {
    if (SmartLib.studentId.isEmpty) {
      return;
    }

    _subscriptions['current_status'] = _database
        .ref('users/students/${SmartLib.studentId}/currentStatus')
        .onValue
        .listen((firebase_db.DatabaseEvent event) {
      final data = event.snapshot.value;

      if (data != null) {
        try {
          // Make sure data is a Map before casting
          if (data is Map) {
            final currentStatusData = Map<String, dynamic>.from(data);


            // Update SmartLib
            _applyCurrentStatusData(currentStatusData);
          } else {
          }
        } catch (e) {
        }
      } else {
      }
    }, onError: (error) {
    });
  }

  /// Listen for seat booking updates for a student
  void listenToSeatBookingUpdates() {
    if (SmartLib.studentId.isEmpty) {
      return;
    }

    _subscriptions['seat_booking'] = _firestore
        .collection('seatBooking')
        .where('studentId', isEqualTo: SmartLib.studentId)
       // .orderBy('createdAt', descending: true)
        //.limit(1) // Just get the latest booking
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        return;
      }

      try {
       //all bookings history
        for (var doc in snapshot.docs) {
          final bookingData = doc.data();
          final bookingId = doc.id;

          // Process timestamps
          if (bookingData['createdAt'] != null) {
            try {
              bookingData['createdAtDateTime'] =
                  (bookingData['createdAt'] as Timestamp).toDate().toString();
            } catch (e) {
            }
          }

          // Add booking ID to the data
          bookingData['id'] = bookingId;

          // Cache the data
          _cacheData('seat_booking', bookingData);

          // Update SmartLib
          _applySeatBookingData(bookingData);
        }

      } catch (e) {
      }
    }, onError: (error) {
    });
  }

  /// Listen for today's attendance data for a student
  void _listenToStudentAttendanceData() {
    if (SmartLib.studentId.isEmpty) {
      return;
    }

    // Get today's date in YYYY-MM-DD format
    final today = DateTime.now().toIso8601String().split('T')[0];

    _subscriptions['student_attendance'] = _firestore
        .collection('attendance')
        .doc(today)
        .collection('records')
        .where('studentId', isEqualTo: SmartLib.studentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      try {
        final records = <Map<String, dynamic>>[];

        for (var doc in snapshot.docs) {
          final recordData = doc.data();
          recordData['id'] = doc.id;

          // Process timestamps
          if (recordData['timestamp'] != null) {
            try {
              recordData['timestampDateTime'] =
                  (recordData['timestamp'] as Timestamp).toDate().toString();
            } catch (e) {
              // Skip this conversion if there's an error
            }
          }

          records.add(recordData);
        }

        // Cache the data
        _cacheData('student_attendance_${today}', records);

      } catch (e) {
      }
    }, onError: (error) {
    });
  }

  /// Listen for today's attendance data for a library
  void _listenToLibraryAttendanceData() {
    if (SmartLib.libraryId.isEmpty) {
      return;
    }

    // Get today's date in YYYY-MM-DD format
    final today = DateTime.now().toIso8601String().split('T')[0];

    _subscriptions['librarian_attendance'] = _firestore
        .collection('attendance')
        .doc(today)
        .collection('records')
        .where('libraryId', isEqualTo: SmartLib.libraryId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      try {
        final records = <Map<String, dynamic>>[];

        for (var doc in snapshot.docs) {
          final recordData = doc.data();
          recordData['id'] = doc.id;

          // Process timestamps
          if (recordData['timestamp'] != null) {
            try {
              recordData['timestampDateTime'] =
                  (recordData['timestamp'] as Timestamp).toDate().toString();
            } catch (e) {
              // Skip this conversion if there's an error
            }
          }

          records.add(recordData);
        }

        // Cache the data
        _cacheData('library_attendance_${today}', records);

      } catch (e) {
      }
    }, onError: (error) {
    });
  }

  // MARK: - Data Application Methods

  /// Apply student data to SmartLib
  void _applyStudentData(Map<String, dynamic> data) {
    SmartLib.email = data['email'] ?? '';
    SmartLib.studentName = data['fullName'] ?? '';
    SmartLib.phone = data['phone'] ?? '';
    SmartLib.dob = data['dateOfBirth'] ?? '';
    SmartLib.gender = data['gender'] ?? '';
    SmartLib.studentId = SmartLib.studentId; // Keep existing ID
    SmartLib.studentImageUrl = data['profileImageUrl'] ?? '';
    SmartLib.userType = 'student';
    SmartLib.department = data['department'] ?? '';
    SmartLib.userName = data['username'] ?? '';
  }

  /// Apply librarian data to SmartLib
  void _applyLibrarianData(Map<String, dynamic> data) {
    SmartLib.librarianName = data['fullName'] ?? '';
    SmartLib.librarianId = SmartLib.librarianId; // Keep existing ID
    SmartLib.librarianImageUrl = data['profileImageUrl'] ?? '';
    SmartLib.userType = 'librarian';
    SmartLib.email = data['email'] ?? '';
    SmartLib.userId = SmartLib.librarianId;
    SmartLib.phone = data['phone'] ?? '';
    SmartLib.experience = data['experience'] ?? '';
    SmartLib.gender = data['gender'] ?? '';
  }

  /// Apply library data to SmartLib
  void _applyLibraryData(Map<String, dynamic> data) {
    //address in map extract



    SmartLib.libraryId = data['id'] ?? '';
    SmartLib.libraryName = data['libraryName'] ?? '';
    SmartLib.noOfSeat = data['noOfSeat']?.toString() ?? '';
    SmartLib.addressMap = data['address'] ?? '';
    SmartLib.contactMap= data['contact'] ?? '';
    SmartLib.libraryImageUrl = data['libraryImageUrl'] ?? '';
    SmartLib.tag = data['tag'] ?? '';
    SmartLib.librarianId = data['librarianId'] ?? '';
    SmartLib.shift = data['shift'] ?? '';
    SmartLib.totalSeats = data['totalSeats']?.toString() ?? '';
    SmartLib.availableSeats = data['availableSeats']?.toString() ?? '';
    SmartLib.establishedDate = data['establishedDate'] ?? '';
    SmartLib.libraryType = data['libraryType'] ?? '';
    SmartLib.libraryStatus = data['status'] ?? 'active';
    SmartLib.lowFee = data['lowFee']?.toString() ?? '';
  }

  /// Apply current status data to SmartLib
  void _applyCurrentStatusData(Map<String, dynamic> data) {
    SmartLib.currentStatus = data['currentStatus'] ?? '';
    SmartLib.shiftName = data['shiftName'] ?? '';
    SmartLib.shiftStartTime = data['shiftStartTime'] ?? '';
    SmartLib.shiftEndTime = data['shiftEndTime'] ?? '';
    SmartLib.seatNo = data['currentSeatNo'] ?? '';
    SmartLib.seatStatus = data['seatStatus'] ?? '';
    SmartLib.libraryId = data['currentLibraryId'] ?? '';
    SmartLib.libraryName = data['libraryName'] ?? '';
    SmartLib.isCheckedIn = data['isCheckedIn'] ?? '';
    SmartLib.streak = data['streak'] ?? '';
    SmartLib.shiftId = data['shiftId'] ?? '';
    SmartLib.dueDate = data['dueDate'] ?? '';
    SmartLib.isMultipleShifts = data['isMultipleShifts'] ?? false;
    SmartLib.paymentStatus = data['paymentStatus'] ?? '';
    SmartLib.shiftFee = data['totalFee']?.toString() ?? '';
    SmartLib.subscriptionStatus = data['subscriptionStatus'] ?? '';
    SmartLib.shiftCount = data['shiftCount']?.toString() ?? '';
  }

  /// Apply seat booking data to SmartLib
  void _applySeatBookingData(Map<String, dynamic> data) {
    SmartLib.bookingId = data['id'] ?? '';
    SmartLib.seatNo = data['seatNo'] ?? '';
    SmartLib.shiftName = data['shiftName'] ?? '';
    SmartLib.shiftStartTime = data['shiftStartTime'] ?? '';
    SmartLib.shiftEndTime = data['shiftEndTime'] ?? '';
    SmartLib.shiftFee = data['shiftFee']?.toString() ?? '';
  }

}
