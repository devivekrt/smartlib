// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/library_model.dart';
import '../../models/verification_model.dart';
import '../../services/verification_service.dart';
import '../../theme/theme.dart';

class QrVerificationWidget extends StatefulWidget {
  final LibraryModel library;
  final VerificationModel verification;
  final VerificationService verificationService;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const QrVerificationWidget({
    super.key,
    required this.library,
    required this.verification,
    required this.verificationService,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<QrVerificationWidget> createState() => _QrVerificationWidgetState();
}

class _QrVerificationWidgetState extends State<QrVerificationWidget> {
  final TextEditingController _qrCodeController = TextEditingController();
  MobileScannerController? _scannerController;
  
  QrVerification? _qrVerification;
  bool _isScanning = false;
  bool _isTesting = false;
  bool _isVerified = false;
  String? _scannedCode;

  @override
  void initState() {
    super.initState();
    _qrVerification = widget.verification.qrVerification;
    
    if (_qrVerification != null) {
      _qrCodeController.text = _qrVerification!.qrCodeData ?? '';
      _scannedCode = _qrVerification!.qrCodeData;
      _isVerified = _qrVerification!.checkInWorks && _qrVerification!.checkOutWorks;
    }
  }

  @override
  void dispose() {
    _qrCodeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _scannerController = MobileScannerController();
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    _scannerController?.dispose();
    _scannerController = null;
  }

  void _onQrCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _scannedCode = barcode.rawValue!;
          _qrCodeController.text = _scannedCode!;
        });
        _stopScanning();
        break;
      }
    }
  }

  void _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        setState(() {
          _scannedCode = clipboardData!.text!;
          _qrCodeController.text = _scannedCode!;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing clipboard: $e')),
      );
    }
  }

  Future<void> _testQrCode() async {
    if (_scannedCode == null || _scannedCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please scan or enter a QR code first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
    });

    try {
      final qrVerification = await widget.verificationService.testQrCode(
        _scannedCode!,
        widget.library.id!,
      );

      await widget.verificationService.saveQrVerification(
        widget.verification.id!,
        qrVerification,
      );

      setState(() {
        _qrVerification = qrVerification;
        _isVerified = qrVerification.checkInWorks && qrVerification.checkOutWorks;
        _isTesting = false;
      });

      final success = qrVerification.checkInWorks && qrVerification.checkOutWorks;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'QR code verification successful!'
                : 'QR code verification failed',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      setState(() {
        _isTesting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing QR code: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR Code Verification',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Gap(16),
          Text(
            'Scan or enter the library\'s QR code and test the check-in/check-out functionality to ensure it works properly.',
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
                  // QR Code Input Section
                  if (!_isScanning) ...[
                    Text(
                      'QR Code Input',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Gap(12),
                    
                    // QR Code Input Field
                    TextField(
                      controller: _qrCodeController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'QR Code Data',
                        hintText: 'Scan QR code or paste the code here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryBlue),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.content_paste, color: AppColors.primaryBlue),
                          onPressed: _pasteFromClipboard,
                          tooltip: 'Paste from clipboard',
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _scannedCode = value;
                        });
                      },
                    ),

                    Gap(16),

                    // QR Code Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _startScanning,
                            icon: Icon(Icons.qr_code_scanner),
                            label: Text('Scan QR Code'),
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
                            onPressed: _scannedCode != null && _scannedCode!.isNotEmpty && !_isTesting
                                ? _testQrCode
                                : null,
                            icon: _isTesting 
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.play_arrow),
                            label: Text(_isTesting ? 'Testing...' : 'Test QR Code'),
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

                  // QR Scanner Section
                  if (_isScanning) ...[
                    Text(
                      'QR Code Scanner',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Gap(12),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: _onQrCodeDetected,
                      ),
                    ),
                    Gap(16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _stopScanning,
                            icon: Icon(Icons.close),
                            label: Text('Cancel Scan'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  Gap(24),

                  // QR Code Information
                  if (_scannedCode != null && _scannedCode!.isNotEmpty) ...[
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
                          Row(
                            children: [
                              Icon(Icons.qr_code, color: AppColors.primaryBlue),
                              Gap(8),
                              Text(
                                'Scanned QR Code',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Gap(12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _scannedCode!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Gap(12),
                          Text(
                            'Code Length: ${_scannedCode!.length} characters',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(24),
                  ],

                  // Test Results
                  if (_qrVerification != null) ...[
                    Text(
                      'Verification Results',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Gap(12),
                    
                    // Overall Status
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isVerified 
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isVerified ? AppColors.success : AppColors.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isVerified ? Icons.check_circle : Icons.error,
                            color: _isVerified ? AppColors.success : AppColors.error,
                            size: 32,
                          ),
                          Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isVerified ? 'QR Code Verification Passed' : 'QR Code Verification Failed',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: _isVerified ? AppColors.success : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Gap(4),
                                Text(
                                  _isVerified 
                                      ? 'Check-in and check-out functionality works correctly'
                                      : 'One or more tests failed. Review details below.',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: _isVerified ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Gap(16),

                    // Individual Test Results
                    _buildTestResult(
                      'QR Code Validity',
                      _qrVerification!.isValidQrCode,
                      _qrVerification!.isValidQrCode 
                          ? 'QR code format is valid and contains library ID'
                          : 'QR code format is invalid or missing library ID',
                    ),
                    
                    _buildTestResult(
                      'Check-in Functionality',
                      _qrVerification!.checkInWorks,
                      _qrVerification!.checkInWorks 
                          ? 'Check-in process works correctly'
                          : 'Check-in process failed',
                    ),
                    
                    _buildTestResult(
                      'Check-out Functionality',
                      _qrVerification!.checkOutWorks,
                      _qrVerification!.checkOutWorks 
                          ? 'Check-out process works correctly'
                          : 'Check-out process failed',
                    ),

                    Gap(16),

                    // Detailed Test Results
                    if (_qrVerification!.testResults.isNotEmpty) ...[
                      ExpansionTile(
                        title: Text(
                          'Detailed Test Results',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: _qrVerification!.testResults.map((result) {
                          return ListTile(
                            leading: Icon(
                              result.success ? Icons.check_circle : Icons.error,
                              color: result.success ? AppColors.success : AppColors.error,
                            ),
                            title: Text(
                              result.action.replaceAll('_', ' ').toUpperCase(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: result.errorMessage != null
                                ? Text(
                                    result.errorMessage!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.error,
                                    ),
                                  )
                                : null,
                            trailing: Text(
                              _formatDateTime(result.testedAt),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
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

  Widget _buildTestResult(String title, bool passed, String description) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gap(4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            passed ? 'PASS' : 'FAIL',
            style: AppTextStyles.bodySmall.copyWith(
              color: passed ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}