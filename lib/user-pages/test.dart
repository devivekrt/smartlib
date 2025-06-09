import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> {
  bool _locationObtained =false;
  bool _isLoading = false;

  Future<List<String>> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    String locationLatitude = "";
    String locationLongitude = "";

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Consider opening location settings instead of just failing
        await Geolocator.openLocationSettings();
        throw 'Location services are disabled';
      }

      // Request permission with proper flow
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Consider opening app settings to let user enable permissions
        await Geolocator.openAppSettings();
        throw 'Location permissions are permanently denied';
      }

      // Get current position with improved accuracy
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15)
      );

      // Update library model with coordinates
      locationLatitude = position.latitude.toString();
      locationLongitude = position.longitude.toString();

      setState(() {
        _locationObtained = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location successfully captured!"),
          duration: Duration(seconds: 2),
        ),
      );

      return [locationLatitude, locationLongitude];
    } catch (e) {
      setState(() => _isLoading = false);

      // More informative error message with action
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error accessing location: ${e.toString()}"),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _getCurrentLocation(),
          ),
          duration: Duration(seconds: 5),
        ),
      );

      return [locationLatitude, locationLongitude];
    }
  }
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
