import 'package:flutter/material.dart';
import 'package:smartlib/student/profile_screen.dart';
import 'package:smartlib/student/qr_code_screen.dart';
import 'package:smartlib/student/student_home_page.dart';
import 'activity_screen.dart';
import 'library_market_place.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  // Page widgets: 0=Home, 1=Marketplace, 2=Activity, 3=Profile
  late final List<Widget> _pages = [
    StudentHomePage(
      onScanButtonPressed: () => _selectQRScan(),
      onBookSeatPressed: () => _selectTab(1),
    ),
    LibraryMarketplace(isSignedUp: false),
    ActivityScreen(), // Create this page for check-in and checkout
    ProfileScreen(),
  ];

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _selectQRScan() async {
    // Show QRScannerScreen as modal or push. Here, as modal bottom sheet:
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QRScannerScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildScanButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Bottom Navigation Bar with center gap for QR Code Scanner button
  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: "Home",
                index: 0,
              ),
              // Marketplace
              _buildNavItem(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: "Marketplace",
                index: 1,
              ),
              const SizedBox(width: 48), // Space for FAB
              // Activity
              _buildNavItem(
                icon: Icons.list_alt_outlined,
                activeIcon: Icons.list_alt,
                label: "Activity",
                index: 2,
              ),
              // Profile
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: "Profile",
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Center Floating QR Scan Button
  Widget _buildScanButton() {
    return FloatingActionButton(
      onPressed: _selectQRScan,
      backgroundColor: Color(0xff1940CC),
      elevation: 6,
      child: Icon(
        Icons.qr_code_scanner,
        color: Colors.white,
        size: 28,
      ),
      shape: CircleBorder(),
    );
  }

  // Navigation Item
  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _selectTab(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            size: 24,
            color: isSelected ? Color(0xff1940CC) : Colors.grey,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Color(0xff1940CC) : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}