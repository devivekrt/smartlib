// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../models/library_model.dart';
import '../../services/verification_service.dart';
import '../../theme/theme.dart';
import 'library_verification_screen.dart';

class MasterPanelDashboard extends StatefulWidget {
  final String adminId;
  
  const MasterPanelDashboard({
    super.key,
    required this.adminId,
  });

  @override
  State<MasterPanelDashboard> createState() => _MasterPanelDashboardState();
}

class _MasterPanelDashboardState extends State<MasterPanelDashboard> with SingleTickerProviderStateMixin {
  final VerificationService _verificationService = VerificationService();
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  Map<String, int> _stats = {};
  List<LibraryModel> _filteredLibraries = [];
  String _selectedStatus = 'pending';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
    _loadLibraries();
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        final statuses = ['pending', 'in_review', 'verified', 'rejected'];
        _selectedStatus = statuses[_tabController.index];
        _loadLibraries();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _verificationService.getVerificationStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading statistics: $e')),
      );
    }
  }

  Future<void> _loadLibraries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final libraries = await _verificationService.searchLibraries(
        _searchController.text,
        _selectedStatus,
      );
      setState(() {
        _filteredLibraries = libraries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading libraries: $e')),
      );
    }
  }

  void _onSearchChanged(String query) {
    _loadLibraries();
  }

  void _navigateToVerification(LibraryModel library) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LibraryVerificationScreen(
          library: library,
          adminId: widget.adminId,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from verification screen
      _loadStats();
      _loadLibraries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Master Panel',
          style: AppTextStyles.heading1.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadStats();
              _loadLibraries();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          Container(
            color: AppColors.primaryBlue,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Pending',
                        count: _stats['pending'] ?? 0,
                        color: AppColors.warning,
                        icon: Icons.pending_actions,
                      ),
                    ),
                    Gap(12),
                    Expanded(
                      child: _StatCard(
                        title: 'In Review',
                        count: _stats['in_review'] ?? 0,
                        color: Colors.blue,
                        icon: Icons.rate_review,
                      ),
                    ),
                  ],
                ),
                Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Verified',
                        count: _stats['verified'] ?? 0,
                        color: AppColors.success,
                        icon: Icons.verified,
                      ),
                    ),
                    Gap(12),
                    Expanded(
                      child: _StatCard(
                        title: 'Rejected',
                        count: _stats['rejected'] ?? 0,
                        color: AppColors.error,
                        icon: Icons.cancel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search libraries by name, location, or owner...',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
                filled: true,
                fillColor: AppColors.inputBackground,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryBlue,
              tabs: [
                Tab(text: 'Pending (${_stats['pending'] ?? 0})'),
                Tab(text: 'In Review (${_stats['in_review'] ?? 0})'),
                Tab(text: 'Verified (${_stats['verified'] ?? 0})'),
                Tab(text: 'Rejected (${_stats['rejected'] ?? 0})'),
              ],
            ),
          ),

          // Library List
          Expanded(
            child: Container(
              color: AppColors.background,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredLibraries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.library_books,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              Gap(16),
                              Text(
                                'No libraries found',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Try adjusting your search or check other tabs',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadLibraries(),
                          child: ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _filteredLibraries.length,
                            itemBuilder: (context, index) {
                              final library = _filteredLibraries[index];
                              return _LibraryCard(
                                library: library,
                                onTap: () => _navigateToVerification(library),
                              );
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _LibraryCard extends StatelessWidget {
  final LibraryModel library;
  final VoidCallback onTap;

  const _LibraryCard({
    required this.library,
    required this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'in_review':
        return Colors.blue;
      case 'verified':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'in_review':
        return 'In Review';
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      library.libraryName ?? 'Unknown Library',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(library.verificationStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(library.verificationStatus),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _formatStatus(library.verificationStatus),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _getStatusColor(library.verificationStatus),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Gap(8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                  Gap(4),
                  Text(
                    library.ownerName ?? 'Unknown Owner',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Gap(4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                  Gap(4),
                  Expanded(
                    child: Text(
                      library.location ?? 'Unknown Location',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Gap(4),
              Row(
                children: [
                  Icon(Icons.event_seat, size: 16, color: AppColors.textSecondary),
                  Gap(4),
                  Text(
                    '${library.totalSeats ?? 0} seats',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Spacer(),
                  Text(
                    library.createdAt != null
                        ? 'Submitted ${_formatDate(library.createdAt!)}'
                        : 'Recently submitted',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (library.rejectionReason != null) ...[
                Gap(8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: AppColors.error),
                      Gap(8),
                      Expanded(
                        child: Text(
                          'Rejection Reason: ${library.rejectionReason}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}