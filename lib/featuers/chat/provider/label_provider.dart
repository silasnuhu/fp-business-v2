import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/chat/data/models/label_model.dart';
import 'package:whoxa/featuers/chat/data/repositories/label_repository.dart';
import 'package:whoxa/utils/logger.dart';

/// The business's own chat labels plus the add/edit form state.
///
/// Labels are cached here; resolve a conversation participant's `labelIds`
/// through [getLabelById] and refetch ([loadLabels]) when an id isn't found.
class LabelProvider extends ChangeNotifier {
  final LabelRepository _repository = GetIt.instance<LabelRepository>();
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  List<ChatLabel> _labels = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String _errorMessage = '';

  final TextEditingController labelTextController = TextEditingController();
  String _selectedColor = '#FF5733';
  ChatLabel? _editingLabel;

  List<ChatLabel> get labels => _labels;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String get errorMessage => _errorMessage;
  String get selectedColor => _selectedColor;
  ChatLabel? get editingLabel => _editingLabel;
  bool get isEditing => _editingLabel != null;

  @override
  void dispose() {
    labelTextController.dispose();
    super.dispose();
  }

  String _messageFor(Object e) => e is AppError ? e.message : e.toString();

  Future<void> loadLabels({bool refresh = false}) async {
    if (refresh) _labels = [];
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _labels = await _repository.getLabels();
      _logger.i('Loaded ${_labels.length} labels');
    } catch (e) {
      _errorMessage = 'Failed to load labels: ${_messageFor(e)}';
      _logger.e(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addLabel() async {
    if (!_validateForm()) return false;

    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _repository.addLabel(
        labelText: labelTextController.text.trim(),
        labelColor: _selectedColor,
      );
      clearForm();
      await loadLabels();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add label: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateLabel() async {
    if (_editingLabel == null || !_validateForm()) return false;

    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _repository.updateLabel(
        labelId: _editingLabel!.labelId!,
        labelText: labelTextController.text.trim(),
        labelColor: _selectedColor,
      );
      _editingLabel = _editingLabel!.copyWith(
        labelText: labelTextController.text.trim(),
        labelColor: _selectedColor,
      );
      await loadLabels();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update label: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Deletes the label server-side (which also strips it from every chat).
  /// Callers should refresh the chat list afterwards.
  Future<bool> deleteLabel(int labelId) async {
    try {
      await _repository.deleteLabel(labelId);
      _labels.removeWhere((label) => label.labelId == labelId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete label: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      await loadLabels();
      return false;
    }
  }

  void setEditingLabel(ChatLabel label) {
    _editingLabel = label;
    labelTextController.text = label.labelText ?? '';
    _selectedColor = label.labelColor ?? '#FF5733';
    notifyListeners();
  }

  void clearForm() {
    _editingLabel = null;
    labelTextController.clear();
    _selectedColor = '#FF5733';
    _errorMessage = '';
    notifyListeners();
  }

  void setSelectedColor(String color) {
    _selectedColor = color;
    notifyListeners();
  }

  bool _validateForm() {
    if (labelTextController.text.trim().isEmpty) {
      _errorMessage = 'Label text is required';
      notifyListeners();
      return false;
    }
    if (!RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$').hasMatch(_selectedColor)) {
      _errorMessage = 'Invalid color format';
      notifyListeners();
      return false;
    }
    return true;
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  ChatLabel? getLabelById(int labelId) {
    for (final label in _labels) {
      if (label.labelId == labelId) return label;
    }
    return null;
  }

  /// Applies the difference between [currentLabels] and [newLabels] to a
  /// conversation. A chat can hold at most 3 labels.
  Future<bool> updateChatLabels({
    required int chatId,
    required List<int> currentLabels,
    required List<int> newLabels,
  }) async {
    if (newLabels.length > 3) {
      _errorMessage = 'Maximum 3 labels can be applied to a chat';
      notifyListeners();
      return false;
    }
    if (chatId == -1) {
      _errorMessage = 'Cannot get the Chat ID';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _repository.updateChatLabels(
        conversationId: chatId,
        currentLabels: currentLabels,
        newLabels: newLabels,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update chat labels: ${_messageFor(e)}';
      _logger.e(_errorMessage);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
