
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/string.dart';

class LibrarianNotificationScreen extends StatefulWidget {
  final String librarianId;
  final String libraryId;

  const LibrarianNotificationScreen({
    Key? key,
    required this.librarianId,
    required this.libraryId,
  }) : super(key: key);

  @override
  _LibrarianNotificationScreenState createState() => _LibrarianNotificationScreenState();
}

class _LibrarianNotificationScreenState extends State<LibrarianNotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _notificationType = 'announcement'; // Default type
  bool _isLoading = false;
  bool _isTargetingSpecificUsers = false;
  List<Map<String, dynamic>> _selectedStudents = [];

  // Filter options
  Map<String, bool> _filterOptions = {
    'current_visitors': false,
    'all_subscribers': false,
    'seat_owners': false,
  };

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Send notification
  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final title = _titleController.text.trim();
      final message = _messageController.text.trim();

      // List for targeted user IDs
      List<String> targetUserIds = [];

      // Either use selected specific users or apply filters
      if (_isTargetingSpecificUsers && _selectedStudents.isNotEmpty) {
        targetUserIds = _selectedStudents
            .map((student) => student['id'] as String)
            .toList();
      } else {
        // Apply filters to get target users
        targetUserIds = await _getFilteredStudentIds();
      }

      // If no users to notify, show error
      if (targetUserIds.isEmpty) {
        _showError('No students match the selected criteria');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create notification document
      final notificationData = {
        'title': title,
        'message': message,
        'senderType': 'librarian',
        'senderId': widget.librarianId,
        'libraryId': widget.libraryId,
        'type': _notificationType,
        'sentAt': FieldValue.serverTimestamp(),
        'targetUserCount': targetUserIds.length,
        'targetUserIds': targetUserIds,
      };

      // Save to Firestore
      final notificationDoc = await _firestore
          .collection('notifications')
          .add(notificationData);

      // Call cloud function to send FCM notifications
      await _callSendNotificationsFunction(
        notificationId: notificationDoc.id,
        title: title,
        message: message,
        notificationType: _notificationType,
        targetUserIds: targetUserIds,
      );

      // Reset form
      _resetForm();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification sent to ${targetUserIds.length} students')),
      );
    } catch (e) {
      _showError('Failed to send notification: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get student IDs based on selected filters
  Future<List<String>> _getFilteredStudentIds() async {
    Set<String> studentIds = {};

    try {
      // Current visitors (checked in today)
      if (_filterOptions['current_visitors'] == true) {
        final today = DateTime.now();
        final todayString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

        final visitorSnapshot = await _firestore
            .collection('attendanceHistory')
            .doc(todayString)
            .collection('records')
            .where('libraryId', isEqualTo: widget.libraryId)
            .where('status', isEqualTo: 'checked_in')
            .get();

        visitorSnapshot.docs.forEach((doc) {
          final data = doc.data();
          if (data['studentId'] != null) {
            studentIds.add(data['studentId'] as String);
          }
        });
      }

      // All subscribers to this library
      if (_filterOptions['all_subscribers'] == true) {
        final subscribersSnapshot = await _firestore
            .collection('libraries')
            .doc(widget.libraryId)
            .collection('subscribers')
            .get();

        subscribersSnapshot.docs.forEach((doc) {
          studentIds.add(doc.id);
        });
      }

      // Current seat owners
      if (_filterOptions['seat_owners'] == true) {
        final bookingsSnapshot = await _firestore
            .collection('seatBookings')
            .where('libraryId', isEqualTo: widget.libraryId)
            .where('status', isEqualTo: 'active')
            .get();

        bookingsSnapshot.docs.forEach((doc) {
          final data = doc.data();
          if (data['studentId'] != null) {
            studentIds.add(data['studentId'] as String);
          }
        });
      }

      return studentIds.toList();
    } catch (e) {
      print('Error getting filtered students: $e');
      return [];
    }
  }

  // Call cloud function to handle FCM sending
  Future<void> _callSendNotificationsFunction({
    required String notificationId,
    required String title,
    required String message,
    required String notificationType,
    required List<String> targetUserIds,
  }) async {
    try {
      // In production, you would call a Firebase Cloud Function here
      // This is a placeholder showing the expected data structure

      // Example using Firebase HTTP callable functions
      /*
      final HttpsCallable sendNotifications =
          FirebaseFunctions.instance.httpsCallable('sendLibrarianNotifications');

      final result = await sendNotifications.call({
        'notificationId': notificationId,
        'title': title,
        'message': message,
        'type': notificationType,
        'libraryId': widget.libraryId,
        'librarianId': widget.librarianId,
        'targetUserIds': targetUserIds,
      });

      print('Cloud function result: ${result.data}');
      */

      // For demo purposes, let's directly create notifications in Firestore
      // In production, this would be handled by the cloud function
      final batch = _firestore.batch();

      for (final userId in targetUserIds) {
        final notificationRef = _firestore.collection('notifications').doc();

        batch.set(notificationRef, {
          'userId': userId,
          'title': title,
          'message': message,
          'type': notificationType,
          'read': false,
          'libraryId': widget.libraryId,
          'senderType': 'librarian',
          'senderId': widget.librarianId,
          'parentNotificationId': notificationId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error calling sendNotifications function: $e');
      throw e;
    }
  }

  void _resetForm() {
    _titleController.clear();
    _messageController.clear();
    _notificationType = 'announcement';
    _isTargetingSpecificUsers = false;
    _selectedStudents = [];
    _filterOptions = {
      'current_visitors': false,
      'all_subscribers': false,
      'seat_owners': false,
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openStudentSelectionDialog() async {
    final selectedStudents = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentSelectionScreen(
          libraryId: widget.libraryId,
          initialSelection: _selectedStudents,
        ),
      ),
    );

    if (selectedStudents != null) {
      setState(() {
        _selectedStudents = selectedStudents;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Send Notifications'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Type Selector
              Text(
                'Notification Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildNotificationTypeSelector(),
              SizedBox(height: 16),

              // Target Student Selector
              Text(
                'Target Students',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildTargetStudentsSelector(),
              SizedBox(height: 16),

              // Notification Content
              Text(
                'Notification Content',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Notification Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Notification Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),

              // Send Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendNotification,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('SEND NOTIFICATION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTypeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _notificationType,
          items: [
            DropdownMenuItem(
              value: 'announcement',
              child: Text('Announcement'),
            ),
            DropdownMenuItem(
              value: 'reminder',
              child: Text('Reminder'),
            ),
            DropdownMenuItem(
              value: 'alert',
              child: Text('Alert'),
            ),
            DropdownMenuItem(
              value: 'promotion',
              child: Text('Promotion'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _notificationType = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildTargetStudentsSelector() {
    return Column(
      children: [
        // Switch between specific users and filters
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: Text('Use Filters'),
                  value: false,
                  groupValue: _isTargetingSpecificUsers,
                  onChanged: (value) {
                    setState(() {
                      _isTargetingSpecificUsers = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: Text('Select Students'),
                  value: true,
                  groupValue: _isTargetingSpecificUsers,
                  onChanged: (value) {
                    setState(() {
                      _isTargetingSpecificUsers = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Show appropriate selector based on choice
        _isTargetingSpecificUsers
            ? _buildSpecificStudentsSelector()
            : _buildStudentFiltersSelector(),
      ],
    );
  }

  Widget _buildSpecificStudentsSelector() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Students: ${_selectedStudents.length}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _openStudentSelectionDialog,
                    child: Text('SELECT'),
                  ),
                ],
              ),
              if (_selectedStudents.isNotEmpty) ...[
                Divider(),
                Container(
                  height: 100,
                  child: ListView.builder(
                    itemCount: _selectedStudents.length,
                    itemBuilder: (context, index) {
                      final student = _selectedStudents[index];
                      return ListTile(
                        dense: true,
                        title: Text(student['name'] ?? 'Unknown'),
                        subtitle: Text(student['email'] ?? 'No email'),
                        leading: CircleAvatar(
                          child: Text(student['name']?[0] ?? 'U'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentFiltersSelector() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Target Groups:', style: TextStyle(fontWeight: FontWeight.bold)),
          CheckboxListTile(
            title: Text('Current Visitors'),
            subtitle: Text('Students currently checked in'),
            value: _filterOptions['current_visitors'],
            onChanged: (value) {
              setState(() {
                _filterOptions['current_visitors'] = value!;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Subscribers'),
            subtitle: Text('Students who subscribed to library updates'),
            value: _filterOptions['all_subscribers'],
            onChanged: (value) {
              setState(() {
                _filterOptions['all_subscribers'] = value!;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Active Seat Owners'),
            subtitle: Text('Students with active seat bookings'),
            value: _filterOptions['seat_owners'],
            onChanged: (value) {
              setState(() {
                _filterOptions['seat_owners'] = value!;
              });
            },
          ),
        ],
      ),
    );
  }
}

// Student selection screen (separate screen)
class StudentSelectionScreen extends StatefulWidget {
  final String libraryId;
  final List<Map<String, dynamic>> initialSelection;

  const StudentSelectionScreen({
    Key? key,
    required this.libraryId,
    required this.initialSelection,
  }) : super(key: key);

  @override
  _StudentSelectionScreenState createState() => _StudentSelectionScreenState();
}

class _StudentSelectionScreenState extends State<StudentSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _selectedStudents = [];

  @override
  void initState() {
    super.initState();
    _selectedStudents = List.from(widget.initialSelection);
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get list of students who visited this library
      final querySnapshot = await _firestore
          .collection('attendanceHistory')
          .where('libraryId', isEqualTo: widget.libraryId)
          .limit(100) // Limit for performance
          .get();

      // Extract unique student IDs
      Set<String> studentIds = {};
      querySnapshot.docs.forEach((doc) {
        final data = doc.data();
        if (data['studentId'] != null) {
          studentIds.add(data['studentId']);
        }
      });

      // Get student details
      List<Map<String, dynamic>> students = [];

      for (final studentId in studentIds) {
        final studentDoc = await _firestore
            .collection('students')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          final data = studentDoc.data()!;
          students.add({
            'id': studentId,
            'name': data['fullName'] ?? data['displayName'] ?? 'Unknown',
            'email': data['email'] ?? 'No email',
            'photoUrl': data['photoUrl'],
          });
        }
      }

      setState(() {
        _allStudents = students;
        _filterStudents('');
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching students: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterStudents(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStudents = List.from(_allStudents);
      } else {
        _filteredStudents = _allStudents.where((student) {
          final name = student['name']?.toString().toLowerCase() ?? '';
          final email = student['email']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || email.contains(searchLower);
        }).toList();
      }
    });
  }

  void _toggleStudent(Map<String, dynamic> student) {
    final studentId = student['id'];
    final isSelected = _selectedStudents.any((s) => s['id'] == studentId);

    setState(() {
      if (isSelected) {
        _selectedStudents.removeWhere((s) => s['id'] == studentId);
      } else {
        _selectedStudents.add(student);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Students'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedStudents);
            },
            child: Text(
              'DONE (${_selectedStudents.length})',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search students',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterStudents,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                ? Center(child: Text('No students found'))
                : ListView.builder(
              itemCount: _filteredStudents.length,
              itemBuilder: (context, index) {
                final student = _filteredStudents[index];
                final isSelected = _selectedStudents.any(
                        (s) => s['id'] == student['id']);

                return ListTile(
                  title: Text(student['name'] ?? 'Unknown'),
                  subtitle: Text(student['email'] ?? 'No email'),
                  leading: CircleAvatar(
                    backgroundImage: student['photoUrl'] != null
                        ? NetworkImage(student['photoUrl'])
                        : null,
                    child: student['photoUrl'] == null
                        ? Text(student['name']?[0] ?? 'U')
                        : null,
                  ),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      _toggleStudent(student);
                    },
                  ),
                  onTap: () {
                    _toggleStudent(student);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}