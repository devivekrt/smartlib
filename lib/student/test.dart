/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/function/student_function.dart';
import 'package:smartlib/models/library_model.dart';


class ListenData {
  // Check for existing user authentication

  Future<void> getUserData() async {
    String? userId = await AuthService.getUserId();
    String? userRole = await AuthService.getUserRole();
    if (userId != null && userRole != null) {
      if (userRole == 'student') {
        listenToStudentData();
        listenToCurrentStatus();
        listenToSeatBookingUpdates();
        listenToAttendanceData();
        SmartLib.studentId = userId;
      } else if (userRole == 'librarian') {
        listenToLibrarianData();
        listenToLibraryData();
        listenToSubscriberData();
        SmartLib.librarianId = userId;
      }
    }
  }

  //listen for per user data changes
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  //Method to listen for student data changes
  //Student data path: users/students/{studentId}
  // for student dashboard
  void listenToStudentData() {
    // Implement logic to listen to student data changes
    // using  Realtime Database
    _database.ref('users/students/${SmartLib.studentId}').onValue.listen((
        event,
        ) {
      final data = event.snapshot.value;
      // The data is a Map<String, dynamic> where the key is the student ID
      final studentId =
          event.snapshot.key; // Get the student ID from the snapshot key
      if (data != null) {
        // Process the student data
        final studentData = Map<String, dynamic>.from(data as Map);
        print("Student Data Updated: $data");
        // You can update your local state or notify listeners here
        SmartLib.email = studentData['email'] ?? '';
        SmartLib.studentName = studentData['fullName'] ?? '';
        SmartLib.phone = studentData['phone'] ?? '';
        SmartLib.dob = studentData['dateOfBirth'] ?? '';
        SmartLib.gender = studentData['gender'] ?? '';
        SmartLib.studentId = studentId ?? '';
        SmartLib.studentImageUrl = studentData['profileImageUrl'] ?? '';
        SmartLib.userType =
        'student'; // Assuming userType is always 'student' for this path
        SmartLib.department = studentData['department'] ?? '';
        SmartLib.userName = studentData['username'] ?? '';
      } else {
        print("No student data found.");
      }
    });
  }

  // Method to listen for library data changes
  // Library data path: libraries/{libraryId}
  // for librarian dashboard
  void listenToLibraryData() {
    // Implement logic to listen to library data changes
    // using  Firestore Database
    _firestore
        .collection('libraries')
        .where('librarianId', isEqualTo: SmartLib.librarianId)
        .snapshots()
        .listen((snapshot) {
      // Create a list to store all subscribers
      final allLibraries = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final libraryData = doc.data();
        allLibraries.add(libraryData);
        final libraryId = doc.id; // Get the library ID from the document ID
        if (libraryData != null) {

          final addressMap = libraryData['address'];
          final contactMap = libraryData['contact'];
          print("Library Data Updated: $libraryData");
          // You can update your local state or notify listeners here
          // Add the library ID to the data

          SmartLib.libraryId = libraryId;
          SmartLib.libraryName = libraryData['libraryName'] ?? '';
          SmartLib.noOfSeat = libraryData['noOfSeat']?.toString() ?? '';
          SmartLib.libraryAddress = libraryData['address'] ?? '';
          SmartLib.city = addressMap['city'] ?? '';
          SmartLib.contactEmail = contactMap['email'] ?? '';
          SmartLib.contactPhone = contactMap['phone'] ?? '';
          SmartLib.state = addressMap['state'] ?? '';
          SmartLib.landmark = addressMap['landMark'] ?? '';
          SmartLib.street = addressMap['street'] ?? '';
          SmartLib.pincode = addressMap['zipCode'] ?? '';
          SmartLib.libraryImageUrl = libraryData['libraryImageUrl'] ?? '';
          SmartLib.tag = libraryData['tag'] ?? '';
          SmartLib.librarianId = libraryData['librarianId'] ?? '';
          SmartLib.shift = libraryData['shift'] ?? '';
          SmartLib.totalSeats = libraryData['totalSeats']?.toString() ?? '';
          SmartLib.availableSeats =
              libraryData['availableSeats']?.toString() ?? '';
          SmartLib.establishedDate = libraryData['establishedDate'] ?? '';
          SmartLib.libraryType = libraryData['libraryType'] ?? '';
          SmartLib.libraryStatus =
              libraryData['status'] ?? 'active'; // Default to 'active'
          SmartLib.lowFee = libraryData['lowFee']?.toString() ?? '';
        } else {
          print("No library data found.");
        }
      }
    });
  }

  // Method to listen for librarian data changes
  // Librarian data path: users/librarians/{librarianId}
  // for librarian dashboard
  void listenToLibrarianData() {
    // Implement logic to listen to librarian data changes
    // using  Realtime Database
    _database.ref('users/librarians/${SmartLib.librarianId}').onValue.listen((
        event,
        ) {
      final data = event.snapshot.value;
      //users/librarians/{librarianId}
      // The data is a Map<String, dynamic> where the key is the librarian ID
      // and the value is the librarian data.
      final librarianId =
          event.snapshot.key; // Get the librarian ID from the snapshot key
      if (data != null) {
        // Process the librarian data
        final librarianData = Map<String, dynamic>.from(data as Map);
        print("Librarian Data Updated: $data");
        // You can update your local state or notify listeners here
        SmartLib.librarianName = librarianData['fullName'] ?? '';
        SmartLib.librarianId = librarianId ?? '';
        SmartLib.librarianImageUrl = librarianData['profileImageUrl'] ?? '';
        SmartLib.userType =
        'librarian'; // Assuming userType is always 'librarian' for this path
        SmartLib.email = librarianData['email'] ?? '';
        SmartLib.userId = librarianId ?? '';
        SmartLib.phone = librarianData['phone'] ?? '';
        SmartLib.experience = librarianData['experience'] ?? '';
        SmartLib.gender = librarianData['gender'] ?? '';
      } else {
        print("No librarian data found.");
      }
    });
  }

  // Method to listen for attendance data changes
  // Attendance data path: attendance/date/{attendanceId}/records
  // for librarian dashboard
  void listenToAttendanceData() {
    // Implement logic to listen to attendance data changes
    // using  Firestore Database
    _firestore.collection('attendance').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final attendanceData = doc.data();
        final attendanceId =
            doc.id; // Get the attendance ID from the document ID

        if (attendanceData != null) {
          print("Attendance Data Updated: $attendanceData");
          // You can update your local state or notify listeners here
          // For example, you might want to update a list of attendance records
        } else {
          print("No attendance data found.");
        }
      }
    });
  }

  // Method to listen for subscriber data changes
