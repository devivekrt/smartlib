// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/library_model.dart';
import '../../models/verification_model.dart';
import '../../services/verification_service.dart';
import '../../theme/theme.dart';

class LocationVerificationWidget extends StatefulWidget {
  final LibraryModel library;
  final VerificationModel verification;
  final VerificationService verificationService;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const LocationVerificationWidget({
    super.key,
    required this.library,
    required this.verification,
    required this.verificationService,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<LocationVerificationWidget> createState() => _LocationVerificationWidgetState();
}

class _LocationVerificationWidgetState extends State<LocationVerificationWidget> {
  GoogleMapController? _mapController;
  LocationVerification? _locationVerification;
  bool _isVerifying = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _locationVerification = widget.verification.locationVerification;
    _isVerified = _locationVerification?.isWithinRange ?? false;
  }

  Future<void> _verifyLocation() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      final submittedLat = double.parse(widget.library.locationLatitude ?? '0');
      final submittedLon = double.parse(widget.library.locationLongitude ?? '0');

      final locationVerification = await widget.verificationService.verifyLocation(
        submittedLat,
        submittedLon,
      );

      await widget.verificationService.saveLocationVerification(
        widget.verification.id!,
        locationVerification,
      );

      setState(() {
        _locationVerification = locationVerification;
        _isVerified = locationVerification.isWithinRange;
        _isVerifying = false;
      });

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locationVerification.isWithinRange
                ? 'Location verified successfully!'
                : 'Location verification failed - distance: ${locationVerification.distance?.toStringAsFixed(1)}m',
          ),
          backgroundColor: locationVerification.isWithinRange 
              ? AppColors.success 
              : AppColors.error,
        ),
      );
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying location: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedLat = double.tryParse(widget.library.locationLatitude ?? '0') ?? 0.0;
    final submittedLon = double.tryParse(widget.library.locationLongitude ?? '0') ?? 0.0;

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Verification',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Gap(16),
          Text(
            'Verify that you are within 50 meters of the submitted library location. The map below shows the submitted location.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(24),

          // Library Information
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
                    Icon(Icons.business, color: AppColors.primaryBlue),
                    Gap(8),
                    Expanded(
                      child: Text(
                        widget.library.libraryName ?? 'Unknown Library',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.textSecondary, size: 16),
                    Gap(8),
                    Expanded(
                      child: Text(
                        widget.library.location ?? 'Unknown Location',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(8),
                Row(
                  children: [
                    Icon(Icons.gps_fixed, color: AppColors.textSecondary, size: 16),
                    Gap(8),
                    Text(
                      'Lat: ${submittedLat.toStringAsFixed(6)}, Lon: ${submittedLon.toStringAsFixed(6)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Gap(24),

          // Map
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(submittedLat, submittedLon),
                zoom: 16,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              markers: {
                Marker(
                  markerId: MarkerId('submitted_location'),
                  position: LatLng(submittedLat, submittedLon),
                  infoWindow: InfoWindow(
                    title: widget.library.libraryName,
                    snippet: 'Submitted Location',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                ),
                if (_locationVerification?.verifiedLatitude != null) ...[
                  Marker(
                    markerId: MarkerId('verified_location'),
                    position: LatLng(
                      _locationVerification!.verifiedLatitude!,
                      _locationVerification!.verifiedLongitude!,
                    ),
                    infoWindow: InfoWindow(
                      title: 'Your Location',
                      snippet: 'Verified Location',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      _locationVerification!.isWithinRange 
                          ? BitmapDescriptor.hueGreen 
                          : BitmapDescriptor.hueRed,
                    ),
                  ),
                ],
              },
              circles: {
                Circle(
                  circleId: CircleId('verification_radius'),
                  center: LatLng(submittedLat, submittedLon),
                  radius: 50, // 50 meters
                  fillColor: AppColors.primaryBlue.withOpacity(0.2),
                  strokeColor: AppColors.primaryBlue,
                  strokeWidth: 2,
                ),
              },
            ),
          ),

          Gap(24),

          // Verification Results
          if (_locationVerification != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _locationVerification!.isWithinRange 
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationVerification!.isWithinRange 
                      ? AppColors.success 
                      : AppColors.error,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _locationVerification!.isWithinRange 
                            ? Icons.check_circle 
                            : Icons.error,
                        color: _locationVerification!.isWithinRange 
                            ? AppColors.success 
                            : AppColors.error,
                      ),
                      Gap(8),
                      Text(
                        _locationVerification!.isWithinRange 
                            ? 'Location Verified' 
                            : 'Location Verification Failed',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: _locationVerification!.isWithinRange 
                              ? AppColors.success 
                              : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Gap(12),
                  _buildResultRow('Distance', '${_locationVerification!.distance?.toStringAsFixed(1) ?? 'Unknown'} meters'),
                  _buildResultRow('Within Range', _locationVerification!.isWithinRange ? 'Yes (≤50m)' : 'No (>50m)'),
                  _buildResultRow('GPS Accuracy', '${_locationVerification!.accuracy.toStringAsFixed(1)} meters'),
                  _buildResultRow('Verified At', _formatDateTime(_locationVerification!.verifiedAt)),
                ],
              ),
            ),
            Gap(24),
          ],

          // Verify Button
          if (!_isVerified) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifying
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
                            'Verifying Location...',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Verify My Location',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            Gap(16),
          ],

          Spacer(),

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

  Widget _buildResultRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Unknown',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}