import 'package:flutter/material.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/profile/data/repository/profile_status_repo.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class ProfileProvider extends ChangeNotifier {
  TextEditingController statuscontroller = TextEditingController();
  bool isSelectedmessage = false;
  String selectedabouttext = "";
  String statusText = '';

  ProfileProvider(this.statusRepo) {
    selectedabouttext = bioList.first.name;
    statusText = bioList.first.name;
  }

  final ProfileStatusRepository statusRepo;

  void noty() {
    notifyListeners();
  }

  bool _isLoading = false;
  bool _isGetLoad = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isGetLoad => _isGetLoad;
  String? get errorMessage => _errorMessage;

  int? _loadingIndex;
  int? get loadingIndex => _loadingIndex;

  void setLoadingIndex(int? index) {
    _loadingIndex = index;
    notifyListeners();
  }

  bool isInternetIssue = false;
  bool hasLoadedOnce = false;

  Future<bool> statusGetApi({required bool isGetData}) async {
    if (!hasLoadedOnce) {
      isGetData ? _isGetLoad = true : _isLoading = true;
      noty();
    }
    _errorMessage = null;
    isInternetIssue = false;
    hasLoadedOnce = false;
    noty();

    try {
      final result = await statusRepo.profileStatusRepo(
        isGetData: isGetData,
        status: statusText,
      );

      if (result.status == true) {
        SecurePrefs.setString(
          SecureStorageKeys.STATUSBIO,
          result.data!.bio.toString(),
        );

        bio = await SecurePrefs.getString(SecureStorageKeys.STATUSBIO) ?? "";
        statusText = bio.isEmpty ? "" : bio;
        selectedabouttext = bio.isEmpty ? "" : bio;

        hasLoadedOnce = true;
        _isGetLoad = false;
        _isLoading = false;
        noty();
        return true;
      } else {
        _isGetLoad = false;
        _isLoading = false;

        noty();
        return false;
      }
    } on AppError catch (e) {
      _isGetLoad = false;
      _isLoading = false;
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      isInternetIssue = e.isNetworkError;
      noty();
      return false;
    } catch (e) {
      _errorMessage = 'Unexpected error occurred';
      isInternetIssue = false;
      noty();
      return false;
    }
  }

  // Get peer user profile
  Future<UserNameCheckModel?> getPeerUserProfile(int userId) async {
    try {
      final result = await statusRepo.getPeerUserProfileRepo(userId);

      // Additional validation to ensure we have valid data
      if (result.data?.records?.isEmpty ?? true) {
        debugPrint('Empty records received for user_id: $userId');
        return null;
      }

      return result;
    } catch (e) {
      debugPrint('Error getting peer user profile: $e');
      return null;
    }
  }

  void selectStatus(Module module) {
    selectedabouttext = module.name;
    statusText = module.name;
    notifyListeners();
  }

  List<Module> bioList = [
    Module(AppString.settingStrigs.available),
    Module(AppString.settingStrigs.atWork),
    Module(AppString.settingStrigs.atOffice),
    Module(AppString.settingStrigs.batteryAboutToDie),
    Module(AppString.settingStrigs.intAMetting),
    Module(AppString.settingStrigs.atTheGym),
    Module(AppString.settingStrigs.sleepin),
  ];
}

class Module {
  final String name;

  Module(this.name);
}
