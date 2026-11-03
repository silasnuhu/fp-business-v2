import 'dart:io';

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/data/models/login_model.dart';
import 'package:whoxa/featuers/auth/data/models/otp_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_delete_model.dart';
import 'package:whoxa/featuers/auth/data/models/logout_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_profile_model.dart';
import 'package:whoxa/featuers/auth/data/models/avatar_model.dart';
import 'package:whoxa/utils/logger.dart';

class LoginRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  LoginRepository(this._apiClient);

  //=============================================================================================================================
  //===================================================== Login email/mobile method =============================================
  //=============================================================================================================================
  LoginModel loginModel = LoginModel();
  Future<LoginModel> emailLoginRepository(String email) async {
    String device = Platform.isIOS ? 'ios' : 'android';
    _logger.i('Adding new email: $email');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.registerEmail,
        method: 'POST',
        body: {
          'email_id': email,
          'login_type': 'email',
          'platform': device,
          // This build is the Business app: the server rejects a
          // business account if the client claims to be the user app.
          'user_type': 'business',
        },
      );
      _logger.i('Email added successfully');
      return loginModel = LoginModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding email:', e.toString());
      rethrow;
    }
  }

  Future<LoginModel> mobileLoginRepository(
    String countryCode,
    String phoneNumber,
    String countryFullName,
    String selectedCountrySortName,
  ) async {
    String device = Platform.isIOS ? 'ios' : 'android';
    _logger.i('Adding new mobile: $phoneNumber');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.registerPhone,
        method: 'POST',
        body: {
          'login_type': 'phone',
          'country': countryFullName,
          'country_code': countryCode,
          'mobile_num': phoneNumber,
          'country_short_name': selectedCountrySortName,
          'platform': device,
          'user_type': 'business',
        },
      );
      _logger.i('Mobile added successfully');
      return loginModel = LoginModel.fromJson(response);
    } catch (e) {
      _logger.e('Mobile_Login_Error adding mobile:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== OTP email/mobile method ===============================================
  //=============================================================================================================================
  VerifyOTPModel otpModel = VerifyOTPModel();

  Future<VerifyOTPModel> otpRepository({
    required bool isEmail,
    required String countryCode,
    required String phoneNumber,
    required String email,
    required String otp,
    required String fcmToken,
    String? country,
  }) async {
    String device = Platform.isIOS ? 'ios' : 'android';
    _logger.i('Adding new otp: $otp');
    _logger.i('Adding new fcmToken: $fcmToken');
    try {
      // VerifyOtpDto (whoxa-nest-api) accepts `push_token` and threads it
      // into the same UserDevice upsert issueTokenPair() does for
      // deviceId/deviceName/platform — sent so a push can reach this device
      // right after signup/login without waiting for a separate call to
      // POST /auth/devices/push-token.
      final response = await _apiClient.request(
        ApiEndpoints.verifyOtpEmail,
        method: 'POST',
        body: isEmail
            ? {
                'email_id': email,
                'otp': otp,
                'login_type': 'email',
                'push_token': fcmToken,
                'platform': device,
                'user_type': 'business',
              }
            : {
                'country_code': countryCode,
                'mobile_num': phoneNumber,
                'otp': otp,
                'login_type': 'phone',
                'push_token': fcmToken,
                'platform': device,
                'user_type': 'business',
                'country': ?country,
              },
      );
      return otpModel = VerifyOTPModel.fromJson(response);

      // // ✅ Store the resData into shared preferences
      // if (otpModel.resData != null) {
      //   await SharedPrefs.setModel(
      //     SharedPreferencesKey.OTPRESPONSEDATA,
      //     otpModel.resData!,
      //   );
      //   ResData? user = SharedPrefs.getModel<ResData>(
      //     SharedPreferencesKey.OTPRESPONSEDATA,
      //     (json) => ResData.fromJson(json),
      //   );

      //   _logger.i('User data saved to SharedPrefs');
      // }

      // _logger.i('OTP verification successful');
      // return VerifyOTPModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding otp:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User name check method ================================================
  //=============================================================================================================================
  UserNameCheckModel userNameCheckModel = UserNameCheckModel();

  Future<UserNameCheckModel> userNameCheckRepo(String xyz) async {
    _logger.i('Adding new user_name: $xyz');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.userNameCheck,
        method: 'POST',
        body: {'user_name': xyz, 'user_check': true},
      );

      return userNameCheckModel = UserNameCheckModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user_name:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User add Profiel method ===============================================
  //=============================================================================================================================
  UserProfileModel userProfileModel = UserProfileModel();
  Future<UserProfileModel> userProfileAddRepo(
    File? image, {
    required String userName,
    required String fname,
    required String lname,
    required String country,
    required String gender,
    required String deviceToken,
    // required String email,
    required String countryCode,
    required String mobile,
    String? avatarUrl,
    String pictureType = 'profile_pic',
  }) async {
    _logger.v('Adding new user_name: $userName');
    _logger.v('Adding new user_fname: $fname');
    _logger.v('Adding new user_lname: $lname');
    _logger.v('Adding new user_country: $country');
    _logger.v('Adding new user_gender: $gender');
    _logger.v('Adding new deviceToken: $deviceToken');
    // _logger.v('Adding new email: $email');
    _logger.v('Adding picture type: $pictureType');
    _logger.v('Adding avatarUrl: $avatarUrl');

    // Verified against actual backend source (UsersService.updateUserAction,
    // src/users/users.service.ts), not the guide's guess: this endpoint
    // bypasses the global DTO/ValidationPipe (reads @Req() directly). Its
    // non-multipart branch only assigns first_name, last_name, user_name,
    // bio, theme_color, description, location, latitude, longitude,
    // country, country_short_name, state, city, selfie — `gender`,
    // `country_code` (dialing code), and `mobile_num` are NOT read at all,
    // so those three are silently no-op'd. Left in the request since NEW
    // ignores them harmlessly either way and stripping requires a product
    // decision on whether the "edit phone/country/gender" UI should be
    // removed rather than silently no-op.
    var bodyData = <String, dynamic>{
      'user_name': userName,
      'first_name': fname,
      'last_name': lname,
      'gender': gender,
      'country_code': countryCode,
      'mobile_num': mobile,
    };

    // Avatar changes (file or catalog `avatarUrl`) and the text-field
    // update above are two SEPARATE requests on NEW, not one combined call
    // like OLD: `updateUserAction` checks `request.isMultipart()` first and,
    // if true, routes entirely to `updateAvatar()`, which reads ONLY the
    // avatar and ignores every other field in that same request — the
    // presigned media-upload flow's `avatarMediaId` is never read anywhere
    // on this endpoint at all. Confirmed field names (`files` for the file
    // part, `pictureType`/`avatarUrl` for catalog selection) are unchanged
    // from OLD.
    if (image != null) {
      await _apiClient.multipartRequest(
        ApiEndpoints.userCreateProfile,
        body: const {},
        files: {'files': image.path},
      );
    } else if (avatarUrl != null) {
      // Catalog-avatar selection also only takes effect through the
      // multipart branch (`fields.pictureType === 'avatar' && fields.avatarUrl`)
      // — sent as multipart fields with zero files, not JSON.
      await _apiClient.multipartRequest(
        ApiEndpoints.userCreateProfile,
        body: {'pictureType': 'avatar', 'avatarUrl': avatarUrl},
        files: const {},
      );
    }

    try {
      final response = await _apiClient.request(
        ApiEndpoints.userCreateProfile,
        method: 'POST',
        body: bodyData,
      );
      _logger.d('data pass in userProfileAddRepo: $bodyData');

      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user profile:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User get Profiel method ===============================================
  //=============================================================================================================================
  Future<UserProfileModel> userProfileGetRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.userCreateProfile,
        method: 'POST',
        body: {},
      );

      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user profile:', e.toString());
      rethrow;
    }
  }

  DeleteAccModel deleteAccModel = DeleteAccModel();
  Future<DeleteAccModel> deleteUserRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.deleteAcc,
        method: "DELETE",
        body: {},
      );

      return deleteAccModel = DeleteAccModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user delete:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User logout method ===============================================
  //=============================================================================================================================
  LogoutModel logoutModel = LogoutModel();
  // NEW's /auth/logout is @Public() and reads no body at all — it does
  // nothing server-side (no token invalidation, no socket_id linkage); the
  // `socketId` param is kept only so callers don't need to change, but it's
  // no longer sent. The frontend is responsible for discarding its own
  // token locally (already done unconditionally in AuthProvider.handleLogout).
  Future<LogoutModel> logoutUserRepo({String? socketId}) async {
    _logger.i('Logging out user (socket_id no longer sent to NEW backend)');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.logout,
        method: "POST",
        body: const {},
      );

      return logoutModel = LogoutModel.fromJson(response);
    } catch (e) {
      _logger.e('Error logging out user:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== Update Avatar Only method ===============================================
  //=============================================================================================================================
  Future<UserProfileModel> updateAvatarRepo({
    File? image,
    String? avatarUrl,
    String pictureType = 'profile_pic',
  }) async {
    _logger.i('Updating avatar only');
    _logger.i('Adding picture type: $pictureType');
    _logger.i('Adding avatarUrl: $avatarUrl');

    // Same real multipart-only avatar protocol as userProfileAddRepo above
    // (see its comment): `updateUser` routes a multipart request entirely
    // to `updateAvatar()`, which reads only the file/`avatarUrl` fields —
    // there is no JSON/`avatarMediaId` path for this at all.
    try {
      final response = image != null
          ? await _apiClient.multipartRequest(
              ApiEndpoints.userCreateProfile,
              body: const {},
              files: {'files': image.path},
            )
          : await _apiClient.multipartRequest(
              ApiEndpoints.userCreateProfile,
              body: {'pictureType': 'avatar', 'avatarUrl': avatarUrl ?? ''},
              files: const {},
            );
      _logger.d('Avatar update response: $response');

      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error updating avatar:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== Delete Avatar method ==================================================
  //=============================================================================================================================
  Future<UserProfileModel> deleteAvatarRepo() async {
    _logger.i('Deleting profile picture');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.deleteAvatar,
        method: 'DELETE',
        body: const {},
      );
      _logger.d('Avatar delete response: $response');

      // The endpoint may answer with the usual {status,data,message} envelope
      // or with an empty 200/204 body — treat the latter as a plain success
      // instead of blowing up on a null/non-map payload.
      if (response is Map<String, dynamic>) {
        return userProfileModel = UserProfileModel.fromJson(response);
      }
      return userProfileModel = UserProfileModel(status: true);
    } catch (e) {
      _logger.e('Error deleting profile picture:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== Get All Avatars method ===============================================
  //=============================================================================================================================
  AvatarModel avatarModel = AvatarModel();

  Future<AvatarModel> getAllAvatarsRepo() async {
    _logger.i('Fetching all avatars');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getAllAvatars,
        method: 'GET',
        body: {},
      );

      return avatarModel = AvatarModel.fromJson(response);
    } catch (e) {
      _logger.e('Error fetching avatars:', e.toString());
      rethrow;
    }
  }
}
