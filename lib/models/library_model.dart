import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryModel {
  String? id;
  String? librarianId;
  String? libraryName;
  String? establishedDate;
  String? ownerName;
  String? location;
  String? locationLatitude;
  String? locationLongitude;

  // Fields for structure
  Map<String, dynamic>? address;
  Map<String, dynamic>? contactInfo;

  int? totalSeats;
  int? availableSeats;
  String? description;
  List<String> rules;
  File? libraryImage;
  String? libraryImageUrl;
  String? tag;

  // Utilities list
  List<String> utilities;

  // Enhanced shift model
  List<ShiftModel> shifts;
  int? lowFee;

  // Timestamp fields
  //String? createdAt;

  // Additional properties for marketplace features
  String status;
  double rating;
  int reviews;
  int students;

  LibraryModel({
    this.id,
    this.librarianId,
    this.libraryName,
    this.establishedDate,
    this.ownerName,
    this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.address,
    this.contactInfo,
    this.totalSeats,
    this.availableSeats,
    this.description,
    this.rules = const [],
    this.libraryImage,
    this.libraryImageUrl,
    this.shifts = const [],
    this.lowFee,
    //this.createdAt,
    this.tag,
    this.utilities = const [], // Add utilities with default empty list
    this.status = 'active', // Default status
    this.rating = 0.0, // Default rating
    this.reviews = 0, // Default reviews count
    this.students = 0, // Default students count
  });

  // Method to convert to Firebase map
  Map<String, dynamic> toMap() {
    // Convert shifts to maps
    final List<Map<String, dynamic>> shiftsMapList =
        shifts.map((shift) => shift.toMap()).toList();

    // Get current timestamp for created/updated fields
    final timestamp = DateTime.now().toIso8601String();

    return {
      'id': id,
      'librarianId': librarianId,
      'libraryName': libraryName,
      'establishedDate': establishedDate,
      'ownerName': ownerName,
      'location': location,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'address': address ?? {},
      'contactInfo': contactInfo ?? {},
      'totalSeats': totalSeats,
      'availableSeats': availableSeats ?? totalSeats, // Default to total seats
      'description': description,
      'rules': rules,
      'libraryImageUrl': libraryImageUrl,
      'shifts': shiftsMapList,
      'lowFee': lowFee,
      'tag': tag,
      'utilities': utilities,
      // 'createdAt': createdAt ?? timestamp,
      // Additional properties
      'status': status,
      'rating': rating,
      'reviews': reviews,
      'students': students,
    };
  }

  // Factory method to create from Firebase
  factory LibraryModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    // Convert shifts data
    final List<ShiftModel> shiftsList = [];
    if (map['shifts'] != null) {
      for (var item in map['shifts']) {
        shiftsList.add(ShiftModel.fromMap(item));
      }
    }

    // Handle rating - could be int, double or missing
    double ratingValue = 0.0;
    if (map['rating'] != null) {
      if (map['rating'] is int) {
        ratingValue = (map['rating'] as int).toDouble();
      } else if (map['rating'] is double) {
        ratingValue = map['rating'] as double;
      }
    }

    return LibraryModel(
      id: docId ?? map['id'],
      tag: map['tag'],
      librarianId: map['librarianId'],
      libraryName: map['libraryName'],
      establishedDate: map['establishedDate'],
      ownerName: map['ownerName'],
      location: map['location'],
      locationLatitude: map['locationLatitude']?.toString(),
      locationLongitude: map['locationLongitude']?.toString(),
      address:
          map['address'] != null
              ? Map<String, dynamic>.from(map['address'])
              : null,
      contactInfo:
          map['contactInfo'] != null
              ? Map<String, dynamic>.from(map['contactInfo'])
              : null,
      totalSeats: map['totalSeats'],
      availableSeats: map['availableSeats'],
      description: map['description'],
      rules: map['rules'] != null ? List<String>.from(map['rules']) : [],
      libraryImageUrl: map['libraryImageUrl'],
      shifts: shiftsList,
      lowFee: map['lowFee'],
      //createdAt: map['createdAt'],
      utilities:
          map['utilities'] != null ? List<String>.from(map['utilities']) : [],
      // Additional properties
      status: map['status'] ?? 'active',
      rating: ratingValue,
      reviews: map['reviews'] ?? 0,
      students: map['students'] ?? 0,
    );
  }
}

// ShiftModel class (unchanged)
class ShiftModel {
  String? shiftName;
  String? startTime;
  String? endTime;
  int? fee;

  ShiftModel({this.shiftName, this.startTime, this.endTime, this.fee});

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      shiftName: map['shiftName'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      fee: map['fee'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shiftName': shiftName,
      'startTime': startTime,
      'endTime': endTime,
      'fee': fee,
    };
  }
}

class LibraryUtility {
  final String id;
  final String name;
  final IconData icon;
  bool isSelected;

  LibraryUtility({
    required this.id,
    required this.name,
    required this.icon,
    this.isSelected = false,
  });
}

class LibraryUtilities {
  // Predefined list of common utilities
  static final List<LibraryUtility> predefinedUtilities = [
    LibraryUtility(id: 'wifi', name: 'WiFi', icon: Icons.wifi),
    LibraryUtility(id: 'cctv', name: 'CCTV', icon: Icons.videocam),
    LibraryUtility(id: 'water', name: 'RO Water', icon: Icons.water_drop),
    LibraryUtility(id: 'ac', name: 'Air Conditioning', icon: Icons.ac_unit),
    LibraryUtility(id: 'printer', name: 'Printer', icon: Icons.print),
    LibraryUtility(id: 'scanner', name: 'Scanner', icon: Icons.scanner),
    LibraryUtility(id: 'locker', name: 'Lockers', icon: Icons.lock),
    LibraryUtility(id: 'cafe', name: 'Cafeteria', icon: Icons.local_cafe),
    LibraryUtility(id: 'parking', name: 'Parking', icon: Icons.local_parking),
    LibraryUtility(id: 'charging', name: 'Charging Points', icon: Icons.power),
  ];
}
