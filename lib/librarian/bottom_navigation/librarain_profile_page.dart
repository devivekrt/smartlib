import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';

import '../../data/string.dart';
import '../../function/student_function.dart';
import '../../library/library_details_upload.dart';
import '../../student/welcomescreen.dart'; // Make sure to add this dependency

class LibrarianProfilePage extends StatefulWidget {
  final Map<String, dynamic> librarianData;
  final List<LibraryModel> libraryModels;
  final LibraryModel? currentLibraryModel;
  final Function(int) onChangeLibrary;
  final String Function(dynamic) formatTimeAgo;

  const LibrarianProfilePage({
    Key? key,
    required this.librarianData,
    required this.libraryModels,
    required this.currentLibraryModel,
    required this.onChangeLibrary,
    required this.formatTimeAgo,
  }) : super(key: key);

  @override
  State<LibrarianProfilePage> createState() => _LibrarianProfilePageState();
}

class _LibrarianProfilePageState extends State<LibrarianProfilePage> {
  bool _isLoading = false;

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Librarian profile card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Image or Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      widget.librarianData['photoURL'] != null &&
                              widget.librarianData['photoURL'].toString().isNotEmpty
                          ? CircleAvatar(
                            radius: 50,
                            backgroundImage: NetworkImage(
                              widget.librarianData['photoURL'],
                            ),
                            backgroundColor: Colors.grey[300],
                          )
                          : CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xff1940CC),
                            child: Text(
                              _getInitials(
                                widget.librarianData['fullName'] ??
                                    widget.librarianData['name'] ??
                                    'L',
                              ),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () {
                            // Handle photo change
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Profile photo update feature coming soon",
                                ),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Color(0xff1940CC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Librarian Name
                  Text(
                    widget.librarianData['fullName'] ??
                        widget.librarianData['name'] ??
                        'Librarian',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(8),

                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff1940CC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.librarianData['role'] ?? 'Librarian',
                      style: const TextStyle(
                        color: Color(0xff1940CC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Gap(12),

                  // Librarian Email and phone
                  Text(
                    widget.librarianData['email'] ?? SmartLib.email ?? '',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),

                  if (widget.librarianData['phone'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        widget.librarianData['phone'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Personal info rows
                  _buildProfileInfoRow(
                    Icons.app_registration,
                    'Member Since',
                    _formatDate(widget.librarianData['establishedDate']),
                  ),

                  _buildProfileInfoRow(
                    Icons.verified_user,
                    'Account Status',
                    'Active',
                    valueColor: Colors.green,
                  ),

                  if (widget.librarianData['lastLogin'] != null)
                    _buildProfileInfoRow(
                      Icons.access_time,
                      'Last Active',
                      widget.formatTimeAgo(widget.librarianData['lastLogin']),
                    ),

                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile"),
                    onPressed: () {
                      // Navigate to edit profile
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile edit feature coming soon"),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff1940CC),
                      side: const BorderSide(color: Color(0xff1940CC)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Gap(20),

          // Libraries managed
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Libraries Managed",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  widget.libraryModels.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "No libraries found",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.libraryModels.length,
                        itemBuilder: (context, index) {
                          final library = widget.libraryModels[index];
                          final isCurrentLibrary =
                              library.id == widget.currentLibraryModel?.id;

                          // Get the first letter of the library name for the avatar
                          final String libraryName =
                              library.libraryName ?? 'Library';
                          final String firstLetter =
                              libraryName.isNotEmpty
                                  ? libraryName[0].toUpperCase()
                                  : 'L';

                          // Format address or location for subtitle
                          String address = '';
                          if (library.address != null) {
                            final addressMap = library.address!;
                            final components = <String>[];
                            if (addressMap['street'] != null)
                              components.add(addressMap['street']);
                            if (addressMap['city'] != null)
                              components.add(addressMap['city']);
                            address = components.join(', ');
                          } else if (library.location != null) {
                            address = library.location!;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color:
                                isCurrentLibrary
                                    ? const Color(0xff1940CC).withOpacity(0.05)
                                    : null,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color:
                                    isCurrentLibrary
                                        ? const Color(
                                          0xff1940CC,
                                        ).withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: CircleAvatar(
                                backgroundColor:
                                    isCurrentLibrary
                                        ? const Color(0xff1940CC)
                                        : Colors.grey[200],
                                child: Text(
                                  firstLetter,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isCurrentLibrary
                                            ? Colors.white
                                            : Colors.black,
                                  ),
                                ),
                              ),
                              title: Text(
                                libraryName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isCurrentLibrary
                                          ? const Color(0xff1940CC)
                                          : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  if (library.totalSeats != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${library.totalSeats} seats • ${library.students ?? 0} students',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing:
                                  isCurrentLibrary
                                      ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                      : IconButton(
                                        icon: const Icon(
                                          Icons.swap_horiz,
                                          color: Color(0xff1940CC),
                                        ),
                                        onPressed: () => widget.onChangeLibrary(index),
                                      ),
                              onTap: () {
                                if (!isCurrentLibrary) {
                                  widget.onChangeLibrary(index);
                                }
                              },
                            ),
                          );
                        },
                      ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add New Library"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff1940CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                            title: Text('Add New Library'),
                            content: Text('Are you sure you want add new Library?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('No'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: (){
                                  // Updated navigation to Library Details Upload
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => LibraryDetailsUpload(
                                        librarianId: SmartLib.userId,
                                      ),
                                    ),
                                  );

                                },
                                child: Text('Yes, Add Library'),
                              ),
                            ],
                          ),
                        );

                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Gap(20),

          // Support Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.support_agent,
                    color: const Color(0xff1940CC),
                  ),
                  title: Text(
                    'Help & Support',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Divider(height: 1),
                _settingsItem(context, "Help Center", Icons.help_outline, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Help center feature coming soon'),
                    ),
                  );
                }, showDivider: true),
                _settingsItem(context, "Contact Support", Icons.support, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Support contact feature coming soon'),
                    ),
                  );
                }, showDivider: true),
                _settingsItem(context, "About", Icons.info_outline, () {
                  // Show about dialog
                  showAboutDialog(
                    context: context,
                    applicationName: "SmartLib - Library Management App",
                    applicationVersion: "1.0.0",
                    applicationLegalese: "© 2025 All Rights Reserved",
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        "SmartLib is a complete solution for managing library seats, bookings, and payments.",
                      ),
                    ],
                  );
                }, showDivider: true),
                _settingsItem(
                  context,
                  "Logout",
                  Icons.logout,
                  () async {
                    // Show confirmation dialog before logging out
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text('Log Out'),
                            content: Text('Are you sure you want to log out?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _logout,
                                child: Text('Log Out'),
                              ),
                            ],
                          ),
                    );
                  },
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  showDivider: false,
                ),
              ],
            ),
          ),

          const Gap(20),

          // Version and current date-time information
          Center(
            child: Column(
              children: [
                Text(
                  'Version 1.0.0 (Build 2025.06.19)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  'SmartLib © 2025',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  // Helper widget for profile info rows
  Widget _buildProfileInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for settings items
  Widget _settingsItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color? textColor,
    Color? iconColor,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor ?? const Color(0xff1940CC)),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  // Helper to get initials from name
  String _getInitials(String name) {
    if (name.isEmpty) return 'L';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }

    return 'L';
  }

  // Format date nicely
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return 'N/A';
      }

      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }
}
