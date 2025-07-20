// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../models/library_model.dart';
import '../../models/verification_model.dart';
import '../../services/verification_service.dart';
import '../../theme/theme.dart';

class SeatVerificationWidget extends StatefulWidget {
  final LibraryModel library;
  final VerificationModel verification;
  final VerificationService verificationService;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const SeatVerificationWidget({
    super.key,
    required this.library,
    required this.verification,
    required this.verificationService,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<SeatVerificationWidget> createState() => _SeatVerificationWidgetState();
}

class _SeatVerificationWidgetState extends State<SeatVerificationWidget> {
  final TextEditingController _verifiedSeatsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _seatNumberController = TextEditingController();
  
  SeatVerification? _seatVerification;
  List<String> _seatNumbers = [];
  bool _isVerified = false;
  bool _seatArrangementMatches = false;

  @override
  void initState() {
    super.initState();
    _seatVerification = widget.verification.seatVerification;
    
    if (_seatVerification != null) {
      _verifiedSeatsController.text = _seatVerification!.verifiedTotalSeats.toString();
      _notesController.text = _seatVerification!.seatArrangementNotes ?? '';
      _seatNumbers = List.from(_seatVerification!.seatNumbers);
      _seatArrangementMatches = _seatVerification!.seatArrangementMatches;
      _isVerified = true;
    } else {
      _verifiedSeatsController.text = widget.library.totalSeats?.toString() ?? '0';
    }
    
    _generateDefaultSeatNumbers();
  }

  @override
  void dispose() {
    _verifiedSeatsController.dispose();
    _notesController.dispose();
    _seatNumberController.dispose();
    super.dispose();
  }

  void _generateDefaultSeatNumbers() {
    if (_seatNumbers.isEmpty) {
      final totalSeats = int.tryParse(_verifiedSeatsController.text) ?? 0;
      _seatNumbers = List.generate(totalSeats, (index) => 'S${(index + 1).toString().padLeft(3, '0')}');
    }
  }

  void _addSeatNumber() {
    final seatNumber = _seatNumberController.text.trim();
    if (seatNumber.isNotEmpty && !_seatNumbers.contains(seatNumber)) {
      setState(() {
        _seatNumbers.add(seatNumber);
        _seatNumberController.clear();
      });
    }
  }

  void _removeSeatNumber(int index) {
    setState(() {
      _seatNumbers.removeAt(index);
    });
  }

  void _regenerateSeatNumbers() {
    final totalSeats = int.tryParse(_verifiedSeatsController.text) ?? 0;
    setState(() {
      _seatNumbers = List.generate(totalSeats, (index) => 'S${(index + 1).toString().padLeft(3, '0')}');
    });
  }

  Future<void> _saveSeatVerification() async {
    final submittedSeats = widget.library.totalSeats ?? 0;
    final verifiedSeats = int.tryParse(_verifiedSeatsController.text) ?? 0;
    
    final seatVerification = SeatVerification(
      submittedTotalSeats: submittedSeats,
      verifiedTotalSeats: verifiedSeats,
      seatNumbers: _seatNumbers,
      seatArrangementMatches: _seatArrangementMatches,
      seatArrangementNotes: _notesController.text.trim(),
      verifiedAt: DateTime.now(),
    );

    try {
      await widget.verificationService.saveSeatVerification(
        widget.verification.id!,
        seatVerification,
      );

      setState(() {
        _seatVerification = seatVerification;
        _isVerified = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seat verification saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving seat verification: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedSeats = widget.library.totalSeats ?? 0;
    final verifiedSeats = int.tryParse(_verifiedSeatsController.text) ?? 0;
    final seatCountMatches = submittedSeats == verifiedSeats;

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seat Verification',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Gap(16),
          Text(
            'Verify the seat count and arrangement matches the submitted data. You can also manage individual seat numbers for QR code generation.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seat Count Comparison
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seat Count Comparison',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Gap(12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                title: 'Submitted Count',
                                value: submittedSeats.toString(),
                                icon: Icons.upload,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verified Count',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Gap(8),
                                  TextField(
                                    controller: _verifiedSeatsController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: InputDecoration(
                                      hintText: 'Enter verified count',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: AppColors.primaryBlue),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Gap(12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: seatCountMatches ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: seatCountMatches ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                seatCountMatches ? Icons.check_circle : Icons.warning,
                                color: seatCountMatches ? AppColors.success : AppColors.warning,
                                size: 20,
                              ),
                              Gap(8),
                              Expanded(
                                child: Text(
                                  seatCountMatches 
                                      ? 'Seat count matches submission'
                                      : 'Seat count differs from submission (${submittedSeats} vs $verifiedSeats)',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: seatCountMatches ? AppColors.success : AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Gap(24),

                  // Seat Arrangement Verification
                  Text(
                    'Seat Arrangement Verification',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Gap(12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _seatArrangementMatches,
                          onChanged: (value) {
                            setState(() {
                              _seatArrangementMatches = value ?? false;
                            });
                          },
                          title: Text(
                            'Seat arrangement matches submitted layout',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primaryBlue,
                        ),
                        Gap(12),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Arrangement Notes (Optional)',
                            hintText: 'Describe the seat arrangement, any discrepancies, or additional observations...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.primaryBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Gap(24),

                  // Seat Numbers Management
                  Text(
                    'Seat Numbers Management',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Gap(8),
                  Text(
                    'Manage individual seat numbers for QR code generation. You can add custom seat numbers or regenerate them automatically.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Gap(16),

                  // Add seat number
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _seatNumberController,
                          decoration: InputDecoration(
                            labelText: 'Seat Number',
                            hintText: 'e.g., S001, A1, etc.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.primaryBlue),
                            ),
                          ),
                          onSubmitted: (_) => _addSeatNumber(),
                        ),
                      ),
                      Gap(12),
                      ElevatedButton.icon(
                        onPressed: _addSeatNumber,
                        icon: Icon(Icons.add),
                        label: Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),

                  Gap(16),

                  // Regenerate button
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _regenerateSeatNumbers,
                        icon: Icon(Icons.refresh),
                        label: Text('Regenerate All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${_seatNumbers.length} seat numbers',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  Gap(16),

                  // Seat numbers grid
                  if (_seatNumbers.isNotEmpty) ...[
                    Container(
                      height: 150,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: _seatNumbers.length,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    _seatNumbers[index],
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    onTap: () => _removeSeatNumber(index),
                                    child: Icon(
                                      Icons.close,
                                      size: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  Gap(24),

                  // Save verification button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSeatVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isVerified ? 'Update Seat Verification' : 'Save Seat Verification',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Gap(24),

          // Navigation Buttons
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
                  onPressed: _isVerified ? widget.onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isVerified ? AppColors.success : AppColors.textSecondary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Next Step',
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

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              Gap(4),
              Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Gap(8),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}