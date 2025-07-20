// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../theme/theme.dart';
import 'master_panel_dashboard.dart';

class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({super.key});

  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  final TextEditingController _adminIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Mock admin credentials - in production, this would be handled by Firebase Auth
  final List<Map<String, String>> _mockAdmins = [
    {'id': 'admin001', 'password': 'admin123', 'name': 'Super Admin'},
    {'id': 'verify001', 'password': 'verify123', 'name': 'Verification Admin'},
    {'id': 'test', 'password': 'test', 'name': 'Test Admin'},
  ];

  Future<void> _authenticate() async {
    final adminId = _adminIdController.text.trim();
    final password = _passwordController.text.trim();

    if (adminId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter admin ID and password'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate authentication delay
    await Future.delayed(Duration(seconds: 1));

    // Check mock credentials
    final admin = _mockAdmins.firstWhere(
      (admin) => admin['id'] == adminId && admin['password'] == password,
      orElse: () => {},
    );

    setState(() {
      _isLoading = false;
    });

    if (admin.isNotEmpty) {
      // Authentication successful
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MasterPanelDashboard(adminId: adminId),
        ),
      );
    } else {
      // Authentication failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid admin credentials'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Admin Access',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Admin Icon
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 64,
                color: AppColors.primaryBlue,
              ),
            ),

            Gap(32),

            Text(
              'Master Panel Access',
              style: AppTextStyles.heading1.copyWith(
                color: AppColors.textPrimary,
              ),
            ),

            Gap(8),

            Text(
              'Enter your admin credentials to access the library verification system',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            Gap(32),

            // Admin ID Field
            TextField(
              controller: _adminIdController,
              decoration: InputDecoration(
                labelText: 'Admin ID',
                hintText: 'Enter your admin ID',
                prefixIcon: Icon(Icons.person, color: AppColors.primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
              ),
              enabled: !_isLoading,
            ),

            Gap(16),

            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icon(Icons.lock, color: AppColors.primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _authenticate(),
            ),

            Gap(32),

            // Login Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          Gap(12),
                          Text(
                            'Authenticating...',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Access Master Panel',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            Gap(24),

            // Demo Credentials Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: AppColors.warning, size: 20),
                      Gap(8),
                      Text(
                        'Demo Credentials',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Gap(8),
                  Text(
                    'For testing purposes, use:',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Gap(4),
                  ..._mockAdmins.map((admin) => Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      'ID: ${admin['id']} | Password: ${admin['password']} (${admin['name']})',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}