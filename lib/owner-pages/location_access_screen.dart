import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../function/users_function.dart';
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
  List<String> location = [];

  // Controllers for manual location entry
  final TextEditingController _manualLatController = TextEditingController();
  final TextEditingController _manualLngController = TextEditingController();

  Future<void> _getCurrentLocation() async {
    location = await AuthFunctions.getCurrentLocation(context, (isLoading) {
      setState(() {
        _isLoading = isLoading;
      });
    },);

    if (location.isNotEmpty && location.length >= 2) {
      setState(() {
        _locationObtained = true;
        widget.libraryModel.locationLatitude = location[0];
        widget.libraryModel.locationLongitude = location[1];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to get location coordinates. Please try again or enter manually."))
      );
    }
  }

  void _openManualLocationDialog() {
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
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualLngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. 77.1025',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                setState(() {
                  _locationObtained = true;
                  widget.libraryModel.locationLatitude = lat;
                  widget.libraryModel.locationLongitude = lng;
                });
                Navigator.pop(context);
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
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            SizedBox(height: h / 12),

            // Main Body
            Expanded(
              child: Column(
                children: [
                  // Location Icon with status indicator
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: DarkColor.cardColor,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(30),
                        child: Icon(
                          Icons.location_on,
                          color: _locationObtained
                              ? Colors.green
                              : DarkColor.highlightColor,
                          size: 100,
                        ),
                      ),
                      if (_locationObtained)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DarkColor.cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DarkColor.secondary,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 30,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Title
                  Text(
                    _locationObtained
                        ? "Location Captured!"
                        : "Library Location?",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _locationObtained
                          ? "Your library's location has been successfully recorded."
                          : "Allow location or select your library on the map",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Show coordinates if location obtained
                  if (_locationObtained) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Latitude: ${widget.libraryModel.locationLatitude}",
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Longitude: ${widget.libraryModel.locationLongitude}",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Allow Location Access Button
                  SolidButton(
                    text: _locationObtained
                        ? "Update Location"
                        : "Allow Location Access",
                    width: w * 0.8,
                    height: 50,
                    onPressed: _getCurrentLocation,
                    buttonColor: _locationObtained
                        ? Colors.green
                        : DarkColor.highlightColor,
                  ),

                  const SizedBox(height: 20),

                  // Enter Manually - Now functional
                  GestureDetector(
                    onTap: _openManualLocationDialog,
                    child: const Text(
                      "Enter Location Manually",
                      style: TextStyle(color: DarkColor.highlightColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          height: 48,
          child: SolidButton(
            text: "Next",
            width: double.infinity,
            height: 48,
            onPressed: _proceedToNextPage,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manualLatController.dispose();
    _manualLngController.dispose();
    super.dispose();
  }
}