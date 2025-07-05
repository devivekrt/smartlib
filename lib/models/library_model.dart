// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'dart:io';
import 'package:flutter/material.dart';

class LibraryModel {
  String? id;
  String? librarianId;
  String? libraryName;
  String? establishedDate;
  String? ownerName;
  String? location;
  String? locationLatitude;
  String? locationLongitude;
  Map<String, dynamic>? address;
  Map<String, dynamic>? contactInfo;
  int? totalSeats;
  int? availableSeats;
  String? description;
  List<String> rules;
  File? libraryImage;
  String? libraryImageUrl;
  String? tag;
  String? libraryType;
  List<String> utilities;
  Map<String, dynamic> shifts;
  int? lowFee;
  Map<String, dynamic>? openingHours;
  String status;
  double rating;
  int reviews;
  int students;
  bool? canReview;
  //Timestamp
   DateTime? createdAt;

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
    Map<String, dynamic>? shifts,
    this.lowFee,
    this.libraryType,
    this.openingHours,
    this.tag,
    this.utilities = const [],
    this.status = 'active',
    this.canReview ,
    this.rating = 0.0,
    this.reviews = 0,
    this.students = 0,
    this.createdAt,
  }) : shifts = shifts ?? {};




  // Find the lowest fee among all shifts
  int calculateLowestFee() {
    if (shifts.isEmpty) return 0;

    int? lowest;

    shifts.forEach((_, shiftData) {
      if (shiftData is Map) {
        int fee;

        // Handle different fee field names that might exist in the data
        if (shiftData.containsKey('shiftFee')) {
          fee = shiftData['shiftFee'] is int
              ? shiftData['shiftFee']
              : int.tryParse(shiftData['shiftFee'].toString()) ?? 0;
        } else if (shiftData.containsKey('fee')) {
          fee = shiftData['fee'] is int
              ? shiftData['fee']
              : int.tryParse(shiftData['fee'].toString()) ?? 0;
        } else {
          fee = 0;
        }

        if (lowest == null || fee < lowest!) {
          lowest = fee;
        }
      }
    });

    return lowest ?? 0;
  }

  // Method to convert to Firebase map
  Map<String, dynamic> toMap() {
    // Ensure lowFee is calculated before saving
    if (lowFee == null) {
      lowFee = calculateLowestFee();
    }

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
      'availableSeats': availableSeats ?? totalSeats,
      'description': description,
      'rules': rules,
      'libraryImageUrl': libraryImageUrl,
      'shifts': shifts,
      'openingHours': openingHours ?? {},
      'lowFee': lowFee,
      'tag': tag,
      'libraryType': libraryType,
      'utilities': utilities,
      'status': status,
      'rating': rating,
      'reviews': reviews,
      'students': students,
      'canReview': canReview ?? false,
      'createdAt': createdAt ?? DateTime.now().toIso8601String() ,
    };
  }

  // Factory method to create from Firebase
  factory LibraryModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    // Handle shifts data
    Map<String, dynamic> shiftsMap = {};

    // Process shifts based on format found in the data
    if (map['shifts'] != null) {
      if (map['shifts'] is Map) {
        shiftsMap = Map<String, dynamic>.from(map['shifts']);
      } else if (map['shifts'] is List) {
        final List<dynamic> shiftsList = map['shifts'];
        for (int i = 0; i < shiftsList.length; i++) {
          final shift = shiftsList[i];
          final String shiftKey;

          if (shift['shiftName'] != null && shift['shiftName'].toString().isNotEmpty) {
            shiftKey = shift['shiftName'].toString().toLowerCase().replaceAll(' ', '_');
          } else {
            switch (i) {
              case 0: shiftKey = 'morning'; break;
              case 1: shiftKey = 'afternoon'; break;
              case 2: shiftKey = 'evening'; break;
              case 3: shiftKey = 'night'; break;
              default: shiftKey = shift['shiftName'].toString().toLowerCase();
            }
          }

          shiftsMap[shiftKey] = {
            'shiftName': shift['shiftName'] ?? 'Shift ${i+1}',
            'shiftStartTime': shift['shiftStartTime'] ?? '00:00',
            'shiftEndTime': shift['shiftEndTime'] ?? '00:00',
            'shiftFee': shift['shiftFee'] ?? 0,
          };
        }
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
      address: map['address'] != null ? Map<String, dynamic>.from(map['address']) : null,
      contactInfo: map['contactInfo'] != null ? Map<String, dynamic>.from(map['contactInfo']) : null,
      totalSeats: map['totalSeats'],
      availableSeats: map['availableSeats'],
      description: map['description'],
      rules: map['rules'] != null ? List<String>.from(map['rules']) : [],
      libraryImageUrl: map['libraryImageUrl'],
      libraryType: map['libraryType'] ?? 'self_study',
      shifts: shiftsMap,
      openingHours: map['openingHours'],
      lowFee: map['lowFee'],
      utilities: map['utilities'] != null ? List<String>.from(map['utilities']) : [],
      status: map['status'] ?? 'active',
      rating: ratingValue,
      reviews: map['reviews'] ?? 0,
      students: map['students'] ?? 0,
      canReview: false,

    );
  }
}

//opening hours model
class OpeningHoursModel {
  String? day;
  String? openTime;
  String? closeTime;
}

class ShiftModel {
  String? shiftName;
  String? startTime;
  String? endTime;
  int? fee;

  ShiftModel({this.shiftName, this.startTime, this.endTime, this.fee});

  Map<String, dynamic> toMap() {
    return {
      'shiftName': shiftName,
      'shiftStartTime': startTime,
      'shiftEndTime': endTime,
      'shiftFee': fee,
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
  static final List<LibraryUtility> predefinedUtilities = [
    LibraryUtility(id: 'wifi', name: 'WiFi', icon: Icons.wifi),
    LibraryUtility(id: 'cctv', name: 'CCTV', icon: Icons.videocam),
    LibraryUtility(id: 'water', name: 'RO Water', icon: Icons.water_drop),
    LibraryUtility(id: 'ac', name: 'AC', icon: Icons.ac_unit),
    LibraryUtility(id: 'printer', name: 'Printer', icon: Icons.print),
    LibraryUtility(id: 'scanner', name: 'Scanner', icon: Icons.scanner),
    LibraryUtility(id: 'locker', name: 'Lockers', icon: Icons.lock),
    LibraryUtility(id: 'cafe', name: 'Cafeteria', icon: Icons.local_cafe),
    LibraryUtility(id: 'parking', name: 'Parking', icon: Icons.local_parking),
    LibraryUtility(id: 'charging', name: 'Charging Points', icon: Icons.power),
  ];
}