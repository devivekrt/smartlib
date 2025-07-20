import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/string.dart';
import '../models/library_model.dart';

class LibrarySubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Submit a new library to Firestore with generated seats
  Future<String> submitLibrary(LibraryModel libraryModel, File? imageFile) async {
    try {
      // Generate a unique library ID if not already provided
      final String libraryId =
          "LIB_${DateTime.now().millisecondsSinceEpoch}";

      // Set required fields and defaults
      libraryModel.id = libraryId;
      libraryModel.status = 'pending'; // Changed from 'active' to 'pending'
      libraryModel.verificationStatus = 'pending'; // Set verification status
      libraryModel.rating = 0;
      libraryModel.reviews = 0;
      libraryModel.students = 0;

      // Upload image to Firebase Storage if provided
      if (imageFile != null) {
        // Image size not more then 100kb
        final imageSize = await imageFile.length();
        if (imageSize <= 100 * 1024) {
        } else {
          // Compress the image if it's larger than 100KB
          final compressedImage = await _compressImage(imageFile);
          if (compressedImage != null) {
            imageFile = compressedImage;
          } else {
            throw Exception('Failed to compress image to under 100KB');
          }
        }
        final fileName = 'library_images/${libraryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = _storage.ref().child(fileName);
        await storageRef.putFile(imageFile);
        final downloadUrl = await storageRef.getDownloadURL();
        libraryModel.libraryImageUrl = downloadUrl;
      }

      // Ensure openingHours is properly formatted before submission
      if (libraryModel.openingHours == null) {

      } else {
        // Validate that openingHours has the correct structure
        if (!libraryModel.openingHours!.containsKey('mon-fri') ||
            !libraryModel.openingHours!.containsKey('sat-sun')) {
          // Restructure if incorrect format detected
          final Map<String, dynamic> formattedOpeningHours = {};

          libraryModel.openingHours!.forEach((key, value) {
            if (value is Map && value.containsKey('openTime') && value.containsKey('closeTime')) {
              formattedOpeningHours[key] = value;
            } else if (value is Map) {
              formattedOpeningHours[key] = {
                'openTime': value['openTime'] ?? '09:00',
                'closeTime': value['closeTime'] ?? '18:00',
              };
            }
          });

          libraryModel.openingHours = formattedOpeningHours;
        }
      }

      // Calculate lowest fee if not set
      if (libraryModel.lowFee == null) {
        libraryModel.lowFee = libraryModel.calculateLowestFee();
      }

      // Prepare library data
      final libraryData = libraryModel.toMap();

      // Explicitly log the openingHours data for debugging

      // Store library data in Firestore
      await _firestore.collection('libraries')
          .doc(libraryId)
          .set(libraryData);


      // Process shifts for seat generation
      final Map<String, dynamic> shiftsMap = libraryModel.shifts;

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
      rethrow;
    }
  }
  Future<File?> _compressImage(File file) async {
    try {
      // Create a temp file for compressed output
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Initial compression quality
      int quality = 85;
      File? result;

      // Try progressive compression until file size is under 100KB or quality gets too low
      while (quality >= 20) {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          quality: quality,
          minWidth: 800,
          minHeight: 450,
        );

        if (compressedBytes != null) {
          // Write compressed bytes to file
          result = File(targetPath);
          await result.writeAsBytes(compressedBytes);

          final fileSize = await result.length();

          // If under 100KB, we're good
          if (fileSize <= 100 * 1024) {
            return result;
          }

          // If still too large, reduce quality and try again
          quality -= 15;
        } else {
          break; // Compression failed
        }
      }

      // If we couldn't get it under 100KB, use the smallest version we got
      if (result != null && await result.exists()) {
        final fileSize = await result.length();
        if (fileSize > 100 * 1024) {
        }
        return result;
      }

      return null;
    } catch (e) {
      return null;
    }
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

    } catch (e) {
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

  //edit library details function
  Future<void> editLibraryDetails(String libraryId, LibraryModel updatedLibraryModel, File? imageFile) async {
    try {
      // Update library details in Firestore
      final libraryRef = _firestore.collection('libraries').doc(libraryId);

      // Upload new image if provided
      if (imageFile != null) {
        final fileName = 'library_images/${libraryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = _storage.ref().child(fileName);
        await storageRef.putFile(imageFile);
        final downloadUrl = await storageRef.getDownloadURL();
        updatedLibraryModel.libraryImageUrl = downloadUrl;
      }

      // Update the library document with new data
      await libraryRef.update(updatedLibraryModel.toMap());

    } catch (e) {
      rethrow;
    }
  }
}