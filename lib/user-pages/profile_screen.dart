import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;

    return SafeArea(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Header
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
                          child: Center(
                            child: Text(
                              "V",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        // Stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Vivek Sharma",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Gap(5),
                              Text(
                                "Computer Science, Year 3",
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                ),
                              ),
                              Gap(10),
                              Row(
                                children: [
                                  _buildStatItem("42", "Study\nHours", textColor),
                                  _buildStatItem("15", "Library\nVisits", textColor),
                                  _buildStatItem("8", "Study\nStreaks", textColor),
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
                    Row(
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
                              "Premium Membership",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "Valid until June 30, 2025",
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
                    ),
                  ],
                ),
              ),

              Gap(25),

              // Options List
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
                      Icons.watch_later_outlined,
                      "Study History",
                      "View your previous study sessions",
                      textColor,
                    ),
                    Divider(color: textColor.withOpacity(0.1), height: 0),
                    _buildProfileOptionItem(
                      Icons.bar_chart_rounded,
                      "Study Analytics",
                      "Track your productivity and patterns",
                      textColor,
                    ),
                    Divider(color: textColor.withOpacity(0.1), height: 0),
                    _buildProfileOptionItem(
                      Icons.notifications,
                      "Notifications",
                      "Manage your notification preferences",
                      textColor,
                    ),
                    Divider(color: textColor.withOpacity(0.1), height: 0),
                    _buildProfileOptionItem(
                      CupertinoIcons.creditcard,
                      "Payment Methods",
                      "Manage your subscription and payments",
                      textColor,
                    ),
                    Divider(color: textColor.withOpacity(0.1), height: 0),
                    _buildProfileOptionItem(
                      CupertinoIcons.person_2,
                      "Study Buddies",
                      "Connect with fellow students",
                      textColor,
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
                      CupertinoIcons.settings,
                      "Account Settings",
                      "Manage your account preferences",
                      textColor,
                    ),
                    Divider(color: textColor.withOpacity(0.1), height: 0),
                    _buildProfileOptionItem(
                      CupertinoIcons.question_circle,
                      "Help & Support",
                      "Get assistance and FAQs",
                      textColor,
                    ),
                    Divider(color: textColor.withOpacity(0.1), height: 0),
                    _buildProfileOptionItem(
                      CupertinoIcons.arrow_right_square,
                      "Log Out",
                      "Sign out from your account",
                      textColor,
                      isLogout: true,
                    ),
                  ],
                ),
              ),

              Gap(30),

              Text(
                "Study Smart v1.0.2",
                style: TextStyle(
                  color: textColor.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),

              Gap(10),

              // Current date-time shown at bottom
              Text(
                "Last updated: 2025-05-21 15:52:22",
                style: TextStyle(
                  color: textColor.withOpacity(0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Stats Item for Profile
  Widget _buildStatItem(String value, String label, Color textColor) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: textColor.withOpacity(0.1),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
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
        bool isLogout = false}
      ) {
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
      onTap: () {
        // Handle the tap based on which option is clicked
        if (isLogout) {
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
                    // Implement logout functionality here
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logged out successfully')),
                    );
                  },
                  child: Text('Log Out'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          );
        } else {
          // Navigate to appropriate screen based on option
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $title')),
          );
        }
      },
    );
  }
}