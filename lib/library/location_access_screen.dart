import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../function/student_function.dart';
import '../models/library_model.dart';
import '../theme/theme.dart';
import '../widgets/solid_button.dart';
import 'upload_picture_screen.dart';

class LocationAccessScreen extends StatefulWidget {
  final LibraryModel libraryModel;

  const LocationAccessScreen({super.key, required this.libraryModel});

  @override
  State<LocationAccessScreen> createState() => _LocationAccessScreenState();
}

class _LocationAccessScreenState extends State<LocationAccessScreen> {
  bool _isLoading = false;
  bool _locationObtained = false;
  String _address = "";
  double _latitude = 0.0;
  double _longitude = 0.0;

  @override
  void initState() {
    super.initState();
    // Check if the library already has location data
    _checkExistingLocation();
    // Request location permission when the screen opens
    _requestLocationPermission();
  }

  Future<void> _checkExistingLocation() async {
    if (widget.libraryModel.locationLatitude != null &&
        widget.libraryModel.locationLongitude != null &&
        widget.libraryModel.locationLatitude!.isNotEmpty &&
        widget.libraryModel.locationLongitude!.isNotEmpty) {

      double lat = double.tryParse(widget.libraryModel.locationLatitude!) ?? 0;
      double lng = double.tryParse(widget.libraryModel.locationLongitude!) ?? 0;

      if (lat != 0 && lng != 0) {
        setState(() {
          _locationObtained = true;
          _latitude = lat;
          _longitude = lng;
        });

        // Get address for the coordinates
        _getAddressFromCoordinates(lat, lng);
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  // Get current position
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location services are disabled. Please enable location services."))
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Check for permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permissions are denied. Please grant permission to use this feature."))
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Location permissions are permanently denied. Please enable them in app settings."),
              duration: Duration(seconds: 5),
            )
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get the current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      // Successfully got position
      double lat = position.latitude;
      double lng = position.longitude;

      setState(() {
        _locationObtained = true;
        widget.libraryModel.locationLatitude = lat.toString();
        widget.libraryModel.locationLongitude = lng.toString();
        _latitude = lat;
        _longitude = lng;
      });

      // Get address for the coordinates
      _getAddressFromCoordinates(lat, lng);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: ${e.toString()}"))
      );
      print("Error getting location: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String street = place.street ?? '';
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        String postalCode = place.postalCode ?? '';
        String country = place.country ?? '';

        // Create a properly formatted address
        List<String> addressParts = [];
        if (street.isNotEmpty) addressParts.add(street);
        if (subLocality.isNotEmpty) addressParts.add(subLocality);
        if (locality.isNotEmpty) addressParts.add(locality);
        if (postalCode.isNotEmpty) addressParts.add(postalCode);
        if (country.isNotEmpty) addressParts.add(country);

        setState(() {
          _address = addressParts.join(", ");
        });
      }
    } catch (e) {
      print("Error getting address: $e");
    }
  }

  void _proceedToNextPage() {
    if (_locationObtained) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadPictureScreen(libraryModel: widget.libraryModel),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a location before proceeding")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Library Location",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Getting location...",
                style: TextStyle(color: Colors.white),
              )
            ],
          ),
        )
            : Column(
          children: [
            // Location Preview Box (replacing the map)
            Container(
              height: h * 0.25,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DarkColor.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DarkColor.borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: _locationObtained ? DarkColor.highlightColor : Colors.grey,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _locationObtained
                        ? "Location Selected"
                        : "No Location Selected",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_locationObtained) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Coordinates: $_latitude, $_longitude",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // Location details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Status indicator
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _locationObtained ? Colors.green : DarkColor.borderColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _locationObtained ? Icons.check : Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _locationObtained ? "Location Selected" : "Select Location",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_locationObtained) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Lat: ${_latitude.toStringAsFixed(6)}, Lng: ${_longitude.toStringAsFixed(6)}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Address display
                    if (_locationObtained && _address.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: DarkColor.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: DarkColor.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.home, size: 20, color: DarkColor.highlightColor),
                                SizedBox(width: 8),
                                Text(
                                  "Address",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _address,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DarkColor.highlightColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: DarkColor.highlightColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: DarkColor.highlightColor.withOpacity(0.8),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Location Information",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "• Use the Get Current Location button to detect your position\n"
                                "• Precise location helps students find your library easier\n"
                                "• Your library will appear on the app's search map\n"
                                "• Location accuracy may vary based on your device",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    SolidButton(
                      text: "Get Current Location",
                      width: double.infinity,
                      height: 50,
                      onPressed: _getCurrentLocation,
                      buttonColor: DarkColor.cardColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SolidButton(
          text: "Next",
          width: double.infinity,
          height: 52,
          onPressed: _proceedToNextPage,
          buttonColor: _locationObtained ? DarkColor.primary : null,
        ),
      ),
    );
  }
}