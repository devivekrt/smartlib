import 'dart:io';

class LibraryModel {
  String? librarianId;
  String? libraryName;
  String? establishedDate;
  String? ownerName;
  String? location;
  String? locationLatitude;
  String? locationLongitude;
  int? seats;
  String? description;
  List<String> rules;
  File? libraryImage;

  LibraryModel({
    this.librarianId,
    this.libraryName,
    this.establishedDate,
    this.ownerName,
    this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.seats,
    this.description,
    this.rules = const [],
    this.libraryImage,
  });

  // Method to convert to Firebase map
  Map<String, dynamic> toMap() {
    return {
      'librarianId': librarianId,
      'libraryName': libraryName,
      'establishedDate': establishedDate,
      'ownerName': ownerName,
      'location': location,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'seats': seats,
      'description': description,
      'rules': rules,
      // Image will be uploaded separately
    };
  }
}