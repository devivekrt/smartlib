import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  // Controllers for manual location entry
  final TextEditingController _manualLatController = TextEditingController();
  final TextEditingController _manualLngController = TextEditingController();

  // Google Maps Controller
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng _initialPosition = const LatLng(28.7041, 77.1025); // Default to Delhi, India

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
          _initialPosition = LatLng(lat, lng);
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

  // Direct implementation to get current position
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
        _initialPosition = LatLng(lat, lng);
      });

      // Update map position
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 15));
        _updateMarker(_initialPosition);
      }

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

  void _updateMarker(LatLng position) {
    setState(() {
      _markers = {};
      _markers.add(
        Marker(
          markerId: const MarkerId('libraryLocation'),
          position: position,
          infoWindow: const InfoWindow(title: 'Library Location'),
          draggable: true,
          onDragEnd: (newPosition) {
            _onMapPositionChanged(newPosition);
          },
        ),
      );
    });
  }

  void _onMapPositionChanged(LatLng position) {
    setState(() {
      _initialPosition = position;
      widget.libraryModel.locationLatitude = position.latitude.toString();
      widget.libraryModel.locationLongitude = position.longitude.toString();
      _locationObtained = true;
    });

    // Get address for new position
    _getAddressFromCoordinates(position.latitude, position.longitude);
  }

  void _openManualLocationDialog() {
    // Pre-fill with existing data if available
    if (_locationObtained) {
      _manualLatController.text = widget.libraryModel.locationLatitude ?? '';
      _manualLngController.text = widget.libraryModel.locationLongitude ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DarkColor.cardColor,
        title: const Text(
          "Enter Location Manually",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _manualLatController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 28.7041',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualLngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. 77.1025',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              // Validate and save manual location
              final lat = _manualLatController.text;
              final lng = _manualLngController.text;

              if (lat.isNotEmpty && lng.isNotEmpty) {
                double? latitude = double.tryParse(lat);
                double? longitude = double.tryParse(lng);

                if (latitude != null && longitude != null &&
                    latitude >= -90 && latitude <= 90 &&
                    longitude >= -180 && longitude <= 180) {
                  setState(() {
                    _locationObtained = true;
                    widget.libraryModel.locationLatitude = lat;
                    widget.libraryModel.locationLongitude = lng;
                    _initialPosition = LatLng(latitude, longitude);
                  });

                  // Update map
                  if (_mapController != null) {
                    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 15));
                    _updateMarker(_initialPosition);
                  }

                  // Get address
                  _getAddressFromCoordinates(latitude, longitude);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter valid latitude and longitude values"))
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter both latitude and longitude"))
                );
              }
            },
            child: const Text(
              "Save",
              style: TextStyle(color: DarkColor.highlightColor),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToNextPage() {
    // We can proceed without location, but we'll set a message if it wasn't obtained
    if (!_locationObtained) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proceeding without library location")),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadPictureScreen(libraryModel: widget.libraryModel),
      ),
    );
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
            // Map View
            Container(
              height: h * 0.35,
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DarkColor.borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition,
                        zoom: 15,
                      ),
                      markers: _markers,
                      mapType: MapType.normal,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: (controller) {
                        setState(() {
                          _mapController = controller;

                          // Apply dark theme styling to the map
                          _mapController!.setMapStyle('''[
                            {
                              "elementType": "geometry",
                              "stylers": [{"color": "#212121"}]
                            },
                            {
                              "elementType": "labels.text.fill",
                              "stylers": [{"color": "#757575"}]
                            },
                            {
                              "elementType": "labels.text.stroke",
                              "stylers": [{"color": "#212121"}]
                            },
                            {
                              "featureType": "administrative",
                              "elementType": "geometry",
                              "stylers": [{"color": "#757575"}]
                            }
                          ]''');
                        });

                        // Add marker if location is already selected
                        if (_locationObtained) {
                          _updateMarker(_initialPosition);
                        }
                      },
                      onTap: (position) {
                        _onMapPositionChanged(position);
                      },
                    ),

                    // Map controls
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: DarkColor.highlightColor,
                              shape: BoxShape.circle,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: IconButton(
                              icon: const Icon(Icons.my_location, color: Colors.white),
                              onPressed: _getCurrentLocation,
                              tooltip: "Get Current Location",
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: DarkColor.cardColor.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                if (_mapController != null) {
                                  _mapController!.animateCamera(CameraUpdate.zoomIn());
                                }
                              },
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: DarkColor.cardColor.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            margin: const EdgeInsets.only(top: 8),
                            child: IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white),
                              onPressed: () {
                                if (_mapController != null) {
                                  _mapController!.animateCamera(CameraUpdate.zoomOut());
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map Instructions
                    if (!_locationObtained)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: DarkColor.highlightColor.withOpacity(0.8),
                          child: const Text(
                            "Tap on the map to select location or use the location button",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
                                  "Lat: ${widget.libraryModel.locationLatitude}, Lng: ${widget.libraryModel.locationLongitude}",
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
                                "Location Options",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "• Tap directly on the map to select location\n"
                                "• Use the current location button\n"
                                "• Enter coordinates manually\n"
                                "• Drag the marker to fine-tune position",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: SolidButton(
                            text: "Get Current",
                            width: double.infinity,
                            height: 45,
                            onPressed: _getCurrentLocation,
                            buttonColor: DarkColor.cardColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SolidButton(
                            text: "Enter Manually",
                            width: double.infinity,
                            height: 45,
                            onPressed: _openManualLocationDialog,
                            buttonColor: DarkColor.cardColor,
                          ),
                        ),
                      ],
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

  @override
  void dispose() {
    _manualLatController.dispose();
    _manualLngController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}