// Subscriber data path: libraries/libraryId/subscribers
  // for librarian dashboard
  void listenToSubscriberData() {
    // Implement logic to listen to subscriber data changes
    // using Firestore Database
    _firestore
        .collection('libraries')
        .doc(SmartLib.libraryId)
        .collection('subscribers')
        .snapshots()
        .listen((snapshot) {
      // Create a list to store all subscribers
      final allSubscribers = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final subscriberData = doc.data();
        final subscriberId = doc.id;

        if (subscriberData != null) {
          // Add the subscriber ID to the data
          subscriberData['id'] = subscriberId;

          // Add to the list of all subscribers
          allSubscribers.add(subscriberData);

          print("Subscriber Data Updated: $subscriberData");
        } else {
          print("No subscriber data found for document: $subscriberId");
        }
      }

      // Now you have all subscribers in the allSubscribers list
      print("Total subscribers: ${allSubscribers.length}");

      // Update your application state with the subscriber data
      // For example: SmartLib.subscribers = allSubscribers;
    });
  }

  // Method to listen for current status updates
  // Current status data path: users/students/{studentId}/currentStatus
  // for student dashboard
  // This method will listen to the current status of the student
  void listenToCurrentStatus() {
    // Implement logic to listen to current status updates
    // using  Realtime Database
    _database
        .ref('users/students/${SmartLib.studentId}/currentStatus')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        // Process the current status data
        final currentStatusData = Map<String, dynamic>.from(data as Map);
        print("Current Status Updated: $data");
        // You can update your local state or notify listeners here
        SmartLib.currentStatus = currentStatusData['currentStatus'];
        SmartLib.shiftName = currentStatusData['shiftName'] ?? '';
        SmartLib.shiftStartTime = currentStatusData['shiftStartTime'] ?? '';
        SmartLib.shiftEndTime = currentStatusData['shiftEndTime'] ?? '';
        SmartLib.seatNo = currentStatusData['currentSeatNo'] ?? '';
        SmartLib.seatStatus = currentStatusData['seatStatus'] ?? '';
        SmartLib.libraryId = currentStatusData['currentLibraryId'] ?? '';
        SmartLib.libraryName = currentStatusData['currentLibraryName'] ?? '';
        SmartLib.isCheckedIn = currentStatusData['isCheckedIn'] ?? '';
        SmartLib.librarianId =
            currentStatusData['currentLibraryId'] ?? '';
        SmartLib.shiftId = currentStatusData['shiftId'] ?? '';
        SmartLib.dueDate = currentStatusData['dueDate'] ?? '';
        SmartLib.isMultipleShifts =
            currentStatusData['isMultipleShifts'] ?? false;
        SmartLib.paymentStatus = currentStatusData['paymentStatus'] ?? '';
        SmartLib.shiftFee = currentStatusData['totalFee']?.toString() ?? '';
        SmartLib.subscriptionStatus =
            currentStatusData['subscriptionStatus'] ?? '';
        SmartLib.shiftCount = currentStatusData['shiftCount']?.toString() ?? '';
      } else {
        print("No current status data found.");
      }
    });
  }

  // Method to listen for seat booking updates
  // Seat booking data path: seatBooking/bookingId/where studentId is equal to SmartLib.studentId
  //for student dashboard
  void listenToSeatBookingUpdates() {
    // Implement logic to listen to seat booking updates
    // using  firestore Database
    _firestore.collection('seatBooking')
        .where('studentId', isEqualTo: SmartLib.studentId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final bookingData = doc.data();
        final bookingId = doc.id; // Get the booking ID from the document ID

        if (bookingData != null) {
          // Process the seat booking data
          SmartLib.bookingId = bookingId; // Add booking ID to the data
          print("Seat Booking Data Updated: $bookingData");
          // You can update your local state or notify listeners here
          // For example, you might want to update a list of seat bookings
          SmartLib.seatNo = bookingData['seatNo'] ?? '';
          SmartLib.shiftName = bookingData['shiftName'] ?? '';
          SmartLib.shiftStartTime = bookingData['shiftStartTime'] ?? '';
          SmartLib.shiftEndTime = bookingData['shiftEndTime'] ?? '';
          SmartLib.shiftFee = bookingData['shiftFee']?.toString() ?? '';

        } else {
          print("No seat booking data found.");
        }
      }
    });
  }

  // Method to get all subscribers of a library
  // Subscriber data path: libraries/libraryId/subscribers
  // This method fetches all subscribers of the library
  // and returns them as a list of maps.
  Future<List<Map<String, dynamic>>> getSubscribers() async {
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
        subscriberData['joinedAtDateTime'] =
            (subscriberData['joinedAt'] as Timestamp).toDate();
      }

      allSubscribers.add(subscriberData);
    }

    return allSubscribers;
  }
  // Method to get attendance records for a specific date
  // Attendance data path: attendance/date/{date}/records
  // This method fetches attendance records for a specific date and specific student
  Future<List<Map<String, dynamic>>> getAttendanceRecordsForDate(
      String date, String studentId) async {
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

      attendanceRecords.add(recordData);
    }

    return attendanceRecords;
  }

  // Method to get all libraries data
  // Library data path: libraries
  //get all libraries data
  Future<List<Map<String, dynamic>>> getAllLibraries() async {
    final snapshot = await _firestore.collection('libraries').get();
    final allLibraries = <Map<String, dynamic>>[];


    for (var doc in snapshot.docs) {
      final libraryData = doc.data();
      final libraryId = doc.id;
      libraryData['id'] = libraryId;

      allLibraries.add(libraryData);
      SmartLib.allLibraryList = allLibraries;

    }

    return allLibraries;
  }

  //get seat booking data for a specific library
  // Seat booking data path: seatBooking/libraryId/{libraryId}
  // This method fetches all seat bookings for a specific library
  Future<List<Map<String, dynamic>>> getSeatBookingsForLibrary(String libraryId) async {
    final snapshot = await _firestore
        .collection('seatBooking')
        .where('libraryId', isEqualTo: libraryId)
        .get();

    final seatBookings = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final bookingData = doc.data();
      final bookingId = doc.id;
      bookingData['id'] = bookingId;


      seatBookings.add(bookingData);
      SmartLib.allSeatBookingList = seatBookings;
    }

    return seatBookings;
  }
// Method to get all attendance records for a specific date of specific library
  Future<List<Map<String, dynamic>>> getAttendanceRecordsForLibrary(
      String libraryId, String date) async {
    final snapshot = await _firestore
        .collection('attendance')
        .doc(date)
        .collection('records')
        .where('libraryId', isEqualTo: libraryId)
        .get();

    final attendanceRecords = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final recordData = doc.data();
      final recordId = doc.id;
      recordData['id'] = recordId;

      // Process timestamps if needed
      if (recordData['timestamp'] != null) {
        recordData['timestampDateTime'] =
            (recordData['timestamp'] as Timestamp).toDate();
      }

      attendanceRecords.add(recordData);
    }

    return attendanceRecords;
  }

}*/