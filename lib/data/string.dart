class SmartLib {
  static const String constPath = 'users';
  static const String constPassword = "password";
  static const String constUserId = "userId";
  static const String constUserType = "userType";
  static const String constStudentPath = "users/students";
  static const String constLibrarianPath = "users/librarians";
  static const String constCurrentStatusPath = "currentStatus";
  static const String constEmail = "email";
  static const String constPhone = "phone";

  //student data list
  static const String constDob = "dateOfBirth";
  static const String constGender = "gender";
  static const String constStudentId = "studentId";
  static const String constStudentName = "studentName";
  static const String constStudentImageUrl = "profileImageUrl";

  //librarian data list
  static const String constLibrarianName = "librarianName";
  static const String constLibrarianId = "librarianId";




  static String email = "";
  static String userId = "";
  static String libraryId = "";
  static String userType = "";
  static String studentName = "";
  static String librarianName = "";
  static String phone = "";
  static String dob = "";
  static String gender = "";
  static String librarianId = "";
  static String studentId = "";
  static String libraryName = "";
  static String noOfSeat = "";
  static String libraryAddress = "";
  static String state = "";
  static String street = "";
  static String landmark = "";
  static String pincode = "";
  static String studentImageUrl = "";
  static String librarianImageUrl = "";
  static String libraryImageUrl = "";
  static String currentStatus = "offline"; // Default status
  static String department = "";
  static String shift = "";
  static String shiftName = "";
  static String shiftStartTime = "";
  static String shiftEndTime = "";
  static String seatNo = "";
  static String seatStatus = "";
  static String shiftFee = "";
  static String tag = "";
  static String userName = "";
  static String address = "";
  static String city = "";
  static String availableSeats = "";
  static String totalSeats = "";
  static String establishedDate = "";
  static String lowFee = "";
  static String libraryType = "";
  static String contactEmail = "";
  static String contactPhone = "";
  static String libraryStatus = ""; // Default status
  static String experience = "";
  static String shiftId = "";
  static String dueDate = "";
  static String isMultipleShifts = "";
  static String paymentStatus = "";
  static String subscriptionStatus = "";
  static String shiftCount = "";
  static String bookingId = "";
  static String isCheckedIn = "";
  //store all libraries list
  static List<Map<String, dynamic>> allLibraryList = [];
  //store all subscriber list
  static List<Map<String, dynamic>> allSubscriberList = [];
  //store all seat booking list
  static List<Map<String, dynamic>> allSeatBookingList = [];

}
class LibraryData{
  //library data list
  static const String constLibraryPath = "libraries";
  static const String libraryType= 'libraryType';
  static const String lowFee = 'lowFee';
  static const String constLibraryName = "libraryName";
  static const String constNoOfSeat = "noOfSeat";
  static const String constLibraryLocation = "libraryLocation";
  static const String constState = "state";
  static const String constDistrict = "district";
  static const String constPincode = "pincode";
  static const String constStreet = "street";
  static const String constLibraryId = "libraryId";
  static const String constLibraryImageUrl = "libraryImageUrl";
  static const String constTag = "tag";
  static const String constEstablishedDate = "establishedDate";
  static const String constShift = "shift";
  static const String constTotalSeats = "totalSeats";
  static const String constAvailableSeats = "availableSeats";
  static const String constLibrarianId = "librarianId";
  static const String constLibraryDescription = "libraryDescription";
  static const String constLibraryLocationMap = "libraryLocationMap";
  static const String constLibraryLocationLat = "locationLatitude";
  static const String constLibraryLocationLong = "locationLongitude";
  static const String constLibraryAddress = "address";
  static const String constLibraryShift = "shifts";
  static const String constLibraryShiftName = "shiftName";
}
