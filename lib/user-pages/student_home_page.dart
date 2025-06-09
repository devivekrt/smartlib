import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/widgets/solid_button.dart';

// For navigation to marketplace and detail page

import 'library_market_place.dart';
// import 'package:smartlib/user-pages/library_detail_screen.dart'; // If you want to push to a detail screen

class StudentHomePage extends StatefulWidget {
  final VoidCallback onScanButtonPressed;
  final VoidCallback onBookSeatPressed;

  const StudentHomePage({
    Key? key,
    required this.onScanButtonPressed,
    required this.onBookSeatPressed
  }) : super(key: key);

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  bool _isCheckedIn = false;
  String _currentSeatId = "";

  // Sample data for nearby libraries
  final List<Map<String, dynamic>> _nearbyLibraries = [
    {
      'name': 'Central University Library',
      'distance': '0.3 km',
      'rating': 4.8,
      'seats': 134,
      'available': 47,
      'image': 'assets/library1.jpg',
      'color': Color(0xFF5B69FF),
      'id': 'lib1'
    },
    {
      'name': 'Downtown Study Center',
      'distance': '1.2 km',
      'rating': 4.5,
      'seats': 78,
      'available': 23,
      'image': 'assets/library2.jpg',
      'color': Color(0xFF9C49F5),
      'id': 'lib2'
    },
    {
      'name': 'Tech Hub & Library',
      'distance': '2.5 km',
      'rating': 4.9,
      'seats': 95,
      'available': 12,
      'image': 'assets/library3.jpg',
      'color': Color(0xFFFF5E7C),
      'id': 'lib3'
    },
  ];

