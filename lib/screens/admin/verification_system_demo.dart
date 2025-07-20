// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../theme/theme.dart';
import '../../models/library_model.dart';
import '../../services/verification_service.dart';
import '../admin/admin_access_screen.dart';

/// Integration test/demo screen to show how the verification system works
class VerificationSystemDemo extends StatefulWidget {
  const VerificationSystemDemo({super.key});

  @override
  State<VerificationSystemDemo> createState() => _VerificationSystemDemoState();
}

class _VerificationSystemDemoState extends State<VerificationSystemDemo> {
  final VerificationService _verificationService = VerificationService();
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _verificationService.getVerificationStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading stats: $e')),
      );
    }
  }

  Future<void> _createMockLibrary() async {
    // Create a mock library for testing
    final library = LibraryModel(
      id: "LIB_${DateTime.now().millisecondsSinceEpoch}",
      librarianId: "mock_librarian_001",
      libraryName: "Demo Test Library",
      ownerName: "Test Owner",
      location: "Test Location, City",
      locationLatitude: "28.6139", // New Delhi coordinates for testing
      locationLongitude: "77.2090",
      totalSeats: 50,
      description: "A test library for verification demo",
      verificationStatus: "pending",
      status: "pending",
      createdAt: DateTime.now(),
    );

    // Note: In real implementation, this would be saved to Firebase
    // For demo purposes, we'll just show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mock library created for testing verification'),
        backgroundColor: AppColors.success,
      ),
    );

    _loadStats(); // Refresh stats
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Verification System Demo',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Demo Info
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: AppColors.primaryBlue),
                            Gap(8),
                            Text(
                              'Master Panel Verification System',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Gap(12),
                        Text(
                          'This system allows administrators to verify library submissions through a comprehensive step-by-step process before making them public.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Gap(24),

                  // Current Statistics
                  Text(
                    'Current Statistics',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Gap(16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          _stats['pending'] ?? 0,
                          AppColors.warning,
                          Icons.pending_actions,
                        ),
                      ),
                      Gap(12),
                      Expanded(
                        child: _buildStatCard(
                          'In Review',
                          _stats['in_review'] ?? 0,
                          Colors.blue,
                          Icons.rate_review,
                        ),
                      ),
                    ],
                  ),
                  Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Verified',
                          _stats['verified'] ?? 0,
                          AppColors.success,
                          Icons.verified,
                        ),
                      ),
                      Gap(12),
                      Expanded(
                        child: _buildStatCard(
                          'Rejected',
                          _stats['rejected'] ?? 0,
                          AppColors.error,
                          Icons.cancel,
                        ),
                      ),
                    ],
                  ),

                  Gap(32),

                  // Verification Process Features
                  Text(
                    'Verification Process Features',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Gap(16),

                  _buildFeatureItem(
                    Icons.location_on,
                    'Location Verification',
                    'Verify library location within 50 meters using GPS',
                    AppColors.success,
                  ),
                  _buildFeatureItem(
                    Icons.photo_library,
                    'Image Validation',
                    'Upload and validate 3-5 indoor library images',
                    AppColors.warning,
                  ),
                  _buildFeatureItem(
                    Icons.event_seat,
                    'Seat Verification',
                    'Verify seat count and arrangement with QR management',
                    Colors.blue,
                  ),
                  _buildFeatureItem(
                    Icons.qr_code,
                    'QR Code Testing',
                    'Test check-in and check-out functionality',
                    AppColors.primaryBlue,
                  ),

                  Spacer(),

                  // Demo Actions
                  Text(
                    'Demo Actions',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Gap(16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _createMockLibrary,
                          icon: Icon(Icons.add_business),
                          label: Text('Create Mock Library'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppColors.primaryBlue),
                          ),
                        ),
                      ),
                      Gap(12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminAccessScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.admin_panel_settings),
                          label: Text('Access Admin Panel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              Spacer(),
              Text(
                count.toString(),
                style: AppTextStyles.heading2.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Gap(8),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gap(4),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}