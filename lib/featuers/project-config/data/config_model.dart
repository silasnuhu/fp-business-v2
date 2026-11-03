// *****************************************************************************************
// * Filename: project_config_model.dart                                                   *
// * Developer:Deval Joshi                               *
// * Date: 25 June 25
// * Description: Model class for handling project configuration data from API             *
// *****************************************************************************************

class ProjectConfig {
  final bool status;
  final ProjectConfigData data;
  final String message;
  final bool toast;

  ProjectConfig({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory ProjectConfig.fromJson(Map<String, dynamic> json) {
    return ProjectConfig(
      status: json['status'] ?? false,
      data: ProjectConfigData.fromJson(json['data'] ?? {}),
      message: json['message'] ?? '',
      toast: json['toast'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.toJson(),
      'message': message,
      'toast': toast,
    };
  }

  @override
  String toString() {
    return 'ProjectConfig{status: $status, data: $data, message: $message, toast: $toast}';
  }
}

class ProjectConfigData {
  final String appLogoLight;
  final String appLogoDark;
  final String webLogoLight;
  final String webLogoDark;
  final String twilioAccountSid;
  final String twilioAuthToken;
  final String twilioPhoneNumber;
  final String password;
  final String emailBanner;
  final int configId;
  final bool phoneAuthentication;
  final bool emailAuthentication;
  final int maximumMembersInGroup;
  final bool showAllContacts;
  final bool showPhoneContacts;
  final bool userNameFlow;
  final bool contactFlow;
  final String appName;
  final String appEmail;
  final String appText;
  final String appPrimaryColor;
  final String appSecondaryColor;
  final String appIosLink;
  final String appAndroidLink;
  final String appTellAFriendText;
  final String emailService;
  final String smtpHost;
  final String email;
  final String emailTitle;
  final String copyrightText;
  final String privacyPolicy;
  final String termsAndConditions;
  final String createdAt;
  final String updatedAt;
  final bool demoCredential;

  ProjectConfigData({
    required this.appLogoLight,
    required this.appLogoDark,
    required this.webLogoLight,
    required this.webLogoDark,
    required this.twilioAccountSid,
    required this.twilioAuthToken,
    required this.twilioPhoneNumber,
    required this.password,
    required this.emailBanner,
    required this.configId,
    required this.phoneAuthentication,
    required this.emailAuthentication,
    required this.maximumMembersInGroup,
    required this.showAllContacts,
    required this.showPhoneContacts,
    required this.userNameFlow,
    required this.contactFlow,
    required this.appName,
    required this.appEmail,
    required this.appText,
    required this.appPrimaryColor,
    required this.appSecondaryColor,
    required this.demoCredential,
    required this.appIosLink,
    required this.appAndroidLink,
    required this.appTellAFriendText,
    required this.emailService,
    required this.smtpHost,
    required this.email,
    required this.emailTitle,
    required this.copyrightText,
    required this.privacyPolicy,
    required this.termsAndConditions,
    required this.createdAt,
    required this.updatedAt,
  });

   static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
      return defaultValue;
    }
    if (value is int) return value == 1;
    return defaultValue;
  }

  factory ProjectConfigData.fromJson(Map<String, dynamic> json) {
    return ProjectConfigData(
      appLogoLight: json['app_logo_light'] ?? '',
      appLogoDark: json['app_logo_dark'] ?? '',
      webLogoLight: json['web_logo_light'] ?? '',
      webLogoDark: json['web_logo_dark'] ?? '',
      twilioAccountSid: json['twilio_account_sid'] ?? '',
      twilioAuthToken: json['twilio_auth_token'] ?? '',
      twilioPhoneNumber: json['twilio_phone_number'] ?? '',
      password: json['password'] ?? '',
      emailBanner: json['email_banner'] ?? '',
      configId: json['config_id'] ?? 0,
      phoneAuthentication: json['phone_authentication'] ?? false,
      emailAuthentication: json['email_authentication'] ?? false,
      maximumMembersInGroup: json['maximum_members_in_group'] ?? 10,
      showAllContacts:
          json['show_all_contatcts'] ?? false, // Note: API has typo
      showPhoneContacts:
          json['show_phone_contatcs'] ?? false, // Note: API has typo
      userNameFlow:
          true, // Force true for testing (ignoring API: json['user_name_flow'])
      contactFlow:
          true, // Force true for testing (ignoring API: json['contact_flow'])
      appName: json['app_name'] ?? '',
      appEmail: json['app_email'] ?? '',
      appText: json['app_text'] ?? '',
      appPrimaryColor: json['app_primary_color'] ?? '',
      appSecondaryColor: json['app_secondary_color'] ?? '',
      appIosLink: json['app_ios_link'] ?? '',
      appAndroidLink: json['app_android_link'] ?? '',
      appTellAFriendText: json['app_tell_a_friend_text'] ?? '',
      emailService: json['email_service'] ?? '',
      smtpHost: json['smtp_host'] ?? '',
      email: json['email'] ?? '',
      emailTitle: json['email_title'] ?? '',
      copyrightText: json['copyright_text'] ?? '',
      privacyPolicy: json['privacy_policy'] ?? '',
      termsAndConditions: json['terms_and_conditions'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      demoCredential: _parseBool(json['demo_credential']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_logo_light': appLogoLight,
      'app_logo_dark': appLogoDark,
      'web_logo_light': webLogoLight,
      'web_logo_dark': webLogoDark,
      'twilio_account_sid': twilioAccountSid,
      'twilio_auth_token': twilioAuthToken,
      'twilio_phone_number': twilioPhoneNumber,
      'password': password,
      'email_banner': emailBanner,
      'config_id': configId,
      'phone_authentication': phoneAuthentication,
      'email_authentication': emailAuthentication,
      'maximum_members_in_group': maximumMembersInGroup,
      'show_all_contatcts': showAllContacts,
      'show_phone_contatcs': showPhoneContacts,
      'user_name_flow': userNameFlow,
      'contact_flow': contactFlow,
      'app_name': appName,
      'app_email': appEmail,
      'app_text': appText,
      'app_primary_color': appPrimaryColor,
      'app_secondary_color': appSecondaryColor,
      'app_ios_link': appIosLink,
      'app_android_link': appAndroidLink,
      'app_tell_a_friend_text': appTellAFriendText,
      'email_service': emailService,
      'smtp_host': smtpHost,
      'email': email,
      'email_title': emailTitle,
      'copyright_text': copyrightText,
      'privacy_policy': privacyPolicy,
      'terms_and_conditions': termsAndConditions,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'demo_credential': demoCredential,
    };
  }

  @override
  String toString() {
    return 'ProjectConfigData{appName: $appName, configId: $configId, phoneAuth: $phoneAuthentication, emailAuth: $emailAuthentication}';
  }

  // Helper methods for easy access
  bool get isPhoneAuthEnabled => phoneAuthentication;
  bool get isEmailAuthEnabled => emailAuthentication;
  bool get hasAppName => appName.isNotEmpty;
  bool get hasTwilioConfig =>
      twilioAccountSid.isNotEmpty && twilioAuthToken.isNotEmpty;
}
