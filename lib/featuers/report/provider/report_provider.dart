import 'package:flutter/material.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/report/data/models/report_types_model.dart';
import 'package:whoxa/featuers/report/data/repositories/report_repository.dart';

class ReportProvider extends ChangeNotifier {
  final ReportRepository _reportRepository;

  ReportProvider(this._reportRepository);

  List<ReportType> _reportTypes = [];
  bool _isLoadingReportTypes = false;
  bool _isSubmittingReport = false;
  // Loading the report types failed (shown in place of the list).
  String _errorMessage = '';
  // Submitting a report failed (shown as a message; the list stays).
  String _submitErrorMessage = '';
  String _successMessage = '';

  List<ReportType> get reportTypes => _reportTypes;
  bool get isLoadingReportTypes => _isLoadingReportTypes;
  bool get isSubmittingReport => _isSubmittingReport;
  String get errorMessage => _errorMessage;
  String get submitErrorMessage => _submitErrorMessage;
  String get successMessage => _successMessage;

  Future<void> fetchReportTypes() async {
    _isLoadingReportTypes = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await _reportRepository.getReportTypes();
      if (response.status) {
        _reportTypes = response.data.reportTypes;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = _messageOf(e);
    } finally {
      _isLoadingReportTypes = false;
      notifyListeners();
    }
  }

  /// Reports a user ([userId]) or a group ([chatId]) — pass exactly one.
  Future<bool> report({
    int? userId,
    int? chatId,
    required int reportTypeId,
  }) async {
    if (_isSubmittingReport) return false;
    _isSubmittingReport = true;
    _submitErrorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final response = await _reportRepository.report(
        userId: userId,
        chatId: chatId,
        reportTypeId: reportTypeId,
      );

      if (response.status) {
        _successMessage = response.message;
        return true;
      }
      _submitErrorMessage = response.message;
      return false;
    } catch (e) {
      _submitErrorMessage = _messageOf(e);
      return false;
    } finally {
      _isSubmittingReport = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = '';
    _submitErrorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  String _messageOf(Object e) => e is AppError ? e.message : e.toString();
}
