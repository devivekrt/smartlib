

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' as gg;
import 'dart:math' as math;
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
  final gg.FirebaseDatabase _database = gg.FirebaseDatabase.instance;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _notificationType = 'announcement'; // Default type
  bool _isLoading = false;
  bool _isSendingNotification = false;
  bool _isTargetingSpecificUsers = false;
  List<Map<String, dynamic>> _selectedStudents = [];
  int _estimatedRecipients = 0;

  // Filter options
  Map<String, bool> _filterOptions = {
    'current_visitors': false,
    'all_subscribers': false,
    'seat_owners': false,
  };

  @override
  void initState() {
    super.initState();
    // Estimate recipient count when filters change
    _estimateFilterRecipients();
  }

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

    // Validate that at least one filter is selected if using filters
    if (!_isTargetingSpecificUsers &&
        !_filterOptions.values.any((selected) => selected)) {
      _showError('Please select at least one filter option');
      return;
    }

    // Validate that some students are selected if targeting specific users
    if (_isTargetingSpecificUsers && _selectedStudents.isEmpty) {
      _showError('Please select at least one student');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSendingNotification = true;
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
          _isSendingNotification = false;
        });
        return;
      }

      // Add library info to notification
      final library = await _firestore
          .collection('libraries')
          .doc(widget.libraryId)
          .get();

      final String libraryName = library.exists
          ? (library.data()?['libraryName'] ?? 'Unknown Library')
          : 'Library';

      // Get librarian info
      final librarian = await _firestore
          .collection('librarians')
          .doc(widget.librarianId)
          .get();

      final String librarianName = librarian.exists
          ? (librarian.data()?['name'] ?? 'Library Staff')
          : 'Library Staff';

      // Create master notification document
      final notificationData = {
        'title': title,
        'message': message,
        'senderType': 'librarian',
        'senderId': widget.librarianId,
        'senderName': librarianName,
        'libraryId': widget.libraryId,
        'libraryName': libraryName,
        'type': _notificationType,
        'sentAt': FieldValue.serverTimestamp(),
        'targetUserCount': targetUserIds.length,
        'targetUserIds': targetUserIds,
        'status': 'sending',
      };

      // Save master notification to Firestore
      final notificationDoc = await _firestore
          .collection('masterNotifications')
          .add(notificationData);

      print('[2025-06-29 14:53:35] devivekrt: Created master notification: ${notificationDoc.id}');

      // Create individual notifications for each user
      await _createIndividualNotifications(
        notificationId: notificationDoc.id,
        title: title,
        message: message,
        librarianName: librarianName,
        libraryName: libraryName,
        notificationType: _notificationType,
        targetUserIds: targetUserIds,
      );

      // Update master notification status
      await notificationDoc.update({
        'status': 'sent',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Reset form
      _resetForm();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sent to ${targetUserIds.length} students'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('[2025-06-29 14:53:35] devivekrt: Error sending notification: $e');
      _showError('Failed to send notification: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isSendingNotification = false;
      });
    }
  }

  // Create individual notifications and handle FCM integration via Firestore trigger
  Future<void> _createIndividualNotifications({
    required String notificationId,
    required String title,
    required String message,
    required String librarianName,
    required String libraryName,
    required String notificationType,
    required List<String> targetUserIds,
  }) async {
    try {
      // Create and send notifications in batches to avoid Firestore limits
      const int batchSize = 500;
      int processedCount = 0;

      for (int i = 0; i < targetUserIds.length; i += batchSize) {
        final int end = (i + batchSize < targetUserIds.length)
            ? i + batchSize
            : targetUserIds.length;

        final List<String> batchUserIds = targetUserIds.sublist(i, end);
        final WriteBatch batch = _firestore.batch();

        // For each user in this batch
        for (final userId in batchUserIds) {
          // Create individual notification document
          final notificationRef = _firestore
              .collection('userNotifications')
              .doc();

          batch.set(notificationRef, {
            'userId': userId,
            'title': title,
            'message': message,
            'type': notificationType,
            'read': false,
            'libraryId': widget.libraryId,
            'libraryName': libraryName,
            'senderType': 'librarian',
            'senderId': widget.librarianId,
            'senderName': librarianName,
            'parentNotificationId': notificationId,
            'createdAt': FieldValue.serverTimestamp(),
            // Add this flag to trigger Firebase Cloud Function
            'sendPushNotification': true,
          });

          // Get user's FCM token from RTDB and add to notification
          try {
            final tokenSnapshot = await _database
                .ref('appStatus/$userId/fcm/token')
                .get();

            if (tokenSnapshot.exists && tokenSnapshot.value != null) {
              final token = tokenSnapshot.value.toString();
              if (token.isNotEmpty) {
                // Include the token in the notification document
                batch.update(notificationRef, {
                  'fcmToken': token,
                });
              }
            }
          } catch (e) {
            print('[2025-06-29 14:53:35] devivekrt: Error getting FCM token for user $userId: $e');
          }
        }

        // Commit this batch of notifications
        await batch.commit();
        processedCount += batchUserIds.length;

        // Update UI with progress
        setState(() {
          _isLoading = true;
          _estimatedRecipients = processedCount;
        });
      }

      // Create a trigger document to signal the cloud function to send the notifications
      // This is an alternative approach to using the Firebase Functions SDK directly
      await _firestore.collection('notificationTriggers').add({
        'masterNotificationId': notificationId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'targetCount': targetUserIds.length,
      });

      print('[2025-06-29 14:53:35] devivekrt: Created notification trigger for cloud function');

    } catch (e) {
      print('[2025-06-29 14:53:35] devivekrt: Error creating individual notifications: $e');
      throw e;
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
            .where('status', whereIn: ['active', 'completed'])
            .get();

        visitorSnapshot.docs.forEach((doc) {
          final data = doc.data();
          if (data['studentId'] != null) {
            studentIds.add(data['studentId'] as String);
          }
        });

        print('[2025-06-29 14:53:35] devivekrt: Found ${visitorSnapshot.docs.length} current visitors');
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

        print('[2025-06-29 14:53:35] devivekrt: Found ${subscribersSnapshot.docs.length} subscribers');
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

        print('[2025-06-29 14:53:35] devivekrt: Found ${bookingsSnapshot.docs.length} seat owners');
      }

      return studentIds.toList();
    } catch (e) {
      print('[2025-06-29 14:53:35] devivekrt: Error getting filtered students: $e');
      return [];
    }
  }

  // Estimate the number of recipients
  Future<void> _estimateFilterRecipients() async {
    if (_isTargetingSpecificUsers) {
      setState(() {
        _estimatedRecipients = _selectedStudents.length;
      });
      return;
    }

    // Only estimate if at least one filter is selected
    if (!_filterOptions.values.any((selected) => selected)) {
      setState(() {
        _estimatedRecipients = 0;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final recipients = await _getFilteredStudentIds();
      setState(() {
        _estimatedRecipients = recipients.length;
        _isLoading = false;
      });
    } catch (e) {
      print('[2025-06-29 14:53:35] devivekrt: Error estimating recipients: $e');
      setState(() {
        _estimatedRecipients = 0;
        _isLoading = false;
      });
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
    _estimatedRecipients = 0;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _openStudentSelectionDialog() async {
    final selectedStudents = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentSelectionScreen(
          libraryId: widget.libraryId,
          librarianId: widget.librarianId,
          initialSelection: _selectedStudents,
        ),
      ),
    );

    if (selectedStudents != null) {
      setState(() {
        _selectedStudents = selectedStudents;
        _estimatedRecipients = _selectedStudents.length;
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
      body: _isSendingNotification
          ? _buildSendingProgress()
          : _buildNotificationForm(),
    );
  }

  Widget _buildSendingProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Sending notifications...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Processed: $_estimatedRecipients notifications',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationForm() {
    return SingleChildScrollView(
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

            // Estimated recipients info
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isLoading
                          ? 'Estimating number of recipients...'
                          : 'This notification will be sent to $_estimatedRecipients recipient${_estimatedRecipients != 1 ? 's' : ''}.',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                hintText: 'Enter a clear, concise title',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                if (value.length > 100) {
                  return 'Title should be less than 100 characters';
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
                hintText: 'Enter the message body here',
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a message';
                }
                if (value.length > 2000) {
                  return 'Message should be less than 2000 characters';
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
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : Text('SEND NOTIFICATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                ),
              ),
            ),
          ],
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
              child: Row(
                children: [
                  Icon(Icons.campaign, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Announcement'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'reminder',
              child: Row(
                children: [
                  Icon(Icons.alarm, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Reminder'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'alert',
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Alert'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'promotion',
              child: Row(
                children: [
                  Icon(Icons.sell, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Promotion'),
                ],
              ),
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
                      // Estimate recipients when switching modes
                      _estimateFilterRecipients();
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
                      // Estimate recipients when switching modes
                      _estimateFilterRecipients();
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
                  ElevatedButton.icon(
                    onPressed: _openStudentSelectionDialog,
                    icon: Icon(Icons.person_add),
                    label: Text('SELECT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              if (_selectedStudents.isNotEmpty) ...[
                Divider(),
                Container(
                  height: 150,
                  child: ListView.builder(
                    itemCount: math.min(_selectedStudents.length, 5),
                    itemBuilder: (context, index) {
                      final student = _selectedStudents[index];
                      return ListTile(
                        dense: true,
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
                        trailing: index == 4 && _selectedStudents.length > 5
                            ? Chip(
                          label: Text(
                            '+${_selectedStudents.length - 5} more',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.blue,
                        )
                            : null,
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
          SizedBox(height: 8),

          // More visually appealing filter options with icons
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _filterOptions['current_visitors'] == true
                  ? Colors.blue.withOpacity(0.1)
                  : null,
              border: Border.all(
                color: _filterOptions['current_visitors'] == true
                    ? Colors.blue
                    : Colors.grey.withOpacity(0.5),
              ),
            ),
            margin: EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              title: Text('Current Visitors'),
              subtitle: Text('Students currently checked in'),
              secondary: Icon(
                Icons.people,
                color: _filterOptions['current_visitors'] == true
                    ? Colors.blue
                    : Colors.grey,
              ),
              value: _filterOptions['current_visitors'],
              onChanged: (value) {
                setState(() {
                  _filterOptions['current_visitors'] = value!;
                  _estimateFilterRecipients();
                });
              },
            ),
          ),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _filterOptions['all_subscribers'] == true
                  ? Colors.blue.withOpacity(0.1)
                  : null,
              border: Border.all(
                color: _filterOptions['all_subscribers'] == true
                    ? Colors.blue
                    : Colors.grey.withOpacity(0.5),
              ),
            ),
            margin: EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              title: Text('Subscribers'),
              subtitle: Text('Students who subscribed to library updates'),
              secondary: Icon(
                Icons.notifications_active,
                color: _filterOptions['all_subscribers'] == true
                    ? Colors.blue
                    : Colors.grey,
              ),
              value: _filterOptions['all_subscribers'],
              onChanged: (value) {
                setState(() {
                  _filterOptions['all_subscribers'] = value!;
                  _estimateFilterRecipients();
                });
              },
            ),
          ),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _filterOptions['seat_owners'] == true
                  ? Colors.blue.withOpacity(0.1)
                  : null,
              border: Border.all(
                color: _filterOptions['seat_owners'] == true
                    ? Colors.blue
                    : Colors.grey.withOpacity(0.5),
              ),
            ),
            child: CheckboxListTile(
              title: Text('Active Seat Owners'),
              subtitle: Text('Students with active seat bookings'),
              secondary: Icon(
                Icons.event_seat,
                color: _filterOptions['seat_owners'] == true
                    ? Colors.blue
                    : Colors.grey,
              ),
              value: _filterOptions['seat_owners'],
              onChanged: (value) {
                setState(() {
                  _filterOptions['seat_owners'] = value!;
                  _estimateFilterRecipients();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}


// Student selection screen (separate screen)
class StudentSelectionScreen extends StatefulWidget {
  final String libraryId;
  final String librarianId;
  final List<Map<String, dynamic>> initialSelection;

  const StudentSelectionScreen({
    Key? key,
    required this.libraryId,
    required this.librarianId,
    required this.initialSelection,
  }) : super(key: key);

  @override
  _StudentSelectionScreenState createState() => _StudentSelectionScreenState();
}

class _StudentSelectionScreenState extends State<StudentSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _selectedStudents = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _selectedStudents = List.from(widget.initialSelection);
    _fetchStudents();
  }

  Future<void> _fetchStudents({bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMoreData || _isLoadingMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Base query to get attendance records for this library
      Query attendanceQuery = _firestore
          .collection('attendanceHistory')
          .where('libraryId', isEqualTo: widget.libraryId)
          .limit(_pageSize);

      if (loadMore && _lastDocument != null) {
        attendanceQuery = attendanceQuery.startAfterDocument(_lastDocument!);
      }

      final attendanceSnapshot = await attendanceQuery.get();

      if (attendanceSnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
          _isLoading = false;
        });
        return;
      }

      // Save last document for pagination
      _lastDocument = attendanceSnapshot.docs.last;

      // Extract unique student IDs
      Set<String> studentIds = {};
      attendanceSnapshot.docs.forEach((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['studentId'] != null) {
          studentIds.add(data['studentId'] as String);
        }
      });

      print('[2025-06-29 14:45:49] devivekrt: Found ${studentIds.length} unique student IDs');

      // Get student details in batches to avoid too many Firestore reads
      List<Map<String, dynamic>> newStudents = [];
      List<List<String>> batches = _batchIds(studentIds.toList(), 10);

      for (final batch in batches) {
        List<Future<DocumentSnapshot>> futures = [];

        for (final studentId in batch) {
          // Avoid fetching already selected students
          bool alreadySelected = false;
          for (final selected in _selectedStudents) {
            if (selected['id'] == studentId) {
              alreadySelected = true;
              break;
            }
          }

          if (!alreadySelected) {
            futures.add(_firestore.collection('students').doc(studentId).get());
          }
        }

        final results = await Future.wait(futures);

        for (final doc in results) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            newStudents.add({
              'id': doc.id,
              'name': data['fullName'] ?? data['displayName'] ?? 'Unknown',
              'email': data['email'] ?? 'No email',
              'photoUrl': data['photoUrl'],
              'lastVisit': DateTime.now().toString(), // Placeholder
            });
          }
        }
      }

      setState(() {
        if (loadMore) {
          _allStudents.addAll(newStudents);
        } else {
          _allStudents = newStudents;
        }
        _filterStudents(_searchQuery);
        _isLoading = false;
        _isLoadingMore = false;
        _hasMoreData = attendanceSnapshot.docs.length >= _pageSize;
      });

      print('[2025-06-29 14:45:49] devivekrt: Loaded ${newStudents.length} student details');
    } catch (e) {
      print('[2025-06-29 14:45:49] devivekrt: Error fetching students: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // Helper to batch IDs into smaller groups
  List<List<T>> _batchIds<T>(List<T> items, int batchSize) {
    List<List<T>> batches = [];
    for (var i = 0; i < items.length; i += batchSize) {
      var end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
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

  void _selectAll() {
    setState(() {
      // Add all filtered students that aren't already selected
      for (final student in _filteredStudents) {
        if (!_selectedStudents.any((s) => s['id'] == student['id'])) {
          _selectedStudents.add(student);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStudents = [];
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
          // Search and action bar
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search students',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _filterStudents('');
                        // Clear the text field
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  onChanged: _filterStudents,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: Icon(Icons.select_all),
                      label: Text('Select All'),
                    ),
                    TextButton.icon(
                      onPressed: _clearSelection,
                      icon: Icon(Icons.clear_all),
                      label: Text('Clear Selection'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Selected count chip
          if (_selectedStudents.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  '${_selectedStudents.length} students selected',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Student list
          Expanded(
            child: _isLoading && _allStudents.isEmpty
                ? Center(child: CircularProgressIndicator())
                : _buildStudentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    if (_filteredStudents.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No students found matching "$_searchQuery"',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_filteredStudents.isEmpty && _allStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No students have visited this library yet',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoading &&
            !_isLoadingMore &&
            _hasMoreData &&
            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _fetchStudents(loadMore: true);
        }
        return true;
      },
      child: ListView.builder(
        itemCount: _filteredStudents.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredStudents.length) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final student = _filteredStudents[index];
          final isSelected = _selectedStudents.any(
                  (s) => s['id'] == student['id']);

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: isSelected ? 3 : 1,
            color: isSelected ? Colors.blue.withOpacity(0.1) : null,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                student['name'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
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
                onChanged: (value) => _toggleStudent(student),
                activeColor: Colors.blue,
              ),
              onTap: () => _toggleStudent(student),
            ),
          );
        },
      ),
    );
  }
}