import 'package:cloud_firestore/cloud_firestore.dart';

class SeatGenerationUtil {
  /// Generates unique seat IDs and creates the initial seat structure in Firestore.
  /// The seats are organized by rows (A-Z) and columns (1-n).
  ///
  /// Parameters:
  /// - libraryId: The ID of the library document
  /// - totalSeats: Total number of seats to generate
  /// - maxSeatsPerRow: Maximum seats per row (default: 10)
  static Future<void> generateAndSaveSeats({
    required String libraryId,
    required int totalSeats,
    int maxSeatsPerRow = 5,
  }) async {
    if (totalSeats <= 0) {
      return;
    }

    try {
      final Map<String, dynamic> seatsData = {};

      // Determine how many rows we need
      int seatCounter = 0;
      int rowIndex = 0;

      while (seatCounter < totalSeats) {
        if (rowIndex >= 26) { // A-Z (26 letters)
          // If we run out of letters, use double letters (AA, AB, etc.)
          String rowName = String.fromCharCode(65 + (rowIndex ~/ 26) - 1) +
              String.fromCharCode(65 + (rowIndex % 26));

          for (int colIndex = 1; colIndex <= maxSeatsPerRow && seatCounter < totalSeats; colIndex++) {
            String seatId = "$rowName$colIndex";
            seatsData[seatId] = _createInitialSeatData();
            seatCounter++;
          }
        } else {
          // Use single letter (A-Z)
          String rowName = String.fromCharCode(65 + rowIndex);

          for (int colIndex = 1; colIndex <= maxSeatsPerRow && seatCounter < totalSeats; colIndex++) {
            String seatId = "$rowName$colIndex";
            seatsData[seatId] = _createInitialSeatData();
            seatCounter++;
          }
        }

        rowIndex++;
      }

      // Update Firestore with the generated seats
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .update({'seats': seatsData});

      print("Successfully generated and saved $totalSeats seats for library $libraryId");
    } catch (e) {
      print("Error generating seats: $e");
      rethrow;
    }
  }

  /// Creates the initial data structure for a seat with all shifts set to available
  static Map<String, dynamic> _createInitialSeatData() {
    return {
      'shifts': {
        'morning': {'status': 'available'},
        'afternoon': {'status': 'available'},
        'evening': {'status': 'available'},
      }
    };
  }
}