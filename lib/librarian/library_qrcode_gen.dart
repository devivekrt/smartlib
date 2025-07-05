import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class LibraryQRGeneratorScreen extends StatefulWidget {
  final String libraryId;
  final String libraryName;
  final String libraryAddress;
  final String librarianId;

  const LibraryQRGeneratorScreen({
    Key? key,
    required this.libraryId,
    required this.libraryName,
    required this.libraryAddress,
    required this.librarianId,
  }) : super(key: key);

  @override
  State<LibraryQRGeneratorScreen> createState() => _LibraryQRGeneratorScreenState();
}

class _LibraryQRGeneratorScreenState extends State<LibraryQRGeneratorScreen> with SingleTickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  final GlobalKey _fullCardKey = GlobalKey(); // Key for full card capture
  bool _isGenerating = false;
  bool _showSuccess = false;
  String _successMessage = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack)
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Generate single QR code data with library ID
  String _generateQRData() {
    return '${widget.libraryId}_SMARTLIB';
  }

  // Save QR code using Gal package
  Future<void> _saveQRToGallery() async {
    setState(() {
      _isGenerating = true;
      _showSuccess = false;
    });

    try {
      // Capture full QR card as image
      RenderRepaintBoundary boundary = _fullCardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        // Convert ByteData to Uint8List
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Create a temporary file to save the image
        final tempDir = await getTemporaryDirectory();
        final fileName = "SmartLib_QR_${widget.libraryId}_${DateTime.now().millisecondsSinceEpoch}.png";
        final tempFile = File('${tempDir.path}/$fileName');

        // Write the file
        await tempFile.writeAsBytes(pngBytes);

        // Save to gallery using Gal
        await Gal.putImage(tempFile.path);

        // Show success message
        setState(() {
          _showSuccess = true;
          _successMessage = 'QR code saved to gallery!';
        });

        // Show more specific success info
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code saved to your photo gallery'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OKAY',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );

        // Auto hide success message after 3 seconds
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showSuccess = false;
            });
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final accentColor = Color(0xff1940CC); // Use your specific accent color
    final secondaryAccentColor = Color(0xFF00C6FF); // Use your specific secondary color

    return Scaffold(
      appBar: AppBar(
        title: Text("Library QR Generator"),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "About QR Code",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "This QR code works as a universal check-in/check-out system for your library.",
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "When students scan this code, the system will automatically determine whether to check them in or out based on their current status.",
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        child: Text("Got it"),
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background design elements
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // QR Section title with animation
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 2,
                              color: accentColor,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "SMART QR CODE",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              width: 30,
                              height: 2,
                              color: accentColor,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        "One QR code for both check-in and check-out",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 30),

                      // Single unified QR code with enhanced design - WITH FULL CARD REPAINT BOUNDARY
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: RepaintBoundary(
                          key: _fullCardKey,  // Use the full card key here
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: Offset(0, 10),
                                ),
                              ],
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accentColor,
                                  secondaryAccentColor,
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  color: cardColor,
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Check-in/out badge
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(30),
                                          gradient: LinearGradient(
                                            colors: [accentColor, secondaryAccentColor],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accentColor.withOpacity(0.3),
                                              blurRadius: 10,
                                              spreadRadius: 0,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.login, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              "CHECK-IN & CHECK-OUT",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.logout, color: Colors.white, size: 18),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 24),

                                      // QR code with inner repaint boundary for reference
                                      RepaintBoundary(
                                        key: _qrKey,
                                        child: Container(
                                          width: MediaQuery.of(context).size.width - 150,
                                          height: MediaQuery.of(context).size.width - 150,
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 10,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                            border: Border.all(
                                              color: accentColor.withOpacity(0.2),
                                              width: 2,
                                            ),
                                          ),
                                          child: QrImageView(
                                            data: _generateQRData(),
                                            version: QrVersions.auto,
                                            backgroundColor: Colors.white,
                                            size: 240,
                                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                                            embeddedImageStyle: QrEmbeddedImageStyle(
                                              size: Size(50, 50),
                                            ),
                                            semanticsLabel: 'QR Code for ${widget.libraryName}',
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: 24),

                                      // Library Information
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: accentColor.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              widget.libraryName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: accentColor,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              widget.libraryAddress,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode ? Colors.white70 : Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              "Library ID: ${widget.libraryId}",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: isDarkMode ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 16),

                                      // Date generated
                                      Text(
                                        "Generated: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.white54 : Colors.black54,
                                        ),
                                      ),

                                      SizedBox(height: 8),

                                      // Footer info
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.qr_code_scanner,
                                            size: 16,
                                            color: isDarkMode ? Colors.white54 : Colors.black54,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "SmartLib",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isDarkMode ? Colors.white54 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 30),

                      // Success message with animation
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        height: _showSuccess ? 60 : 0,
                        curve: Curves.easeInOut,
                        child: _showSuccess
                            ? Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: Colors.green.withOpacity(0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _successMessage,
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : SizedBox.shrink(),
                      ),

                      SizedBox(height: 30),

                      // Save to Gallery button with animation
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: _isGenerating
                                  ? [Colors.grey, Colors.grey.shade600]
                                  : [accentColor, secondaryAccentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: _isGenerating
                                ? []
                                : [
                              BoxShadow(
                                color: accentColor.withOpacity(0.4),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _saveQRToGallery,
                            icon: _isGenerating
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Icon(Icons.photo_library, size: 24),
                            label: Text(
                              _isGenerating ? "Saving..." : "Save to Gallery",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              minimumSize: Size(double.infinity, 60),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 30),

                      // Instructions card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                isDarkMode ? Colors.blueGrey[900]! : Colors.blue[50]!,
                                isDarkMode ? Color(0xFF1A1A2E) : Colors.white
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isDarkMode ? Colors.grey[800]! : Colors.blue[100]!,
                                width: 1
                            ),
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                            childrenPadding: EdgeInsets.all(20),
                            iconColor: accentColor,
                            collapsedIconColor: accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.info_outline, color: accentColor, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  "How It Works",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInstructionItem(
                                    context,
                                    icon: Icons.image,
                                    text: "Save and print this QR code for your library.",
                                    iconColor: accentColor,
                                  ),
                                  Divider(height: 20, thickness: 0.5, color: Colors.grey.withOpacity(0.3)),

                                  _buildInstructionItem(
                                    context,
                                    icon: Icons.place,
                                    text: "Place the QR code at convenient locations in your library.",
                                    iconColor: accentColor,
                                  ),
                                  Divider(height: 20, thickness: 0.5, color: Colors.grey.withOpacity(0.3)),

                                  Text(
                                    "When a student scans the QR code, the system will:",
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(height: 12),

                                  _buildInstructionItem(
                                    context,
                                    icon: Icons.login,
                                    text: "Check the student IN if they're not currently checked in",
                                    iconColor: Colors.green,
                                    indent: 16,
                                  ),
                                  SizedBox(height: 8),

                                  _buildInstructionItem(
                                    context,
                                    icon: Icons.logout,
                                    text: "Check the student OUT if they're already checked in",
                                    iconColor: Colors.red,
                                    indent: 16,
                                  ),

                                  Divider(height: 20, thickness: 0.5, color: Colors.grey.withOpacity(0.3)),

                                  _buildInstructionItem(
                                    context,
                                    icon: Icons.verified,
                                    text: "The system automatically validates bookings and records attendance times.",
                                    iconColor: accentColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isGenerating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Saving QR code to gallery...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(BuildContext context, {
    required IconData icon,
    required String text,
    required Color iconColor,
    double indent = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}