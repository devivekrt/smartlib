// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-22 12:36:56
// Current User's Login: devivekrti

// File: lib/screens/notification_center_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../function/notification_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String studentId;

  const NotificationCenterScreen({
    Key? key,
    required this.studentId,
  }) : super(key: key);

  @override
  _NotificationCenterScreenState createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  List<DocumentSnapshot> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get notifications from Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('userNotifications')
          .where('userId', isEqualTo: widget.studentId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      setState(() {
        _notifications = querySnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          return _buildNotificationItem(_notifications[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    final bool isRead = data['read'] ?? false;
    final String title = data['title'] ?? 'Notification';
    final String message = data['message'] ?? '';
    final String type = data['type'] ?? 'general';

    // Format timestamp
    String timeDisplay = 'Just now';
    if (data['createdAt'] != null) {
      final timestamp = data['createdAt'] as Timestamp;
      final dateTime = timestamp.toDate();
      timeDisplay = DateFormat.yMMMd().add_jm().format(dateTime);
    }

    // Select icon based on notification type
    IconData notificationIcon;
    Color iconColor;

    switch (type) {
      case 'announcement':
        notificationIcon = Icons.campaign;
        iconColor = Colors.blue;
        break;
      case 'reminder':
        notificationIcon = Icons.alarm;
        iconColor = Colors.orange;
        break;
      case 'alert':
        notificationIcon = Icons.warning;
        iconColor = Colors.red;
        break;
      default:
        notificationIcon = Icons.notifications;
        iconColor = Colors.blue;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isRead ? null : Colors.blue.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          foregroundColor: iconColor,
          child: Icon(notificationIcon),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(message),
            SizedBox(height: 4),
            Text(
              timeDisplay,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: isRead
            ? null
            : Icon(Icons.circle, color: Colors.blue, size: 10),
        onTap: () {
          if (!isRead) {
            // Mark as read
            _notificationService.markNotificationAsRead(
              document.id,
              widget.studentId,
            );

            // Update UI
            setState(() {
              data['read'] = true;
            });
          }

          // Show the notification in detail
          _showNotificationDetail(data);
        },
      ),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(data['title'] ?? 'Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['message'] ?? ''),
              SizedBox(height: 16),
              if (data['createdAt'] != null) ...[
                Text(
                  'Received: ${DateFormat.yMMMd().add_jm().format((data['createdAt'] as Timestamp).toDate())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}