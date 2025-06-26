import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/function/student_function.dart';
import 'package:smartlib/student/edit_profile_page.dart';
import 'package:smartlib/student/welcomescreen.dart';

import 'booking_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // User data
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _studyStats = {};
  String _profileImageUrl = '';
  bool _isPremium = false;
  String _membershipExpiry = '';
  String _membershipLevel = 'Basic';
  int _streak = 0;
  int _totalStudyHours = 0;
  int _totalVisits = 0;

  // Loading state
  bool _isLoading = true;
  bool _isLoadingStats = true;

  // Achievements
  List<Map<String, dynamic>> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStudyStats();
  }

  // Load user data from Firebase
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user's ID
      final userId = SmartLib.userId;

      // Get user data from Realtime Database
      final userRef = FirebaseDatabase.instance
          .ref()
          .child('users/students/$userId');

      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Convert to a properly typed map
        Map<String, dynamic> typedData = {};
        data.forEach((key, value) {
          typedData[key.toString()] = value;
        });

        // Extract membership info if available
        bool isPremium = false;
        String expiryDate = '';
        String membershipLevel = 'Basic';

        if (typedData.containsKey('membership')) {
          final membership = typedData['membership'];
          if (membership is Map) {
            isPremium = membership['isPremium'] == true;
            expiryDate = membership['expiryDate']?.toString() ?? '';
            membershipLevel = membership['level']?.toString() ?? 'Basic';
          }
        }

        // Get profile image URL
        String profileImageUrl = typedData['profilePic']?.toString() ?? '';

        setState(() {
          _userData = typedData;
          _isPremium = isPremium;
          _membershipExpiry = expiryDate;
          _membershipLevel = membershipLevel;
          _profileImageUrl = profileImageUrl;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load study statistics
  Future<void> _loadStudyStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      // Get current user's ID
      final userId = SmartLib.userId;



      // If we don't have stats from Firestore, try to get streak from RTDB
      if (_streak == 0) {
        try {
          final streakRef = FirebaseDatabase.instance
              .ref()
              .child('users/students/$userId/currentStatus/streak');

          final streakSnapshot = await streakRef.get();
          if (streakSnapshot.exists) {
            final streak = (streakSnapshot.value as num?)?.toInt() ?? 0;
            setState(() {
              _streak = streak;
            });
          }
        } catch (e) {
          print('Error loading streak: $e');
        }
      }

      // If we still don't have total visits, check attendance history
      if (_totalVisits == 0) {
        try {
          // Get attendance records from the last 30 days
          final now = DateTime.now();
          final attendanceQuery = await FirebaseFirestore.instance
              .collectionGroup('records')
              .where('studentId', isEqualTo: userId)
              .limit(100)
              .get();

          // Count unique dates
          Set<String> uniqueDates = {};
          for (final doc in attendanceQuery.docs) {
            final data = doc.data();
            final date = data['date']?.toString() ?? '';
            if (date.isNotEmpty) {
              uniqueDates.add(date);
            }
          }

          setState(() {
            _totalVisits = uniqueDates.length;
          });
        } catch (e) {
          print('Error counting visits: $e');
        }
      }

    } catch (e) {
      print('Error loading study stats: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }



  // Format date for display
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Handle logout action
  Future<void> _logout() async {
    try {
      setState(() {
        _isLoading = true;
      });
      AuthFunctions().userLogout(context);
      /// Navigate to login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => WelcomeScreen()), // Replace with your login screen
            (route) => false, // Remove all previous routes
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $e')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = Theme.of(context).cardColor;

    // Extract user name from userData
    final String fullName = _userData['fullName'] ?? _userData['name']?.toString().split(' ').first ?? 'Student';
    final String initials = (fullName.isNotEmpty ? fullName[0]: '');

    // Extract user education info
    final String dept = _userData['department'] ?? 'Computer Science';
    final String educationInfo = "$dept";

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadUserData();
                  await _loadStudyStats();
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile Header with Quick Settings
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "My Profile",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.notifications_outlined),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Notifications')),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.settings_outlined),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Settings')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),

                        Gap(20),

                        // Profile Header Card
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
                              // Profile Image and Stats
                              Row(
                                children: [
                                  // Profile Image
                                  GestureDetector(
                                    onTap: () {
                                      // Show profile image options
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Change profile picture')),
                                      );
                                    },
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 80,
                                          width: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [Color(0xff6C63FF), Color(0xff1940CC)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: _profileImageUrl.isNotEmpty
                                              ? SizedBox()
                                              : Center(
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 30,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Color(0xff1940CC),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: cardColor,
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  // Stats
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fullName,
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),
                                            if (_isPremium)
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFFFFD700).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.stars,
                                                      color: Color(0xFFFFD700),
                                                      size: 12,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      _membershipLevel,
                                                      style: TextStyle(
                                                        color: Color(0xFFFFD700),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        Gap(5),
                                        Text(
                                          educationInfo,
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.7),
                                          ),
                                        ),
                                        Gap(10),
                                        Row(
                                          children: [
                                            _buildStatItem(
                                              _totalStudyHours.toString(),
                                              "Study\nHours",
                                              textColor,
                                            ),
                                            _buildStatItem(
                                              _totalVisits.toString(),
                                              "Library\nVisits",
                                              textColor,
                                            ),
                                            _buildStatItem(
                                              _streak.toString(),
                                              "Day\nStreak",
                                              textColor,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              Gap(20),
                              Divider(color: textColor.withOpacity(0.1)),
                              Gap(15),

                              // Membership Status
                              _isPremium
                                  ? Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFD700).withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: Color(0xFFFFD700),
                                      size: 18,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$_membershipLevel Membership",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        "Valid until ${_formatDate(_membershipExpiry)}",
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFD700).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "ACTIVE",
                                      style: TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                                  : ElevatedButton.icon(
                                icon: Icon(Icons.workspace_premium),
                                label: Text("Upgrade to Premium"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF1940CC),
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Upgrade to Premium')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        Gap(25),

                        // Account Settings
                        Container(
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
                              _buildProfileOptionItem(
                                Icons.person,
                                "Edit Profile",
                                "Update your personal information",
                                textColor,
                                  onTap: () {
                                    // Navigate to edit profile page
                                    Navigator.push(context, MaterialPageRoute(builder: (context)=> EditProfilePage()));
                                }
                              ),
                              Divider(color: textColor.withOpacity(0.1), height: 0),
                              _buildProfileOptionItem(
                                Icons.calendar_month,
                                "Booking History",
                                "View your previous booking sessions",
                                textColor,
                                  onTap: () {
                                    // Navigate to edit profile page
                                    Navigator.push(context, MaterialPageRoute(builder: (context)=> BookingHistoryScreen()));
                                  }
                              ),
                              Divider(color: textColor.withOpacity(0.1), height: 0),
                              _buildProfileOptionItem(
                                Icons.bar_chart,
                                "Study Analytics",
                                "Track your productivity and patterns",
                                textColor,
                              ),


                            ],
                          ),
                        ),

                        Gap(25),

                        // Help and About options
                        Container(
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
                              _buildProfileOptionItem(
                                Icons.question_mark_rounded,
                                "Help & Support",
                                "Get assistance and FAQs",
                                textColor,
                              ),
                              Divider(color: textColor.withOpacity(0.1), height: 0),
                              _buildProfileOptionItem(
                                Icons.article_rounded,
                                "Terms & Policies",
                                "Read our terms and privacy policy",
                                textColor,
                              ),
                              Divider(color: textColor.withOpacity(0.1), height: 0),
                              _buildProfileOptionItem(
                                Icons.arrow_circle_right_rounded,
                                "Log Out",
                                "Sign out from your account",
                                textColor,
                                isLogout: true,
                                onTap: () {
                                  // Show confirmation dialog before logout
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Log Out'),
                                      content: Text('Are you sure you want to log out?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _logout();
                                          },
                                          child: Text('Log Out'),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        Gap(30),

                        Text(
                          "SmartLib v1.2.5",
                          style: TextStyle(
                            color: textColor.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),

                        Gap(10),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Stats Item for Profile
  Widget _buildStatItem(String value, String label, Color textColor) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xff1940CC).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xff1940CC),
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Profile Option Item
  Widget _buildProfileOptionItem(
      IconData icon,
      String title,
      String subtitle,
      Color textColor, {
        bool isLogout = false,
        VoidCallback? onTap,
      }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isLogout
              ? Colors.red.withOpacity(0.1)
              : Color(0xff1940CC).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isLogout ? Colors.red : Color(0xff1940CC),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isLogout ? Colors.red : textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: textColor.withOpacity(0.7),
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.keyboard_arrow_right,
        color: textColor.withOpacity(0.5),
        size: 16,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      onTap:onTap
    );
  }
}