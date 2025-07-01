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

  /// Initialize the ListenData system
  Future<void> initialize() async {
    try {
      // Monitor connectivity changes
      Connectivity().onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;

        if (!wasOnline && _isOnline) {
          print("🔄 Connection restored - refreshing data");
          getUserData();
        }
      });

      // Check initial connection
      final connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;

      // Load cached data first
      await _loadCachedData();

      // Then get fresh data if online
      if (_isOnline) {
        await getUserData();
      }
    } catch (e) {
      print("❌ Error initializing ListenData: $e");
    }
  }

  /// Set up listeners based on the user's role
  Future<void> getUserData() async {
    try {
      String? userId = await AuthService.getUserId();
      String? userRole = await AuthService.getUserRole();

      if (userId == null || userRole == null) {
        print("⚠️ No authenticated user found");
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
      print("❌ Error in getUserData: $e");
    }
  }

  /// Clean up all listeners to prevent memory leaks
  void dispose() {
    try {
      _subscriptions.forEach((key, subscription) {
        subscription.cancel();
      });
      _subscriptions.clear();
      print("🧹 All listeners disposed");
    } catch (e) {
      print("❌ Error disposing listeners: $e");
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

      print("🧹 Cache cleared successfully");
    } catch (e) {
      print("❌ Error clearing cache: $e");
    }
  }

  // MARK: - Data Fetch Methods

  /// Get all subscribers for the current library
  Future<List<Map<String, dynamic>>> getSubscribers() async {
    if (SmartLib.libraryId.isEmpty) {
      print("⚠️ Cannot get subscribers: libraryId is empty");
      return [];
    }

    final cacheKey = 'subscribers_${SmartLib.libraryId}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      print("💾 Using cached subscriber list");
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

        // Process timestamps
        if (subscriberData['joinedAt'] != null) {
          try {
            subscriberData['joinedAtDateTime'] =
                (subscriberData['joinedAt'] as Timestamp).toDate().toString();
          } catch (e) {
            print("⚠️ Error converting joinedAt timestamp: $e");
          }
        }

        allSubscribers.add(subscriberData);
      }

      // Cache the results
      await _cacheData(cacheKey, allSubscribers);

      return allSubscribers;
    } catch (e) {
      print("❌ Error fetching subscribers: $e");

      // Return cached data on error if available
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      return [];
    }
  }

  /// Get attendance records for a specific date and student
  Future<List<Map<String, dynamic>>> getAttendanceRecordsForDate(
      String date, String studentId) async {
    if (date.isEmpty || studentId.isEmpty) {
      print("⚠️ Cannot get attendance records: date or studentId is empty");
      return [];
    }

    final cacheKey = 'attendance_${date}_${studentId}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      print("💾 Using cached attendance records");
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
            print("⚠️ Error converting timestamp: $e");
          }
        }

        attendanceRecords.add(recordData);
      }

      // Cache the results
      await _cacheData(cacheKey, attendanceRecords);

      return attendanceRecords;
    } catch (e) {
      print("❌ Error fetching attendance records: $e");

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
      print("💾 Using cached library list");
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
      print("❌ Error fetching libraries: $e");

      // Return cached data on error if available
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      return [];
    }
  }

  /// Get seat bookings for a specific library
  Future<List<Map<String, dynamic>>> getSeatBookingsForLibrary(String libraryId) async {
    if (libraryId.isEmpty) {
      print("⚠️ Cannot get seat bookings: libraryId is empty");
      return [];
    }

    final cacheKey = 'seat_bookings_${libraryId}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      print("💾 Using cached seat bookings");
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('seatBooking')
          .where('libraryId', isEqualTo: libraryId)
          .orderBy('createdAt', descending: true)
          .get();

      final seatBookings = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final bookingData = doc.data();
        final bookingId = doc.id;
        bookingData['id'] = bookingId;



        seatBookings.add(bookingData);
      }

      // Cache the results
      await _cacheData(cacheKey, seatBookings);

      // Update SmartLib
      SmartLib.allSeatBookingList = seatBookings;

      return seatBookings;
    } catch (e) {
      print("❌ Error fetching seat bookings: $e");

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
      String libraryId, String date) async {
    if (libraryId.isEmpty || date.isEmpty) {
      print("⚠️ Cannot get attendance records: libraryId or date is empty");
      return [];
    }

    final cacheKey = 'attendance_lib_${libraryId}_${date}';

    // Return cached data if valid and offline
    if (_isCacheValid(cacheKey) && !_isOnline) {
      print("💾 Using cached attendance records");
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
          .where('libraryId', isEqualTo: libraryId)
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
            print("⚠️ Error converting timestamp: $e");
          }
        }

        attendanceRecords.add(recordData);
      }

      // Cache the results
      await _cacheData(cacheKey, attendanceRecords);

      return attendanceRecords;
    } catch (e) {
      print("❌ Error fetching attendance records: $e");

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

    _startListener(
      name: 'seat_booking',
      listener: () => listenToSeatBookingUpdates(),
    );

    _startListener(
      name: 'student_attendance',
      listener: () => _listenToStudentAttendanceData(),
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
      onSuccess: () {
        // Only start subscriber listener if we have a valid libraryId
        if (SmartLib.libraryId.isNotEmpty) {
          _startListener(
            name: 'subscriber_data',
            listener: () => listenToSubscriberData(),
          );

          _startListener(
            name: 'librarian_attendance',
            listener: () => _listenToLibraryAttendanceData(),
          );
        }
      },
    );

    // Fetch library list for librarian
    getAllLibraries();
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
          print("⚠️ Error starting $name listener. Retrying ($retries/$maxRetries)...");
          Future.delayed(Duration(seconds: 2 * retries), tryStartListener);
        } else {
          print("❌ Failed to start $name listener after $maxRetries attempts: $e");
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
              print("⚠️ Error parsing cache time: $e");
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
            print("⚠️ Error processing cached data for $key: $e");
          }
        }
      }
      print("💾 Loaded ${cachedKeys.length} cached items");
    } catch (e) {
      print("❌ Error loading cached data: $e");
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
      print("❌ Error applying cached data for $key: $e");
    }
  }

  /// Save data to cache
  Future<void> _cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedKeys = prefs.getStringList('cachedKeys') ?? [];

      if (!cachedKeys.contains(key)) {
        cachedKeys.add(key);
        await prefs.setStringList('cachedKeys', cachedKeys);
      }

      _memoryCache[key] = data;
      _cacheTimes[key] = DateTime.now();

      // Convert data to JSON string
      final jsonData = json.encode(data);
      await prefs.setString(key, jsonData);
      await prefs.setString('${key}_time', DateTime.now().toIso8601String());
    } catch (e) {
      print("❌ Error caching data for $key: $e");
    }
  }

  // MARK: - Listener Methods

  /// Listen for student data changes
  void listenToStudentData() {
    if (SmartLib.studentId.isEmpty) {
      print("⚠️ Cannot listen to student data: studentId is empty");
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
            print("📡 Student Data Updated");

            // Cache the data
            _cacheData('student_data', studentData);

            // Update SmartLib
            _applyStudentData(studentData);
          } else {
            print("⚠️ Student data is not in expected Map format");
          }
        } catch (e) {
          print("❌ Error processing student data: $e");
        }
      } else {
        print("⚠️ No student data found");
      }
    }, onError: (error) {
      print("❌ Error listening to student data: $error");
    });
  }

  /// Listen for librarian data changes
  void listenToLibrarianData() {
    if (SmartLib.librarianId.isEmpty) {
      print("⚠️ Cannot listen to librarian data: librarianId is empty");
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
            print("📡 Librarian Data Updated");

            // Cache the data
            _cacheData('librarian_data', librarianData);

            // Update SmartLib
            _applyLibrarianData(librarianData);
          } else {
            print("⚠️ Librarian data is not in expected Map format");
          }
        } catch (e) {
          print("❌ Error processing librarian data: $e");
        }
      } else {
        print("⚠️ No librarian data found");
      }
    }, onError: (error) {
      print("❌ Error listening to librarian data: $error");
    });
  }

  /// Listen for library data changes
  void listenToLibraryData() {
    if (SmartLib.librarianId.isEmpty) {
      print("⚠️ Cannot listen to library data: librarianId is empty");
      return;
    }

    _subscriptions['library_data'] = _firestore
        .collection('libraries')
        .where('librarianId', isEqualTo: SmartLib.librarianId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        print("⚠️ No libraries found for librarian ${SmartLib.librarianId}");
        return;
      }

      try {
        // Process the first library document
        final doc = snapshot.docs[0];
        final libraryData = doc.data();
        final libraryId = doc.id;

        // Add ID to the data
        libraryData['id'] = libraryId;

        print("📡 Library Data Updated: ${libraryData['libraryName']}");

        // Cache the data
        _cacheData('library_data', libraryData);

        // Update SmartLib
        _applyLibraryData(libraryData);
      } catch (e) {
        print("❌ Error processing library data: $e");
      }
    }, onError: (error) {
      print("❌ Error listening to library data: $error");
    });
  }

  /// Listen for subscriber data changes
  void listenToSubscriberData() {
    if (SmartLib.libraryId.isEmpty) {
      print("⚠️ Cannot listen to subscriber data: libraryId is empty");
      return;
    }

    _subscriptions['subscriber_data'] = _firestore
        .collection('libraries')
        .doc(SmartLib.libraryId)
        .collection('subscribers')
        .snapshots()
        .listen((snapshot) {
      try {
        final allSubscribers = <Map<String, dynamic>>[];

        for (var doc in snapshot.docs) {
          final subscriberData = doc.data();
          final subscriberId = doc.id;

          // Add the subscriber ID to the data
          subscriberData['id'] = subscriberId;

          // Process timestamps
          if (subscriberData['joinedAt'] != null) {
            try {
              subscriberData['joinedAtDateTime'] =
                  (subscriberData['joinedAt'] as Timestamp).toDate().toString();
            } catch (e) {
              // Skip this conversion if there's an error
            }
          }

          allSubscribers.add(subscriberData);
        }

        // Cache the data
        _cacheData('subscribers_${SmartLib.libraryId}', allSubscribers);

        print("📡 Subscriber Data Updated: ${allSubscribers.length} subscribers");
      } catch (e) {
        print("❌ Error processing subscriber data: $e");
      }
    }, onError: (error) {
      print("❌ Error listening to subscriber data: $error");
    });
  }

  /// Listen for current status updates for a student
  void listenToCurrentStatus() {
    if (SmartLib.studentId.isEmpty) {
      print("⚠️ Cannot listen to current status: studentId is empty");
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
            print("📡 Current Status Updated");

            // Cache the data
            _cacheData('current_status', currentStatusData);

            // Update SmartLib
            _applyCurrentStatusData(currentStatusData);
          } else {
            print("⚠️ Current status data is not in expected Map format");
          }
        } catch (e) {
          print("❌ Error processing current status data: $e");
        }
      } else {
        print("⚠️ No current status data found");
      }
    }, onError: (error) {
      print("❌ Error listening to current status: $error");
    });
  }

  /// Listen for seat booking updates for a student
  void listenToSeatBookingUpdates() {
    if (SmartLib.studentId.isEmpty) {
      print("⚠️ Cannot listen to seat bookings: studentId is empty");
      return;
    }

    _subscriptions['seat_booking'] = _firestore
        .collection('seatBooking')
        .where('studentId', isEqualTo: SmartLib.studentId)
        .orderBy('bookingTime', descending: true)
        .limit(1) // Just get the latest booking
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        print("⚠️ No seat bookings found for student ${SmartLib.studentId}");
        return;
      }

      try {
        // Process the latest booking
        final doc = snapshot.docs[0];
        final bookingData = doc.data();
        final bookingId = doc.id;

        // Add booking ID to the data
        bookingData['id'] = bookingId;

        print("📡 Seat Booking Data Updated");

        // Cache the data
        _cacheData('seat_booking', bookingData);

        // Update SmartLib
        _applySeatBookingData(bookingData);
      } catch (e) {
        print("❌ Error processing seat booking data: $e");
      }
    }, onError: (error) {
      print("❌ Error listening to seat booking updates: $error");
    });
  }

  /// Listen for today's attendance data for a student
  void _listenToStudentAttendanceData() {
    if (SmartLib.studentId.isEmpty) {
      print("⚠️ Cannot listen to attendance data: studentId is empty");
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

        print("📡 Student Attendance Data Updated: ${records.length} records");
      } catch (e) {
        print("❌ Error processing attendance data: $e");
      }
    }, onError: (error) {
      print("❌ Error listening to attendance data: $error");
    });
  }

  /// Listen for today's attendance data for a library
  void _listenToLibraryAttendanceData() {
    if (SmartLib.libraryId.isEmpty) {
      print("⚠️ Cannot listen to attendance data: libraryId is empty");
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

        print("📡 Library Attendance Data Updated: ${records.length} records");
      } catch (e) {
        print("❌ Error processing attendance data: $e");
      }
    }, onError: (error) {
      print("❌ Error listening to attendance data: $error");
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
    final addressMap = data['address'] as Map<dynamic, dynamic>? ?? {};
    final contactMap = data['contact'] as Map<dynamic, dynamic>? ?? {};

    SmartLib.libraryId = data['id'] ?? '';
    SmartLib.libraryName = data['libraryName'] ?? '';
    SmartLib.noOfSeat = data['noOfSeat']?.toString() ?? '';
    SmartLib.libraryAddress = data['address'] ?? '';
    SmartLib.city = addressMap['city'] ?? '';
    SmartLib.contactEmail = contactMap['email'] ?? '';
    SmartLib.contactPhone = contactMap['phone'] ?? '';
    SmartLib.state = addressMap['state'] ?? '';
    SmartLib.landmark = addressMap['landMark'] ?? '';
    SmartLib.street = addressMap['street'] ?? '';
    SmartLib.pincode = addressMap['zipCode'] ?? '';
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
    SmartLib.libraryName = data['currentLibraryName'] ?? '';
    SmartLib.isCheckedIn = data['isCheckedIn'] ?? '';
    SmartLib.librarianId = data['currentLibraryId'] ?? '';
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