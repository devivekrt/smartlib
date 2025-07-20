// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../models/library_model.dart';
import '../../models/verification_model.dart';
import '../../services/verification_service.dart';
import '../../theme/theme.dart';
import '../../widgets/verification/location_verification_widget.dart';
import '../../widgets/verification/image_upload_widget.dart';
import '../../widgets/verification/seat_verification_widget.dart';
import '../../widgets/verification/qr_verification_widget.dart';

class LibraryVerificationScreen extends StatefulWidget {
  final LibraryModel library;
  final String adminId;

  const LibraryVerificationScreen({
    super.key,
    required this.library,
    required this.adminId,
  });

  @override
  State<LibraryVerificationScreen> createState() => _LibraryVerificationScreenState();
}

class _LibraryVerificationScreenState extends State<LibraryVerificationScreen> {
  final VerificationService _verificationService = VerificationService();
  final PageController _pageController = PageController();
  
  VerificationModel? _verification;
  int _currentStep = 0;
  bool _isLoading = false;

  final List<VerificationStep> _steps = [
    VerificationStep.introduction,
    VerificationStep.location,
    VerificationStep.images,
    VerificationStep.seatAndQr,
    VerificationStep.qrValidation,
    VerificationStep.finalReview,
  ];

  @override
  void initState() {
    super.initState();
    _initializeVerification();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if verification already exists
      VerificationModel? existingVerification = await _verificationService.getVerification(widget.library.id!);
      
      if (existingVerification != null) {
        _verification = existingVerification;
        _currentStep = _steps.indexOf(existingVerification.currentStep);
      } else {
        // Start new verification
        _verification = await _verificationService.startVerification(
          widget.library.id!,
          widget.adminId,
        );
        _currentStep = 0;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing verification: $e')),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = false;
    });

