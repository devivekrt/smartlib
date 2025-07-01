import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../data/string.dart';
import '../models/library_model.dart';

// Import your required dependencies here - removed unnecessary imports as requested

class LibrarySubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Submit a new library to Firestore with generated seats
  Future<String> submitLibrary(LibraryModel libraryModel, File? imageFile) async {
    try {
      // Generate a unique library ID if not already provided
      final String libraryId = libraryModel.tag ??
          "LIB_${DateTime.now().millisecondsSinceEpoch}";

      // Set required fields and defaults
      libraryModel.id = libraryId;
      libraryModel.status = 'active';
      libraryModel.rating = 0;
      libraryModel.reviews = 0;
      libraryModel.students = 0;

      // Upload image to Firebase Storage if provided
       if (imageFile != null) {
        final fileName = 'library_images/${libraryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(imageFile);
        final downloadUrl = await storageRef.getDownloadURL();
        libraryModel.libraryImageUrl = downloadUrl;
      }

      // Prepare library data
      final libraryData = libraryModel.toMap();

      // Store library data in Firestore
      await _firestore.collection('libraries')
          .doc(libraryId)
          .set(libraryData);

      // Process shifts for seat generation - modified to handle Map format
      final Map<String, dynamic> shiftsMap;
      // If shifts is already a map, use it directly
      shiftsMap = Map<String, dynamic>.from(libraryModel.shifts);

      // Generate and save seats
      await _generateSeats(libraryId, libraryModel.totalSeats ?? 0, shiftsMap);

      // Connect library to librarian
      await _database.ref('${SmartLib.constPath}/librarians/${libraryModel.librarianId}/managedLibraries')
          .child(libraryId)
          .set(true);

      await _database.ref('${SmartLib.constPath}/librarians/${libraryModel.librarianId}')
          .update({
        'libraryAdded': true,
      });

      return libraryId;
    } catch (e) {
      print("Error submitting library: $e");
      rethrow;
    }
  }

  // Helper method to convert shift models to Firebase structure
  Map<String, dynamic> _convertShiftsToMap(dynamic shifts) {
    final Map<String, dynamic> shiftsMap = {};

    // If shifts is already a Map, return it with validation
    if (shifts is Map<String, dynamic>) {
      // Ensure we have basic structure in each shift
      shifts.forEach((key, value) {
        if (value is Map) {
          shiftsMap[key] = {
            'shiftName': value['shiftName'] ?? key,
            'shiftStartTime': value['shiftStartTime'] ?? '00:00',
            'shiftEndTime': value['shiftEndTime'] ?? '00:00',
            'shiftFee': value['shiftFee'] ?? 0,
          };
        }
      });

      // Add default shifts if missing - this will be handled below
    }
    // Handle old format (List<ShiftModel>)
    else if (shifts is List) {
      // Generate shift IDs based on names or use default names
      for (int i = 0; i < shifts.length; i++) {
        final shift = shifts[i];
        String shiftKey;

        if (shift is ShiftModel) {
          if (shift.shiftName != null && shift.shiftName!.isNotEmpty) {
            // Convert shift name to lowercase and remove spaces for a key
            shiftKey = shift.shiftName!.toLowerCase().replaceAll(' ', '_');
          } else {
            // Default shift key if name is not provided
            switch (i) {
              case 0: shiftKey = 'morning'; break;
              case 1: shiftKey = 'afternoon'; break;
              case 2: shiftKey = 'evening'; break;
              default: shiftKey = 'shift_${i+1}';
            }
          }

          shiftsMap[shiftKey] = {
            'shiftName': shift.shiftName ?? 'Shift ${i+1}',
            'shiftStartTime': shift.startTime ?? '00:00',
            'shiftEndTime': shift.endTime ?? '00:00',
            'shiftFee': shift.fee ?? 0,
          };
        }
      }
    }

    return shiftsMap;
  }

  // Generate seats for the library
  Future<void> _generateSeats(String libraryId, int totalSeats, Map<String, dynamic> shiftsMap) async {
    if (totalSeats <= 0) {
      return;
    }

    try {
      final Map<String, dynamic> seatsData = {};

      // Determine how many rows we need
      int seatCounter = 0;
      int rowIndex = 0;
      final int maxSeatsPerRow = 10; // Adjust as needed

      while (seatCounter < totalSeats) {
        if (rowIndex >= 26) { // A-Z (26 letters)
          // If we run out of letters, use double letters (AA, AB, etc.)
          String rowName = String.fromCharCode(65 + (rowIndex ~/ 26) - 1) +
              String.fromCharCode(65 + (rowIndex % 26));

          for (int colIndex = 1; colIndex <= maxSeatsPerRow && seatCounter < totalSeats; colIndex++) {
            String seatId = "$rowName$colIndex";
            seatsData[seatId] = _createInitialSeatData(shiftsMap);
            seatCounter++;
          }
        } else {
          // Use single letter (A-Z)
          String rowName = String.fromCharCode(65 + rowIndex);

          for (int colIndex = 1; colIndex <= maxSeatsPerRow && seatCounter < totalSeats; colIndex++) {
            String seatId = "$rowName$colIndex";
            seatsData[seatId] = _createInitialSeatData(shiftsMap);
            seatCounter++;
          }
        }

        rowIndex++;
      }

      // Update Firestore with the generated seats
      await _firestore
          .collection('libraries')
          .doc(libraryId)
          .update({'seats': seatsData});

       SnackBar(
        content: Text("Successfully generated and saved $totalSeats seats for library $libraryId"),
      );
    } catch (e) {
      print("Error generating seats: $e");
      rethrow;
    }
  }

  // Creates the initial data structure for a seat with all shifts set to available
  Map<String, dynamic> _createInitialSeatData(Map<String, dynamic> shiftsMap) {
    Map<String, dynamic> shiftsStatus = {};

    // Create status entries for each shift
    shiftsMap.forEach((shiftKey, shiftData) {
      shiftsStatus[shiftKey] = {'status': 'available'};
    });

    return {
      'shifts': shiftsStatus
    };
  }
}