  // Sample seat booking history
  final List<Map<String, dynamic>> _seatHistory = [
    {
      'id': 'A-42',
      'library': 'Central University Library',
      'date': '2025-05-17',
      'duration': '3h 24m',
      'status': 'completed',
    },
    {
      'id': 'B-15',
      'library': 'Central University Library',
      'date': '2025-05-15',
      'duration': '5h 12m',
      'status': 'completed',
    },
    {
      'id': 'C-08',
      'library': 'Downtown Study Center',
      'date': '2025-05-10',
      'duration': '2h 45m',
      'status': 'completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = Theme.of(context).cardColor;

    return SafeArea(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Profile Row
              _buildProfileRow(textColor),

              Gap(20),

              // Current Status Card - Check-in status
              _buildCheckInStatusCard(width, _isCheckedIn, _currentSeatId),

              Gap(20),

              // Featured Section - Book a Seat
              _buildBookSeatCard(width, height),

              Gap(20),

              // Study Statistics Section
              _buildStudyStatsSection(textColor, cardColor),

              Gap(20),

              // Nearby Libraries Section (updated for navigation)
              _buildNearbyLibrariesSection(width, textColor, context),

              Gap(20),

              // Recent Seat History
              _buildSeatHistorySection(textColor, cardColor),

              Gap(20),
            ],
          ),
        ),
      ),
    );
  }

  // Profile Row with Greeting
  Widget _buildProfileRow(Color textColor) {
    String greeting = _getGreeting();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile and Greeting
        Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xff6C63FF), Color(0xff1940CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xff1940CC).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  "V",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
                Text(
                  "Vivek 👋",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Notification with badge
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications,
                color: Colors.white70,
                size: 22,
              ),
            ),
            Container(
              height: 12,
              width: 12,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFF121212), width: 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Check-in Status Card (unchanged, could be updated to use real session data)
  Widget _buildCheckInStatusCard(double width, bool isCheckedIn, String seatId) {
    return Container(
      width: width,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCheckedIn
              ? [Color(0xff43A047), Color(0xff66BB6A)]
              : [Color(0xff1940CC), Color(0xff2D5BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: isCheckedIn
                ? Color(0xff43A047).withOpacity(0.4)
                : Color(0xff1940CC).withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status icon and text
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCheckedIn
                          ? CupertinoIcons.check_mark_circled_solid
                          : Icons.access_time_filled,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isCheckedIn ? "Currently Studying" : "Not Checked In",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              // QR Code icon (only if checked in)
              if (isCheckedIn)
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code,
                    color: Color(0xff43A047),
                    size: 20,
                  ),
                ),
            ],
          ),

          Gap(20),

          // Status details
          if (isCheckedIn) ...[
            _buildStatusInfoRow(
              icon: Icons.location_on,
              label: "Central University Library",
              color: Colors.white,
            ),
            SizedBox(height: 10),
            _buildStatusInfoRow(
              icon: Icons.person_pin,
              label: "Seat $seatId",
              color: Colors.white,
            ),
            SizedBox(height: 10),
            _buildStatusInfoRow(
              icon: Icons.access_time,
              label: "Started at 2:30 PM (1h 24m elapsed)",
              color: Colors.white,
            ),

            Gap(15),
            Divider(color: Colors.white38),
            Gap(15),

            // Action button
            SolidButton(
              text: "End Session & Check Out",
              onPressed: () {},
              buttonColor: Colors.white,
              width: double.infinity,
              height: 45,
            ),
          ] else ...[
            Text(
              "You haven't checked into any library yet.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Gap(15),
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Scan the QR code at library entrance to check in",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            Gap(15),

            // Action buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SolidButton(
                    text: "Book a Seat",
                    onPressed: widget.onBookSeatPressed,
                    buttonColor: Colors.white,
                    height: 45,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: SolidButton(
                    text: "Scan",
                    onPressed: widget.onScanButtonPressed,
                    buttonColor: Colors.white.withOpacity(0.3),
                    height: 45,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Book a Seat Quick Access Card (navigates to LibraryMarketplace)
  Widget _buildBookSeatCard(double width, double height) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LibraryMarketplace(isSignedUp: false), // or true if user just signed up
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9C49F5), Color(0xFFFF5E7C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF9C49F5).withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Book a Seat",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Reserve your favorite spot in advance",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 15),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Book Now",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                CupertinoIcons.car_fill,
                color: Colors.white,
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Status Info Row
  Widget _buildStatusInfoRow({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // Study Statistics Section (unchanged)
  Widget _buildStudyStatsSection(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Study Statistics",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Gap(15),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Weekly hours chart
              Container(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBarChartItem("M", 0.5, 5, textColor),
                    _buildBarChartItem("T", 0.7, 7, textColor),
                    _buildBarChartItem("W", 0.9, 9, textColor, isHighlighted: true),
                    _buildBarChartItem("T", 0.6, 6, textColor),
                    _buildBarChartItem("F", 0.4, 4, textColor),
                    _buildBarChartItem("S", 0.2, 2, textColor),
                    _buildBarChartItem("S", 0.0, 0, textColor),
                  ],
                ),
              ),

              Gap(20),

              // Stats summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatsItem(
                    value: "33h",
                    label: "This Week",
                    icon: Icons.access_time,
                    color: Color(0xff1940CC),
                    textColor: textColor,
                  ),
                  _buildStatsItem(
                    value: "9h",
                    label: "Longest Day",
                    icon: Icons.bar_chart,
                    color: Color(0xff9C49F5),
                    textColor: textColor,
                  ),
                  _buildStatsItem(
                    value: "5",
                    label: "Day Streak",
                    icon: Icons.local_fire_department,
                    color: Color(0xFFFF5E7C),
                    textColor: textColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Nearby Libraries Section -- tap navigates to LibraryMarketplace, long-press could show details
  Widget _buildNearbyLibrariesSection(double width, Color textColor, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Nearby Libraries",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LibraryMarketplace(isSignedUp: false),
                  ),
                );
              },
              child: Text(
                "View All",
                style: TextStyle(
                  color: Color(0xff2D5BFF),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        Gap(10),
        Container(
          height: 210,
          child: ListView.builder(
            physics: BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: _nearbyLibraries.length,
            itemBuilder: (context, index) {
              final library = _nearbyLibraries[index];
              return GestureDetector(
                onTap: () {
                  // Go to the marketplace showing this library or a detail page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LibraryMarketplace(isSignedUp: false),
                    ),
                  );
                  // For a direct details page, you could push to LibraryDetailScreen
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryDetailScreen(...)));
                },
                child: Container(
                  width: width * 0.7,
                  margin: EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(
                    color: library['color'].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: library['color'].withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Library info
                      Row(
                        children: [
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: library['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.apartment,
                                color: library['color'],
                                size: 25,
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  library['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: textColor.withOpacity(0.7),
                                      size: 14,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      library['distance'],
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFFFFD700),
                                      size: 14,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      library['rating'].toString(),
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 15),

                      // Availability info
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${library['available']} seats available",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: textColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: (width * 0.7 - 30) *
                                            (library['available'] / library['seats']),
                                        decoration: BoxDecoration(
                                          color: library['color'],
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  "out of ${library['seats']} total seats",
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      Spacer(),

                      // Book button
                      GestureDetector(
                        onTap: widget.onBookSeatPressed,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: library['color'],
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              "Book a Seat",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Seat History Section (unchanged)
  Widget _buildSeatHistorySection(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Sessions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "See All",
                style: TextStyle(
                  color: Color(0xff2D5BFF),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        Gap(10),
        Column(
          children: _seatHistory.map((session) {
            return Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: Color(0xff1940CC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        session['id'],
                        style: TextStyle(
                          color: Color(0xff1940CC),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['library'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: textColor.withOpacity(0.7),
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              _formatDate(session['date']),
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.access_time,
                              color: textColor.withOpacity(0.7),
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              session['duration'],
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Color(0xff43A047).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "Completed",
                      style: TextStyle(
                        color: Color(0xff43A047),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Bar Chart Item
  Widget _buildBarChartItem(
      String label,
      double value,
      int hours,
      Color textColor,
      {bool isHighlighted = false}
      ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 25,
          height: 78 * value,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isHighlighted
                  ? [Color(0xff1940CC), Color(0xff2D5BFF)]
                  : [Color(0xff1940CC).withOpacity(0.3), Color(0xff2D5BFF).withOpacity(0.3)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isHighlighted ? Color(0xff1940CC) : textColor.withOpacity(0.7),
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        SizedBox(height: 4),
        if (isHighlighted)
          Text(
            "${hours}h",
            style: TextStyle(
              color: Color(0xff1940CC),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  // Stats Item
  Widget _buildStatsItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Get greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning,";
    } else if (hour < 17) {
      return "Good Afternoon,";
    } else {
      return "Good Evening,";
    }
  }

  // Format date for display
  String _formatDate(String date) {
    final parts = date.split('-');
    if (parts.length >= 3) {
      return "${parts[1]}/${parts[2]}";
    }
    return date;
  }
}