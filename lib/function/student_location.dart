// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-29 09:27:40
// Current User's Login: devivekrt

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class StudentLocationService {
  // Singleton pattern implementation
  static final StudentLocationService _instance = StudentLocationService._internal();
  factory StudentLocationService() => _instance;
  StudentLocationService._internal();

  // Location data
  double? _latitude;
  double? _longitude;
  String? _address;
  DateTime? _lastUpdated;
  bool _isTracking = false;

  // Streams and controllers
  StreamSubscription<Position>? _positionStream;
  Timer? _locationUpdateTimer;
  final _locationUpdateController = StreamController<LocationData>.broadcast();

  // Configuration
  final int _locationUpdateIntervalMinutes = 5; // Update every 5 minutes
  final int _locationStaleMinutes = 15; // Consider location stale after 15 minutes
  final int _significantDistanceMeters = 20; // Update if moved 20+ meters

  // Getters
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get address => _address;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isLocationAvailable => _latitude != null && _longitude != null;
  bool get isStale => _lastUpdated == null ||
      DateTime.now().difference(_lastUpdated!).inMinutes > _locationStaleMinutes;
  Stream<LocationData> get locationUpdates => _locationUpdateController.stream;

  // Initialize the service
  Future<bool> initialize() async {
    try {
      print('[2025-06-29 09:27:40] devivekrt: Initializing StudentLocationService');

      // Try to load saved location data first
      await _loadSavedLocation();

      // If location is stale or not available, request a fresh location
      if (isStale) {
        print('[2025-06-29 09:27:40] devivekrt: Stored location is stale, getting fresh location');
        await requestSingleLocationUpdate();
      }

      return isLocationAvailable;
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error initializing StudentLocationService: $e');
      return false;
    }
  }

  // Load location from shared preferences
  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final latString = prefs.getString('user_latitude');
      final lngString = prefs.getString('user_longitude');
      final lastUpdatedString = prefs.getString('location_updated');
      final addressString = prefs.getString('user_address');

      if (latString != null && lngString != null) {
        _latitude = double.tryParse(latString);
        _longitude = double.tryParse(lngString);
        _address = addressString;

        if (lastUpdatedString != null) {
          _lastUpdated = DateTime.parse(lastUpdatedString);
        }

        print('[2025-06-29 09:27:40] devivekrt: Loaded location from storage: $_latitude, $_longitude (last updated: $_lastUpdated)');
      }
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error loading saved location: $e');
    }
  }

  // Save location to shared preferences
  Future<void> _saveLocationToPreferences() async {
    if (_latitude == null || _longitude == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('user_latitude', _latitude.toString());
      await prefs.setString('user_longitude', _longitude.toString());

      if (_lastUpdated != null) {
        await prefs.setString('location_updated', _lastUpdated!.toIso8601String());
      }

      if (_address != null) {
        await prefs.setString('user_address', _address!);
      }

      print('[2025-06-29 09:27:40] devivekrt: Saved location to preferences: $_latitude, $_longitude');
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error saving location to preferences: $e');
    }
  }

  // Request a single location update
  Future<LocationData?> requestSingleLocationUpdate({bool highAccuracy = true}) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[2025-06-29 09:27:40] devivekrt: Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[2025-06-29 09:27:40] devivekrt: Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[2025-06-29 09:27:40] devivekrt: Location permission permanently denied');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      // Update stored values
      _latitude = position.latitude;
      _longitude = position.longitude;
      _lastUpdated = DateTime.now();

      // Try to get address
      await _updateAddress();

      // Save to preferences
      await _saveLocationToPreferences();

      // Create location data object
      final locationData = LocationData(
        latitude: _latitude!,
        longitude: _longitude!,
        timestamp: _lastUpdated!,
        address: _address,
      );

      // Notify listeners
      _locationUpdateController.add(locationData);

      print('[2025-06-29 09:27:40] devivekrt: Updated location: $_latitude, $_longitude');
      return locationData;
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error updating location: $e');
      return null;
    }
  }

  // Get address from coordinates
  Future<void> _updateAddress() async {
    if (_latitude == null || _longitude == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(_latitude!, _longitude!);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }

        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }

        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }

        _address = addressParts.join(", ");
        print('[2025-06-29 09:27:40] devivekrt: Updated address: $_address');
      }
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error getting address: $e');
    }
  }

  // Start continuous location tracking
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    try {
      print('[2025-06-29 09:27:40] devivekrt: Starting location tracking');

      // Check permissions and get initial position
      final initialLocation = await requestSingleLocationUpdate();
      if (initialLocation == null) {
        print('[2025-06-29 09:27:40] devivekrt: Failed to get initial location');
        return false;
      }

      // Start tracking with position stream
      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _significantDistanceMeters,
        ),
      ).listen(_handlePositionUpdate);

      // Also set up a periodic timer for regular updates
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(
          Duration(minutes: _locationUpdateIntervalMinutes),
              (_) => requestSingleLocationUpdate(highAccuracy: false)
      );

      _isTracking = true;
      return true;
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error starting location tracking: $e');
      return false;
    }
  }

  // Handle position updates from the stream
  void _handlePositionUpdate(Position position) {
    _latitude = position.latitude;
    _longitude = position.longitude;
    _lastUpdated = DateTime.now();

    _updateAddress().then((_) {
      _saveLocationToPreferences();

      // Notify listeners
      final locationData = LocationData(
        latitude: _latitude!,
        longitude: _longitude!,
        timestamp: _lastUpdated!,
        address: _address,
      );

      _locationUpdateController.add(locationData);
    });
  }

  // Stop tracking
  void stopTracking() {
    print('[2025-06-29 09:27:40] devivekrt: Stopping location tracking');
    _positionStream?.cancel();
    _locationUpdateTimer?.cancel();
    _isTracking = false;
  }

  // Check if user is within a certain distance of a location
  Future<bool> isWithinRange({
    required double targetLatitude,
    required double targetLongitude,
    required double radiusMeters,
    bool updateLocationIfStale = true
  }) async {
    // If location is stale or not available, try to update it
    if ((isStale || !isLocationAvailable) && updateLocationIfStale) {
      await requestSingleLocationUpdate();
    }

    // If still no location, return false
    if (!isLocationAvailable) return false;

    try {
      // Calculate distance
      double distanceInMeters = Geolocator.distanceBetween(
          _latitude!, _longitude!, targetLatitude, targetLongitude
      );

      print('[2025-06-29 09:27:40] devivekrt: Distance to target: ${distanceInMeters.toStringAsFixed(2)}m, Required: ${radiusMeters}m');

      return distanceInMeters <= radiusMeters;
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error calculating distance: $e');
      return false;
    }
  }

  // Calculate distance between current location and a target
  double? calculateDistanceInKm(double targetLat, double targetLng) {
    if (!isLocationAvailable) return null;

    try {
      double distanceInMeters = Geolocator.distanceBetween(
          _latitude!, _longitude!, targetLat, targetLng
      );

      return distanceInMeters / 1000; // Convert to kilometers
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error calculating distance: $e');
      return null;
    }
  }

  // Clear location data
  Future<void> clearLocationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_latitude');
      await prefs.remove('user_longitude');
      await prefs.remove('location_updated');
      await prefs.remove('user_address');

      _latitude = null;
      _longitude = null;
      _address = null;
      _lastUpdated = null;

      print('[2025-06-29 09:27:40] devivekrt: Cleared location data');
    } catch (e) {
      print('[2025-06-29 09:27:40] devivekrt: Error clearing location data: $e');
    }
  }

  // Dispose resources
  void dispose() {
    stopTracking();
    _locationUpdateController.close();
  }

  // Get formatted location string
  String getFormattedLocationString() {
    if (!isLocationAvailable) return "Location unavailable";

    final lat = _latitude!.toStringAsFixed(6);
    final lng = _longitude!.toStringAsFixed(6);
    final updated = _lastUpdated != null ?
    DateFormat('HH:mm, MMM d').format(_lastUpdated!) : "unknown";

    return "Lat: $lat, Lng: $lng (Updated: $updated)";
  }
}

// Data class for location updates
class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
  });
}

// Extension for using the service with BuildContext
extension LocationServiceExtension on BuildContext {
  StudentLocationService get locationService => StudentLocationService();
}