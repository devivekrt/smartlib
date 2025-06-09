import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:smartlib/widgets/solid_button.dart';

class QRScannerScreen extends StatefulWidget {
  final bool isCheckedIn;
  final String currentSeatId;

  const QRScannerScreen({
    Key? key,
    required this.isCheckedIn,
    required this.currentSeatId
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final width = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Container(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.isCheckedIn ? "Check Out from Library" : "Check In to Library",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 10),
            Text(
              widget.isCheckedIn
                  ? "Scan QR code at the exit to check out"
                  : "Scan QR code at the entrance to check in",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: textColor.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 40),

            // QR Scanner Frame
            Container(
              width: width * 0.8,
              height: width * 0.8,
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xff1940CC), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Simulated camera view (gray background for demo)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),

                  // Corner markers
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildCornerMarker(),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Transform.rotate(
                      angle: 90 * 3.14159 / 180,
                      child: _buildCornerMarker(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Transform.rotate(
                      angle: -90 * 3.14159 / 180,
                      child: _buildCornerMarker(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Transform.rotate(
                      angle: 180 * 3.14159 / 180,
                      child: _buildCornerMarker(),
                    ),
                  ),

                  // Scan line animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Positioned(
                        top: _animationController.value * (width * 0.8 - 2),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xff1940CC),
                                Color(0xff1940CC),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Center helper text
                  Center(
                    child: Text(
                      "Position QR code in frame",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),

            // Manual Entry Option
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.keyboard, color: Color(0xff1940CC)),
              label: Text(
                "Enter Code Manually",
                style: TextStyle(
                  color: Color(0xff1940CC),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            SizedBox(height: 10),

            // Show My QR Code Button for seat verification
            if (widget.isCheckedIn)
              OutlinedButton.icon(
                onPressed: () {
                  // Show the user's seat QR code
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _buildMyQRBottomSheet(textColor, cardColor),
                  );
                },
                icon: Icon(Icons.qr_code, color: Color(0xff1940CC)),
                label: Text(
                  "Show My Seat QR Code",
                  style: TextStyle(
                    color: Color(0xff1940CC),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xff1940CC)),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Corner Marker for QR Scanner
  Widget _buildCornerMarker() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xff1940CC), width: 3),
          left: BorderSide(color: Color(0xff1940CC), width: 3),
        ),
      ),
    );
  }

  // My QR Code Bottom Sheet
  Widget _buildMyQRBottomSheet(Color textColor, Color cardColor) {
    return Container(
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Your Seat QR Code",
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // QR Code (Placeholder)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(15),
            child: Image.network(
              'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=SeatA42_UserID12345',
              fit: BoxFit.contain,
            ),
          ),

          SizedBox(height: 20),

          Text(
            "Seat ${widget.currentSeatId.isEmpty ? 'A-42' : widget.currentSeatId}",
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 5),

          Text(
            "Show this to library staff if requested",
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),

          SizedBox(height: 25),

          SolidButton(
            text: "Download QR Code",
            onPressed: () {},
            buttonColor: Color(0xff1940CC),
            width: double.infinity,
            height: 50,
          ),
        ],
      ),
    );
  }
}