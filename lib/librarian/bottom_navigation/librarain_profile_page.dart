import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';

import '../../data/string.dart';
import '../../function/listen_data.dart';
import '../../function/student_function.dart';
import '../../library/library_details_upload.dart';
import '../../student/welcomescreen.dart';
import '../../theme/theme.dart';

class LibrarianProfilePage extends StatefulWidget {
  const LibrarianProfilePage({Key? key}) : super(key: key);

  @override
  State<LibrarianProfilePage> createState() => _LibrarianProfilePageState();
}

class _LibrarianProfilePageState extends State<LibrarianProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic> _librarianData = {};
  List<LibraryModel> _libraryModels = [];
  LibraryModel? _currentLibraryModel;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ListenData _listenData = ListenData();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load librarian data
      await _loadLibrarianData();

      // Load libraries managed by this librarian
      await _loadLibrariesData();

      // Set current library model
      _setCurrentLibraryModel();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLibrarianData() async {
    try {
      // Get librarian ID from SmartLib
      String librarianId = SmartLib.userId;
      if (librarianId.isEmpty) {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          librarianId = currentUser.uid;
        } else {
          throw Exception('No authenticated user found');
        }
      }

      // Get librarian data from Firestore
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(librarianId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        setState(() {
          _librarianData = data;
        });
      } else {
        // Try getting data from Realtime Database via SmartLib
        setState(() {
          _librarianData = {
            'id': SmartLib.userId,
            'fullName': SmartLib.librarianName,
            'email': SmartLib.email,
            'phone': SmartLib.phone,
            'photoURL': SmartLib.librarianImageUrl,
            'role': 'Librarian',
            'gender': SmartLib.gender,
            'experience': SmartLib.experience,
          };
        });
      }
    } catch (e) {
      // Fallback to SmartLib data
      setState(() {
        _librarianData = {
          'id': SmartLib.userId,
          'fullName': SmartLib.librarianName,
          'email': SmartLib.email,
          'phone': SmartLib.phone,
          'photoURL': SmartLib.librarianImageUrl,
          'role': 'Librarian',
          'gender': SmartLib.gender,
          'experience': SmartLib.experience,
        };
      });
    }
  }

  Future<void> _loadLibrariesData() async {
    try {
      // Get librarian ID
      String librarianId = SmartLib.userId;
      if (librarianId.isEmpty && _librarianData.containsKey('id')) {
        librarianId = _librarianData['id'];
      }

      if (librarianId.isEmpty) {
        throw Exception('Librarian ID not available');
      }

      // Get libraries managed by this librarian
      QuerySnapshot snapshot = await _firestore
          .collection('libraries')
          .where('librarianId', isEqualTo: librarianId)
          .get();

      List<LibraryModel> libraries = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Get subscriber count
        try {
          QuerySnapshot subscribersSnapshot = await _firestore
              .collection('libraries')
              .doc(doc.id)
              .collection('subscribers')
              .get();

          data['students'] = subscribersSnapshot.docs.length;
        } catch (e) {
          data['students'] = 0;
        }

        libraries.add(LibraryModel.fromMap(data));
      }

      setState(() {
        _libraryModels = libraries;
      });
    } catch (e) {

      // Try to get library data from SmartLib if available
      if (SmartLib.allLibraryList.isNotEmpty) {
        List<LibraryModel> libraries = [];
        for (var libraryData in SmartLib.allLibraryList) {
          libraries.add(LibraryModel.fromMap(libraryData));
        }
        setState(() {
          _libraryModels = libraries;
        });
      }
    }
  }

  void _setCurrentLibraryModel() {
    if (_libraryModels.isEmpty) return;

    // First try to find library by SmartLib.libraryId
    if (SmartLib.libraryId.isNotEmpty) {
      for (var library in _libraryModels) {
        if (library.id == SmartLib.libraryId) {
          setState(() {
            _currentLibraryModel = library;
          });
          return;
        }
      }
    }

    // If not found, use the first library
    setState(() {
      _currentLibraryModel = _libraryModels.isNotEmpty ? _libraryModels[0] : null;
    });
  }

  void _onChangeLibrary(int index) {
    if (index < 0 || index >= _libraryModels.length) return;

    setState(() {
      _currentLibraryModel = _libraryModels[index];
    });

    // Update SmartLib with new library data
    SmartLib.libraryId = _currentLibraryModel!.id ?? '';
    SmartLib.libraryName = _currentLibraryModel!.libraryName ?? '';

    if (_currentLibraryModel!.address != null) {
      SmartLib.city = _currentLibraryModel!.address!['city'] ?? '';
      SmartLib.landmark = _currentLibraryModel!.address!['landMark'] ?? '';
      SmartLib.street = _currentLibraryModel!.address!['street'] ?? '';
      SmartLib.state = _currentLibraryModel!.address!['state'] ?? '';
      SmartLib.pincode = _currentLibraryModel!.address!['zipCode'] ?? '';
    }

    SmartLib.libraryImageUrl = _currentLibraryModel!.libraryImageUrl ?? '';
    SmartLib.noOfSeat = _currentLibraryModel!.totalSeats?.toString() ?? '';

    // Reload data from ListenData service
    _listenData.getUserData();

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${_currentLibraryModel!.libraryName}'),
        )
    );
  }

  String formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Never';

    DateTime date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _logout() async {
    try {
      setState(() {
        _isLoading = true;
      });
      await AuthFunctions().userLogout(context);

      // Dispose any listeners
      _listenData.dispose();

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
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: DarkColor.highlightColor,
        ),
      );
    }

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
            color: DarkColor.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Image or Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _librarianData['profileUrl'] != null &&
                          _librarianData['profileUrl'].toString().isNotEmpty
                          ? CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(
                          _librarianData['profileUrl'],
                        ),
                        backgroundColor: Colors.grey[700],
                      )
                          : CircleAvatar(
                        radius: 50,
                        backgroundColor: DarkColor.highlightColor,
                        child: Text(
                          _getInitials(
                            _librarianData['fullName'] ??
                                _librarianData['name'] ??
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
                          child: Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: DarkColor.highlightColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Librarian Name
                  Text(
                    _librarianData['fullName'] ??
                        _librarianData['name'] ??
                        'Librarian',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                      color: DarkColor.highlightColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _librarianData['role'] ?? 'Librarian',
                      style: TextStyle(
                        color: DarkColor.highlightColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Gap(12),

                  // Librarian Email and phone
                  Text(
                    _librarianData['email'] ?? SmartLib.email ?? '',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),

                  if (_librarianData['phone'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        _librarianData['phone'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Personal info rows
                  _buildProfileInfoRow(
                    Icons.app_registration,
                    'Member Since',
                    _formatDate(_librarianData['establishedDate']),
                  ),

                  _buildProfileInfoRow(
                    Icons.verified_user,
                    'Account Status',
                    _librarianData['status'] ?? 'Active',
                    valueColor: Colors.green,
                  ),

                  if (_librarianData['lastLogin'] != null)
                    _buildProfileInfoRow(
                      Icons.access_time,
                      'Last Active',
                      formatTimeAgo(_librarianData['lastLogin']),
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
                      foregroundColor: DarkColor.highlightColor,
                      side: BorderSide(color: DarkColor.highlightColor),
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
            color: DarkColor.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Libraries Managed",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _libraryModels.isEmpty
                      ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.library_books,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No libraries found",
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Add a library to get started",
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _libraryModels.length,
                    itemBuilder: (context, index) {
                      final library = _libraryModels[index];
                      final isCurrentLibrary =
                          library.id == _currentLibraryModel?.id;

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
                            ? DarkColor.highlightColor.withOpacity(0.1)
                            : DarkColor.cardColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color:
                            isCurrentLibrary
                                ? DarkColor.highlightColor.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: CircleAvatar(
                            backgroundColor:
                            isCurrentLibrary
                                ? DarkColor.highlightColor
                                : Colors.grey[800],
                            child: Text(
                              firstLetter,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          title: Text(
                            libraryName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                              isCurrentLibrary
                                  ? DarkColor.highlightColor
                                  : Colors.white,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address,
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              if (library.totalSeats != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '${library.totalSeats} seats • ${library.students ?? 0} students',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
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
                            icon: Icon(
                              Icons.swap_horiz,
                              color: DarkColor.highlightColor,
                            ),
                            onPressed: () => _onChangeLibrary(index),
                          ),
                          onTap: () {
                            if (!isCurrentLibrary) {
                              _onChangeLibrary(index);
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
                        backgroundColor: DarkColor.highlightColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: DarkColor.cardColor,
                            title: Text('Add New Library',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: Text('Are you sure you want add new Library?',
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('No', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  // Navigate to Library Details Upload
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LibraryDetailsUpload(
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
            color: DarkColor.cardColor,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.support_agent,
                    color: DarkColor.highlightColor,
                  ),
                  title: Text(
                    'Help & Support',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey[800]),
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
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                    applicationIcon: Image.asset(
                      'assets/images/logo.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.library_books, size: 48, color: DarkColor.highlightColor),
                    ),
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
                      builder: (context) => AlertDialog(
                        backgroundColor: DarkColor.cardColor,
                        title: Text('Log Out', style: TextStyle(color: Colors.white)),
                        content: Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _logout,
                            child: _isLoading
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text('Log Out'),
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
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.white,
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
          leading: Icon(icon, color: iconColor ?? DarkColor.highlightColor),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.white,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey[800]),
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

// Extension to add clear data functionality to SmartLib
extension SmartLibExtension on SmartLib {
  static void clearData() {
    SmartLib.userId = '';
    SmartLib.librarianId = '';
    SmartLib.librarianName = '';
    SmartLib.libraryId = '';
    SmartLib.libraryName = '';
    SmartLib.email = '';
    SmartLib.phone = '';
    SmartLib.gender = '';
    SmartLib.experience = '';
    SmartLib.libraryImageUrl = '';
    // Add more fields as needed
  }
}