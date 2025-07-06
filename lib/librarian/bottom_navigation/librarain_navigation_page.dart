import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:gap/gap.dart';
import 'package:flutter/services.dart'; // Add this import

import '../../data/string.dart';
import 'librarain_booking_page.dart';
import 'librarain_dashboard_page.dart';
import 'librarain_profile_page.dart';
import 'librarain_seats_page.dart';

class LibrarianNavigationPage extends StatefulWidget {
  const LibrarianNavigationPage({Key? key}) : super(key: key);

  @override
  State<LibrarianNavigationPage> createState() => _LibrarianNavigationPageState();
}

class _LibrarianNavigationPageState extends State<LibrarianNavigationPage> {
  // Navigation state
  int _currentIndex = 0;
  DateTime? _lastBackPressTime; // For double back to exit

  // Firebase instances
  final _firestore = FirebaseFirestore.instance;

  // Pending payments data
  List<Map<String, dynamic>> _pendingPayments = [];
  StreamSubscription? _pendingPaymentsSubscription;

  // Loading state
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchPendingPayments();

    // Set up periodic refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _fetchPendingPayments();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pendingPaymentsSubscription?.cancel();
    super.dispose();
  }

  // Navigate to a specific tab
  void _navigateToTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Handle back button press - COMPLETE FIX
  Future<bool> _handleBackButton() async {
    // If we're not on the home tab (index 0), navigate to home tab instead of exiting
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
      return false; // Prevent app exit
    }

    // We're on the home tab (index 0), implement double-back to exit
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;

      // Show warning toast/snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return false; // Don't exit the app yet
    }

    // This is the second back press within 2 seconds
    return true; // Allow the app to exit
  }

  // Fetch pending payments for notifications
  Future<void> _fetchPendingPayments() async {
    // Cancel existing subscription
    _pendingPaymentsSubscription?.cancel();

    try {
      // Listen for bookings with pending payments that need confirmation
      _pendingPaymentsSubscription = _firestore
          .collection('seatBookings')
          .where('paymentStatus', isEqualTo: 'pending')
          .snapshots()
          .listen(
            (snapshot) {
          if (!mounted) return;

          List<Map<String, dynamic>> payments = [];

          for (final doc in snapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            data['bookingId'] = doc.id;
            payments.add(data);
          }

          setState(() {
            _pendingPayments = payments;
          });
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading pending payments: $error'),
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching pending payments: ${e.toString()}'),
          ),
        );
      }
    }
  }

  // App bar title based on current tab
  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Librarian Dashboard';
      case 1:
        return 'Bookings';
      case 2:
        return 'Seats Board';
      case 3:
        return 'Profile';
      default:
        return 'Librarian Dashboard';
    }
  }

  // List of page widgets
  final List<Widget> _pages = [
    LibrarianDashboardPage(),
    LibrarianSeatBookingsScreen(),
    LibrarianSeatsPage(),
    LibrarianProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope( // Using PopScope instead of WillPopScope for Flutter 3.12+
      canPop: false, // Disable automatic popping
      onPopInvoked: (didPop) async {
        // Handle the back button press event
        if (didPop) return;

        // If not on home tab, go to home tab
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // We're on the home tab, check if we should exit
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;

          // Show warning toast/snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // This is the second press within 2 seconds, exit the app
        SystemNavigator.pop(); // Properly exit the app
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _getAppBarTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? _buildLoadingScreen()
            : IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xff1940CC),
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.calendar_month),
                  if (_pendingPayments.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '${_pendingPayments.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Bookings',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.event_seat),
              label: 'Seats',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // Loading screen
  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xff1940CC)),
          SizedBox(height: 16),
          Text('Loading library data...'),
        ],
      ),
    );
  }
}