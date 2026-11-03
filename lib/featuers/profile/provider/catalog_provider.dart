import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/core/services/media/business_image_uploader.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/business/data/repositories/business_repository.dart';
import 'package:whoxa/featuers/profile/data/models/catalog_response_model.dart';
import 'package:whoxa/featuers/profile/data/repositories/catalog_repository.dart';
import 'package:whoxa/utils/logger.dart';

/// State for the business's own product catalog and its add/edit form.
class CatalogProvider extends ChangeNotifier {
  final CatalogRepository _repository = GetIt.instance<CatalogRepository>();
  final BusinessRepository _businessRepository =
      GetIt.instance<BusinessRepository>();
  final BusinessImageUploader _uploader = GetIt.instance<BusinessImageUploader>();
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  List<Catalog> _catalogs = [];
  List<CatalogCategory> _categories = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String _errorMessage = '';

  // Form controllers for add/edit catalog
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController countryController = TextEditingController();

  final List<File> _selectedImages = [];
  Catalog? _editingCatalog;
  int? _selectedCategoryId;

  List<Catalog> get catalogs => _catalogs;
  List<CatalogCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String get errorMessage => _errorMessage;
  List<File> get selectedImages => _selectedImages;
  Catalog? get editingCatalog => _editingCatalog;
  bool get isEditing => _editingCatalog != null;
  int? get selectedCategoryId => _selectedCategoryId;

  // `GET /catalog` returns the full list in one go — there is no pagination,
  // so the "load more" affordances the list screen used to have are inert.
  bool get isLoadingMore => false;
  bool get hasMoreData => false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    countryController.dispose();
    super.dispose();
  }

  String _messageFor(Object e) => e is AppError ? e.message : e.toString();

  /// Loads the caller's own products. (`GET /catalog` is owner-scoped — it
  /// cannot list another user's catalog.)
  Future<void> loadCatalogs({bool refresh = false}) async {
    if (refresh) _catalogs = [];
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _catalogs = await _repository.getCatalogs();
      _logger.i('Loaded ${_catalogs.length} catalogs');
    } catch (e) {
      _errorMessage = 'Failed to load catalogs: ${_messageFor(e)}';
      _logger.e(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      _categories = await _businessRepository.getCategories();
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to load categories: $e');
    }
  }

  void setSelectedCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  /// Price is stored as a whole number by the API (no decimals, no currency).
  int _parsedPrice() =>
      (double.tryParse(priceController.text.trim()) ?? 0).round();

  Future<bool> addCatalog() async {
    if (!_validateForm()) {
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final imageUrls = await _uploader.uploadAll(_selectedImages);
      await _repository.createCatalog(
        title: titleController.text.trim(),
        price: _parsedPrice(),
        description: descriptionController.text.trim(),
        countryOfOrigin: countryController.text.trim(),
        categoryId: _selectedCategoryId,
        images: imageUrls,
      );
      clearForm();
      await loadCatalogs(refresh: true);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add catalog: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateCatalog() async {
    if (_editingCatalog == null) return false;
    if (!_validateForm()) {
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Newly picked photos are appended to the existing set (the API
      // replaces the whole set, so the existing URLs must be re-sent).
      List<String>? images;
      if (_selectedImages.isNotEmpty) {
        images = [..._existingImageUrls(_editingCatalog!)];
        images.addAll(await _uploader.uploadAll(_selectedImages));
      }

      await _repository.updateCatalog(
        _editingCatalog!.catalogId!,
        title: titleController.text.trim(),
        price: _parsedPrice(),
        description: descriptionController.text.trim(),
        countryOfOrigin: countryController.text.trim(),
        categoryId: _selectedCategoryId,
        images: images,
      );
      _selectedImages.clear();
      await loadCatalogs(refresh: true);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update catalog: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  List<String> _existingImageUrls(Catalog catalog) =>
      (catalog.catalogImages ?? [])
          .map((i) => i.image ?? '')
          .where((url) => url.isNotEmpty)
          .toList();

  Catalog? _byId(int catalogId) {
    for (final c in _catalogs) {
      if (c.catalogId == catalogId) return c;
    }
    return null;
  }

  /// Appends [images] to a product's photos. `PATCH` replaces the whole image
  /// set, so the current URLs are sent back along with the new ones.
  Future<bool> addCatalogImages(int catalogId, List<File> images) async {
    final catalog = _byId(catalogId);
    if (catalog == null) return false;
    try {
      final uploaded = await _uploader.uploadAll(images);
      await _repository.updateCatalog(
        catalogId,
        images: [..._existingImageUrls(catalog), ...uploaded],
      );
      await loadCatalogs(refresh: true);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add images: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Removes one photo by re-sending the set without it.
  Future<bool> deleteCatalogImage(int catalogId, int catalogImageId) async {
    final catalog = _byId(catalogId);
    if (catalog == null) return false;
    try {
      final remaining =
          (catalog.catalogImages ?? [])
              .where((i) => i.catalogImageId != catalogImageId)
              .map((i) => i.image ?? '')
              .where((url) => url.isNotEmpty)
              .toList();
      await _repository.updateCatalog(catalogId, images: remaining);
      await loadCatalogs(refresh: true);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete image: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCatalog(int catalogId) async {
    try {
      await _repository.deleteCatalog(catalogId);
      await loadCatalogs(refresh: true);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete catalog: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  void setEditingCatalog(Catalog catalog) {
    _editingCatalog = catalog;
    titleController.text = catalog.title ?? '';
    descriptionController.text = catalog.description ?? '';
    priceController.text = catalog.price?.round().toString() ?? '';
    countryController.text = catalog.countryOfOrigin ?? '';
    _selectedCategoryId =
        (catalog.categoryId ?? 0) > 0 ? catalog.categoryId : null;
    _selectedImages.clear();
    notifyListeners();
  }

  void clearForm() {
    _editingCatalog = null;
    titleController.clear();
    descriptionController.clear();
    priceController.clear();
    countryController.clear();
    _selectedCategoryId = null;
    _selectedImages.clear();
    _errorMessage = '';
    notifyListeners();
  }

  void addImage(File image) {
    // API allows at most 20 images per product.
    if (_selectedImages.length >= 20) return;
    _selectedImages.add(image);
    notifyListeners();
  }

  void removeImage(int index) {
    if (index < _selectedImages.length) {
      _selectedImages.removeAt(index);
      notifyListeners();
    }
  }

  void clearImages() {
    _selectedImages.clear();
    notifyListeners();
  }

  bool _validateForm() {
    if (titleController.text.trim().isEmpty) {
      _errorMessage = 'Title is required';
      return false;
    }
    if (priceController.text.trim().isNotEmpty &&
        double.tryParse(priceController.text.trim()) == null) {
      _errorMessage = 'Invalid price format';
      return false;
    }
    return true;
  }

  /// Fire-and-forget view count for a product someone opened.
  Future<void> trackCatalogView(int catalogId) async {
    try {
      await _repository.trackView(catalogId);
    } catch (e) {
      _logger.e('Could not track catalog view $catalogId: $e');
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}
