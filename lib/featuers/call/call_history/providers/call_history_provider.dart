import 'package:flutter/material.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/call/call_history/models/call_history_model.dart';
import 'package:whoxa/featuers/call/call_history/repositories/call_history_repository.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';

class CallHistoryProvider with ChangeNotifier {
  final CallHistoryRepository _callHistoryRepository;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  CallHistoryProvider(this._callHistoryRepository);

  List<CallRecord> _callHistory = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  PaginationInfo? _paginationInfo;
  int _currentPage = 1;

  List<CallRecord> get callHistory => _callHistory;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  PaginationInfo? get paginationInfo => _paginationInfo;
  int get currentPage => _currentPage;

  // Check if there are more pages to load
  bool get hasMoreData =>
      _paginationInfo != null && _currentPage < _paginationInfo!.totalPages;

  // Helper method to get grouped call history by date
  Map<String, List<CallRecord>> get groupedCallHistory {
    Map<String, List<CallRecord>> grouped = {};

    for (var call in _callHistory) {
      DateTime callDate = DateTime.parse(call.createdAt);
      DateTime now = DateTime.now();
      String dateKey;

      if (callDate.year == now.year &&
          callDate.month == now.month &&
          callDate.day == now.day) {
        dateKey = 'Today';
      } else if (callDate.year == now.year &&
          callDate.month == now.month &&
          callDate.day == now.day - 1) {
        dateKey = 'Yesterday';
      } else {
        dateKey = '${callDate.day}/${callDate.month}/${callDate.year}';
      }

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(call);
    }

    return grouped;
  }

  bool isInternetIssue = false;
  Future<void> fetchCallHistory({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _callHistory.clear();
    }

    _setLoading(true);
    _setError(null);
    isInternetIssue = false;
    notifyListeners();

    try {
      _logger.i('Fetching call history for user: $userID, page: $_currentPage');
      final response = await _callHistoryRepository.getCallHistory(
        page: _currentPage,
      );

      if (response.status) {
        if (refresh) {
          _callHistory = response.data.records;
        } else {
          _callHistory.addAll(response.data.records);
        }
        _paginationInfo = response.data.pagination;
        _logger.i(
          'Successfully fetched ${response.data.records.length} call history items for page $_currentPage',
        );
        _logger.i(
          'Total records: ${_paginationInfo?.totalRecords}, Total pages: ${_paginationInfo?.totalPages}',
        );
      } else {
        _setError(response.message);
        _logger.e('Failed to fetch call history: ${response.message}');
      }
    } on AppError catch (e) {
      final data = extractErrorData(e);
      _setError(data?['message'] ?? 'Unknown error');
      isInternetIssue = e.isNetworkError;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load call history');
      _logger.e('Error fetching call history: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreCallHistory() async {
    if (_isLoadingMore || !hasMoreData) return;

    _setLoadingMore(true);
    _setError(null);
    isInternetIssue = false;
    notifyListeners();

    try {
      _currentPage++;
      _logger.i(
        'Loading more call history for user: $userID, page: $_currentPage',
      );
      final response = await _callHistoryRepository.getCallHistory(
        page: _currentPage,
      );

      if (response.status) {
        _callHistory.addAll(response.data.records);
        _paginationInfo = response.data.pagination;
        _logger.i(
          'Successfully loaded ${response.data.records.length} more call history items for page $_currentPage',
        );
      } else {
        _currentPage--; // Revert page increment on failure
        _setError(response.message);
        _logger.e('Failed to load more call history: ${response.message}');
      }
    } on AppError catch (e) {
      _currentPage--;
      final data = extractErrorData(e);
      _setError(data?['message'] ?? 'Unknown error');
      isInternetIssue = e.isNetworkError;
      notifyListeners();
    } catch (e) {
      _currentPage--; // Revert page increment on failure
      _setError('Failed to load more call history');
      _logger.e('Error loading more call history: $e');
    } finally {
      _setLoadingMore(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingMore(bool loading) {
    _isLoadingMore = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper method to get call history by type
  List<CallRecord> getCallHistoryByType(String type) {
    return _callHistory
        .where((call) => call.getCallDirection(userID.toString()) == type)
        .toList();
  }

  // Get missed calls count
  int get missedCallsCount {
    return _callHistory
        .where((call) => call.getCallDirection(userID.toString()) == 'missed')
        .length;
  }

  // Get total calls count
  int get totalCallsCount => _callHistory.length;

  // Get video calls count
  int get videoCallsCount {
    return _callHistory.where((call) => call.getCallType() == 'video').length;
  }

  // Get audio calls count
  int get audioCallsCount {
    return _callHistory.where((call) => call.getCallType() == 'audio').length;
  }
}
