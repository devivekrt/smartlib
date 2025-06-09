import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:smartlib/logic/string.dart';
import 'package:smartlib/user-pages/library_market_place.dart';
import '../models/library_model.dart';
import '../theme/theme.dart';
import '../user-pages/market_place.dart';
import '../widgets/solid_button.dart';

class UploadPictureScreen extends StatefulWidget {
  final LibraryModel libraryModel;

  const UploadPictureScreen({
    super.key,
    required this.libraryModel,
  });

  @override
  State<UploadPictureScreen> createState() => _UploadPictureScreenState();
}

class _UploadPictureScreenState extends State<UploadPictureScreen> {
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        widget.libraryModel.libraryImage = _imageFile;
      });
    }
  }

  Future<void> _uploadLibraryData() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload a library image")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate a unique library ID
      final String libraryId = widget.libraryModel.tag ?? "LIB_${DateTime.now().millisecondsSinceEpoch}";
      widget.libraryModel.id = libraryId;

      // 1. Upload image to Firebase Storage
     /* final fileName = 'library_images/${libraryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      await storageRef.putFile(_imageFile!);
      final downloadUrl = await storageRef.getDownloadURL();
      widget.libraryModel.libraryImageUrl = downloadUrl;*/

      // Set default values for status, rating, etc. if not already set
      widget.libraryModel.status = 'active';
      widget.libraryModel.rating = 0;
      widget.libraryModel.reviews = 0;
      widget.libraryModel.students = 0;
      //widget.libraryModel.createdAt = DateTime.now().toString();

      // 2. Prepare library data
      final libraryData = widget.libraryModel.toMap();

      // 3. Store complete library data in Firestore
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .set(libraryData); // Now libraryData already includes all necessary fields

      // 4. Store the librarian-library relationship in Realtime DB
      // This is the key part that connects the library to the librarian
      await FirebaseDatabase.instance
          .ref('${SmartLib.constPath}/librarians/${widget.libraryModel.librarianId}/managedLibraries')
          .child(libraryId)
          .set(true);

      // 5. Setup initial seat status data
      await FirebaseDatabase.instance
          .ref('users/seats-status/${libraryId}')
          .set({
        'totalSeats': widget.libraryModel.totalSeats,
        'availableSeats': widget.libraryModel.totalSeats,
      });

      // Success! Show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Library setup completed successfully!")),
      );

      // Navigate to market place or dashboard
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LibraryMarketplace(isSignedUp: true)),
              (route) => false,
        );
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading data: ${e.toString()}")),
      );
      print("Error in _uploadLibraryData: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    final libraryName = widget.libraryModel.libraryName ?? "Your Library";
    final lowFee = widget.libraryModel.lowFee != null ?
    "₹${widget.libraryModel.lowFee}" : "₹499"; // Default value

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Upload Picture', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Setting up your library...",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Upload Card
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 45),
                decoration: BoxDecoration(
                  color: DarkColor.cardColor,
                  border: Border.all(color: DarkColor.borderColor),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload, size: 40, color: Colors.white),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: "Click here",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const TextSpan(
                            text: " to upload your file\nSupported Format: JPG, PNG (10mb each)",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Library Card Preview
            Card(
              shape: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF6b7280)),
              ),
              margin: const EdgeInsets.only(bottom: 20),
              color: DarkColor.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Placeholder or Selected Image
                    Container(
                      height: width * 0.4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                        image: _imageFile != null
                            ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _imageFile == null
                          ? const Center(
                        child: Text(
                          "Library Image",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            libraryName,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "Open",
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        const Text(
                          "New",
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "• No reviews yet",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Display selected utilities if any
                    if (widget.libraryModel.utilities.isNotEmpty) ...[
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.libraryModel.utilities.take(3).map((utilityId) {
                          IconData icon = Icons.star;
                          String name = utilityId;

                          // Find matching utility from predefined list
                          for (var util in LibraryUtilities.predefinedUtilities) {
                            if (util.id == utilityId) {
                              icon = util.icon;
                              name = util.name;
                              break;
                            }
                          }

                          // If it's a custom utility, extract name
                          if (utilityId.startsWith('custom_') && name == utilityId) {
                            name = name.replaceAll('custom_', '');
                            if (name.contains('_')) {
                              name = name.split('_').map((word) =>
                              word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : ''
                              ).join(' ');
                            }
                          }

                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 10, color: Colors.blue[300]),
                                SizedBox(width: 4),
                                Text(
                                  name,
                                  style: TextStyle(fontSize: 10, color: Colors.blue[300]),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const Text(
                      "0 Students Enrolled",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event_seat,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.libraryModel.totalSeats} seats",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(),
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: Row(
                            children: [
                              Text(
                                lowFee,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "/month",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              )
                            ],
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Completion Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DarkColor.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Almost Done!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Click Done to complete your library setup. You can update your library details anytime from your dashboard.",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Done Button
            SolidButton(
              text: "Complete Setup",
              width: double.infinity,
              height: 48,
              onPressed: _uploadLibraryData,
            ),
          ],
        ),
      ),
    );
  }
}