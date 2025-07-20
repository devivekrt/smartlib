// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-25 11:14:41
// Current User's Login: devivekrt

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/library_model.dart';
import '../../models/verification_model.dart';
import '../../services/verification_service.dart';
import '../../theme/theme.dart';

class ImageUploadWidget extends StatefulWidget {
  final LibraryModel library;
  final VerificationModel verification;
  final VerificationService verificationService;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const ImageUploadWidget({
    super.key,
    required this.library,
    required this.verification,
    required this.verificationService,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  ImageVerification? _imageVerification;
  bool _isUploading = false;
  bool _isValidated = false;

  final int _minImages = 3;
  final int _maxImages = 5;

  @override
  void initState() {
    super.initState();
    _imageVerification = widget.verification.imageVerification;
    if (_imageVerification != null) {
      _uploadedImageUrls = List.from(_imageVerification!.uploadedImageUrls);
      _isValidated = _imageVerification!.isValidCount;
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      
      if (images.isEmpty) return;

      // Check total count
      if (_selectedImages.length + images.length > _maxImages) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum $_maxImages images allowed'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)));
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      
      if (image == null) return;

      // Check total count
      if (_selectedImages.length >= _maxImages) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum $_maxImages images allowed'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _selectedImages.add(File(image.path));
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking picture: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _selectedImages.length) {
        _selectedImages.removeAt(index);
      } else {
        final urlIndex = index - _selectedImages.length;
        if (urlIndex < _uploadedImageUrls.length) {
          _uploadedImageUrls.removeAt(urlIndex);
        }
      }
      _validateImageCount();
    });
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final urls = await widget.verificationService.uploadVerificationImages(
        widget.library.id!,
        _selectedImages,
      );

      setState(() {
        _uploadedImageUrls.addAll(urls);
        _selectedImages.clear();
        _isUploading = false;
      });

      await _saveImageVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Images uploaded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading images: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveImageVerification() async {
    _validateImageCount();

    final imageVerification = ImageVerification(
      uploadedImageUrls: _uploadedImageUrls,
      requiredMinImages: _minImages,
      requiredMaxImages: _maxImages,
      isValidCount: _isValidated,
      imageValidations: _uploadedImageUrls.map((url) => ImageValidation(
        imageUrl: url,
        isIndoor: true, // Assuming indoor for verification
        showsLibraryInterior: true,
        sizeKb: 100, // Assuming compressed to ~100KB
      )).toList(),
      uploadedAt: DateTime.now(),
    );

    await widget.verificationService.saveImageVerification(
      widget.verification.id!,
      imageVerification,
    );

    setState(() {
      _imageVerification = imageVerification;
    });
  }

  void _validateImageCount() {
    final totalImages = _selectedImages.length + _uploadedImageUrls.length;
    setState(() {
      _isValidated = totalImages >= _minImages && totalImages <= _maxImages;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = _selectedImages.length + _uploadedImageUrls.length;
    
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image Upload & Validation',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Gap(16),
          Text(
            'Upload $_minImages to $_maxImages high-quality indoor images of the library. These images should clearly show the library interior, seating arrangements, and facilities.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(24),

          // Requirements
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
                      'Image Requirements',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Gap(12),
                _buildRequirementItem('Minimum $_minImages images, maximum $_maxImages images'),
                _buildRequirementItem('Indoor library photos only'),
                _buildRequirementItem('Clear view of seating arrangements'),
                _buildRequirementItem('Show library facilities and amenities'),
                _buildRequirementItem('Good lighting and image quality'),
                _buildRequirementItem('Images will be compressed to under 100KB'),
              ],
            ),
          ),

          Gap(24),

          // Image Count Status
          Row(
            children: [
              Text(
                'Images: $totalImages/$_maxImages',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: _isValidated ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              if (_isValidated) ...[
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                Gap(4),
                Text(
                  'Valid Count',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Icon(Icons.warning, color: AppColors.warning, size: 20),
                Gap(4),
                Text(
                  totalImages < _minImages ? 'Need ${_minImages - totalImages} more' : 'Too many images',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),

          Gap(16),

          // Image Grid
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Upload buttons
                  if (totalImages < _maxImages) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImages,
                            icon: Icon(Icons.photo_library),
                            label: Text('Pick from Gallery'),
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
                          child: OutlinedButton.icon(
                            onPressed: _takePicture,
                            icon: Icon(Icons.camera_alt),
                            label: Text('Take Picture'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: AppColors.primaryBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap(24),
                  ],

                  // Image grid
                  if (totalImages > 0) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: totalImages,
                      itemBuilder: (context, index) {
                        if (index < _selectedImages.length) {
                          // Selected images (not uploaded yet)
                          return _buildImageCard(
                            imageFile: _selectedImages[index],
                            index: index,
                            isUploaded: false,
                          );
                        } else {
                          // Uploaded images
                          final urlIndex = index - _selectedImages.length;
                          return _buildImageCard(
                            imageUrl: _uploadedImageUrls[urlIndex],
                            index: index,
                            isUploaded: true,
                          );
                        }
                      },
                    ),
                    Gap(24),
                  ],

                  // Upload button for selected images
                  if (_selectedImages.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadImages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isUploading
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
                                    'Uploading ${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''}...',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Upload ${_selectedImages.length} Image${_selectedImages.length > 1 ? 's' : ''}',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    Gap(24),
                  ],
                ],
              ),
            ),
          ),

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
                  onPressed: _isValidated && _selectedImages.isEmpty ? widget.onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValidated && _selectedImages.isEmpty 
                        ? AppColors.success 
                        : AppColors.textSecondary,
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

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, color: AppColors.primaryBlue, size: 16),
          Gap(8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard({
    File? imageFile,
    String? imageUrl,
    required int index,
    required bool isUploaded,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Image
          SizedBox.expand(
            child: imageFile != null
                ? Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                  )
                : imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.error, color: AppColors.error),
                          );
                        },
                      )
                    : Container(color: AppColors.inputBackground),
          ),

          // Overlay with status
          if (isUploaded) ...[
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done, color: Colors.white, size: 12),
                    Gap(4),
                    Text(
                      'Uploaded',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Pending',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          // Remove button
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: () => _removeImage(index),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),

          // Image number
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontSize: 10,
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