    // Navigate to current step
    if (_currentStep > 0) {
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });

      // Update verification step in database
      await _verificationService.updateVerificationStep(
        _verification!.id!,
        _steps[_currentStep],
      );

      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _previousStep() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });

      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeVerification(bool approved, String reason, String notes) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (approved) {
        await _verificationService.approveLibrary(
          widget.library.id!,
          _verification!.id!,
          notes,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Library approved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        await _verificationService.rejectLibrary(
          widget.library.id!,
          _verification!.id!,
          reason,
          notes,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Library rejected with reason provided.'),
            backgroundColor: AppColors.error,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing verification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _verification == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Loading Verification'),
          backgroundColor: AppColors.primaryBlue,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Verify ${widget.library.libraryName}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            color: AppColors.primaryBlue,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: List.generate(_steps.length, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentStep 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                Gap(12),
                Text(
                  'Step ${_currentStep + 1} of ${_steps.length}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getStepTitle(_steps[_currentStep]),
                  style: AppTextStyles.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Step Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _IntroductionStep(
                  library: widget.library,
                  onNext: _nextStep,
                ),
                LocationVerificationWidget(
                  library: widget.library,
                  verification: _verification!,
                  verificationService: _verificationService,
                  onNext: _nextStep,
                  onPrevious: _previousStep,
                ),
                ImageUploadWidget(
                  library: widget.library,
                  verification: _verification!,
                  verificationService: _verificationService,
                  onNext: _nextStep,
                  onPrevious: _previousStep,
                ),
                SeatVerificationWidget(
                  library: widget.library,
                  verification: _verification!,
                  verificationService: _verificationService,
                  onNext: _nextStep,
                  onPrevious: _previousStep,
                ),
                QrVerificationWidget(
                  library: widget.library,
                  verification: _verification!,
                  verificationService: _verificationService,
                  onNext: _nextStep,
                  onPrevious: _previousStep,
                ),
                _FinalReviewStep(
                  library: widget.library,
                  verification: _verification!,
                  onComplete: _completeVerification,
                  onPrevious: _previousStep,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(VerificationStep step) {
    switch (step) {
      case VerificationStep.introduction:
        return 'Introduction';
      case VerificationStep.location:
        return 'Location Verification';
      case VerificationStep.images:
        return 'Image Upload & Validation';
      case VerificationStep.seatAndQr:
        return 'Seat Verification';
      case VerificationStep.qrValidation:
        return 'QR Code Verification';
      case VerificationStep.finalReview:
        return 'Final Review';
    }
  }
}

class _IntroductionStep extends StatelessWidget {
  final LibraryModel library;
  final VoidCallback onNext;

  const _IntroductionStep({
    required this.library,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user,
            size: 64,
            color: AppColors.primaryBlue,
          ),
          Gap(24),
          Text(
            'Library Verification Process',
            style: AppTextStyles.heading1.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Gap(16),
          Text(
            'Welcome to the verification process for ${library.libraryName}. This step-by-step process will help you verify:',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(24),
          _VerificationChecklistItem(
            icon: Icons.location_on,
            title: 'Location Verification',
            description: 'Verify location is within 50 meters of submitted coordinates',
          ),
          _VerificationChecklistItem(
            icon: Icons.photo_library,
            title: 'Image Validation',
            description: 'Review 3-5 indoor library images for authenticity',
          ),
          _VerificationChecklistItem(
            icon: Icons.event_seat,
            title: 'Seat Arrangement',
            description: 'Validate seat count and arrangement matches submission',
          ),
          _VerificationChecklistItem(
            icon: Icons.qr_code,
            title: 'QR Code Testing',
            description: 'Test QR code check-in and check-out functionality',
          ),
          _VerificationChecklistItem(
            icon: Icons.approval,
            title: 'Final Review',
            description: 'Make final approval or rejection decision',
          ),
          Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start Verification Process',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationChecklistItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _VerificationChecklistItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBlue,
              size: 20,
            ),
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

class _FinalReviewStep extends StatefulWidget {
  final LibraryModel library;
  final VerificationModel verification;
  final Function(bool approved, String reason, String notes) onComplete;
  final VoidCallback onPrevious;

  const _FinalReviewStep({
    required this.library,
    required this.verification,
    required this.onComplete,
    required this.onPrevious,
  });

  @override
  State<_FinalReviewStep> createState() => _FinalReviewStepState();
}

class _FinalReviewStepState extends State<_FinalReviewStep> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _rejectionReasonController = TextEditingController();
  bool _isApproved = true;

  @override
  void dispose() {
    _notesController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Final Review',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Gap(16),
          Text(
            'Review all verification steps and make your decision:',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(24),

          // Verification Summary
          _buildVerificationSummary(),
          
          Gap(24),

          // Decision Section
          Text(
            'Decision',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Gap(12),
          
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isApproved = true),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isApproved ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isApproved ? AppColors.success : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: _isApproved ? AppColors.success : Colors.grey,
                          size: 32,
                        ),
                        Gap(8),
                        Text(
                          'Approve',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: _isApproved ? AppColors.success : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Gap(16),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isApproved = false),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: !_isApproved ? AppColors.error.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isApproved ? AppColors.error : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cancel,
                          color: !_isApproved ? AppColors.error : Colors.grey,
                          size: 32,
                        ),
                        Gap(8),
                        Text(
                          'Reject',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: !_isApproved ? AppColors.error : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          Gap(24),

          // Notes/Reason Field
          if (!_isApproved) ...[
            Text(
              'Rejection Reason *',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(8),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Please provide a detailed reason for rejection...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error),
                ),
              ),
            ),
            Gap(16),
          ],

          Text(
            _isApproved ? 'Admin Notes (Optional)' : 'Additional Notes (Optional)',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Gap(8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add any additional notes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryBlue),
              ),
            ),
          ),

          Spacer(),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrevious,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.primaryBlue),
                  ),
                  child: Text(
                    'Previous',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Gap(16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (!_isApproved && _rejectionReasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please provide a rejection reason')),
                      );
                      return;
                    }

                    widget.onComplete(
                      _isApproved,
                      _rejectionReasonController.text.trim(),
                      _notesController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isApproved ? AppColors.success : AppColors.error,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isApproved ? 'Approve Library' : 'Reject Library',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryItem(
          'Location Verification',
          widget.verification.locationVerification?.isWithinRange == true ? 'Passed' : 'Failed',
          widget.verification.locationVerification?.isWithinRange == true,
        ),
        _buildSummaryItem(
          'Image Validation',
          widget.verification.imageVerification?.isValidCount == true ? 'Passed' : 'Failed',
          widget.verification.imageVerification?.isValidCount == true,
        ),
        _buildSummaryItem(
          'Seat Verification',
          widget.verification.seatVerification?.seatArrangementMatches == true ? 'Passed' : 'Failed',
          widget.verification.seatVerification?.seatArrangementMatches == true,
        ),
        _buildSummaryItem(
          'QR Code Verification',
          widget.verification.qrVerification?.checkInWorks == true && 
          widget.verification.qrVerification?.checkOutWorks == true ? 'Passed' : 'Failed',
          widget.verification.qrVerification?.checkInWorks == true && 
          widget.verification.qrVerification?.checkOutWorks == true,
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String title, String status, bool passed) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: passed ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed ? AppColors.success : AppColors.error,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: passed ? AppColors.success : AppColors.error,
            size: 20,
          ),
          Gap(12),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            status,
            style: AppTextStyles.bodyMedium.copyWith(
              color: passed ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}