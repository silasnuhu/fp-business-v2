import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:whoxa/featuers/profile/provider/catalog_provider.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class ManageImagesDialog extends StatefulWidget {
  final Catalog catalog;

  const ManageImagesDialog({
    super.key,
    required this.catalog,
  });

  @override
  State<ManageImagesDialog> createState() => _ManageImagesDialogState();
}

class _ManageImagesDialogState extends State<ManageImagesDialog> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _newImages = [];
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppThemeManage.appTheme.scaffoldBackColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.appPriSecColor.primaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage Images - ${widget.catalog.title}',
                      style: AppTypography.h5(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Images Section
                    _buildCurrentImagesSection(),

                    SizedBox(height: 24),

                    // Add New Images Section
                    _buildAddImagesSection(),

                    // Upload Button
                    if (_newImages.isNotEmpty) ...[
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _uploadNewImages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.appPriSecColor.primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isUploading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Upload ${_newImages.length} New Image${_newImages.length > 1 ? "s" : ""}',
                                  style: AppTypography.innerText14(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentImagesSection() {
    final images = widget.catalog.catalogImages ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Images',
          style: AppTypography.innerText16(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeManage.appTheme.textColor,
          ),
        ),
        SizedBox(height: 12),

        if (images.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.image_not_supported,
                  color: Colors.grey[600],
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  'No images yet',
                  style: AppTypography.innerText14(context).copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return _buildImageTile(image);
            },
          ),
      ],
    );
  }

  Widget _buildImageTile(CatalogImage image) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: image.image ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.appPriSecColor.primaryColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey[600],
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _deleteImage(image),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add New Images',
          style: AppTypography.innerText16(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeManage.appTheme.textColor,
          ),
        ),
        SizedBox(height: 12),

        // Add Image Button
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  color: AppColors.appPriSecColor.primaryColor,
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to select images',
                  style: AppTypography.innerText12Ragu(context).copyWith(
                    color: AppColors.appPriSecColor.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Selected New Images
        if (_newImages.isNotEmpty) ...[
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _newImages.length,
            itemBuilder: (context, index) {
              final image = _newImages[index];
              return _buildNewImageTile(image, index);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildNewImageTile(File image, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.5),
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeNewImage(index),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();

      setState(() {
        for (final pickedFile in pickedFiles) {
          _newImages.add(File(pickedFile.path));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _uploadNewImages() async {
    if (_newImages.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final provider = Provider.of<CatalogProvider>(context, listen: false);
      final success = await provider.addCatalogImages(
        widget.catalog.catalogId!,
        _newImages,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _newImages.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Images uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Close dialog and refresh the main screen
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload images'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteImage(CatalogImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Image'),
          content: Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<CatalogProvider>(context, listen: false);
      final success = await provider.deleteCatalogImage(
        widget.catalog.catalogId!,
        image.catalogImageId!,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Close dialog and refresh the main screen
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}