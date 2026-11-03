import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/packages/phone_field/intl_phone_field.dart';
import 'package:whoxa/utils/packages/phone_field/phone_number.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/global_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';

class SaveContact extends StatefulWidget {
  final String? name;
  final String? number;
  const SaveContact({super.key, this.name, this.number});

  @override
  State<SaveContact> createState() => _SaveContactState();
}

class _SaveContactState extends State<SaveContact> {
  TextEditingController fname = TextEditingController();
  TextEditingController lname = TextEditingController();
  bool isPhoneValid = false;
  PhoneNumber? phoneNumber;
  bool isSaving = false;
  bool exists = false;

  @override
  void initState() {
    super.initState();
    setNameFromFullName(widget.name ?? '');

    final authProvider = context.read<AuthProvider>();
    authProvider.mobilecontroller.text = widget.number ?? '';
  }

  void setNameFromFullName(String fullName) {
    if (fullName.trim().isEmpty) return;

    List<String> parts = fullName.trim().split(' ');

    setState(() {
      fname.text = parts.first; // First word

      if (parts.length > 1) {
        lname.text = parts.sublist(1).join(' '); // Rest as last name
      } else {
        lname.text = '';
      }
    });
  }

  void checkDuplicate(String phone) {
    final contactProvider = context.read<ContactListProvider>();

    bool isNumberExists = contactProvider.isContactNumberExistss(phone);

    setState(() {
      exists = isNumberExists;
    });

    debugPrint("👋 phone: $phone");
    debugPrint("👋 exists: $exists");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.number != null && widget.number!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkDuplicate(widget.number!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          titleSpacing: 1,
          title: Text(
            "Save Contact",
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
          child: Column(
            children: [
              SizedBox(height: SizeConfig.height(5)),

              /// First Name
              GlobalTextField1(
                contentPadding: SizeConfig.getPaddingSymmetric(
                  vertical: 3,
                  horizontal: 15,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                ],
                style: AppTypography.inputPlaceholder(
                  context,
                ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                hintStyle: AppTypography.inputPlaceholder(context).copyWith(
                  fontSize: SizeConfig.getFontSize(11),
                  color: AppColors.textColor.textGreyColor,
                ),

                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.sentences,
                lable: AppString.addInfoScreenString.firstName,
                controller: fname,
                onEditingComplete: () {},
                hintText: AppString.addInfoScreenString.firstName,
                context: context,
                maxLines: 1,
                maxLength: 10,
              ),

              SizedBox(height: SizeConfig.height(0.5)),
              //====================== LAST NAME =======================================
              //====================== LAST NAME =======================================
              GlobalTextField1(
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                ],
                style: AppTypography.inputPlaceholder(
                  context,
                ).copyWith(fontSize: SizeConfig.getFontSize(12)),
                hintStyle: AppTypography.inputPlaceholder(context).copyWith(
                  fontSize: SizeConfig.getFontSize(11),
                  color: AppColors.textColor.textGreyColor,
                ),

                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.sentences,
                lable: AppString.addInfoScreenString.lastName,
                controller: lname,
                onEditingComplete: () {},
                hintText: AppString.addInfoScreenString.lastName,
                context: context,
                maxLines: 1,
                maxLength: 10,
              ),

              SizedBox(height: SizeConfig.height(1)),
              twoText(
                context,
                text1: AppString.loginEmailPhoneString.mobileNumber,
                text2: "*",
                style1: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
                style2: AppTypography.h5(
                  context,
                ).copyWith(color: AppColors.textColor.textErrorColor1),
                mainAxisAlignment: MainAxisAlignment.start,
              ),
              SizedBox(height: SizeConfig.height(0.5)),

              /// Country Code + Phone
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return IntlPhoneField(
                    key: ValueKey(authProvider.defaultCountrySortName),
                    dropdownDecoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: AppThemeManage.appTheme.greyBlackGrey,
                          width: 1.0,
                        ),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[,.\-]')),
                    ],
                    dropdownTextStyle: AppTypography.innerText11(context),
                    showCountryFlag: false,
                    showDropdownIcon: true,
                    dropdownIcon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 13,
                    ),
                    dropdownIconPosition: IconPosition.trailing,
                    initialCountryCode: authProvider.defaultCountrySortName,
                    initialValue: authProvider.selectedCountrycode,
                    onChanged: (number) async {
                      bool valid = false;

                      try {
                        valid = number.isValidNumber();
                      } catch (e) {
                        // NumberTooShortException, NumberTooLongException, etc.
                        valid = false;
                      }
                      logger.i(number.toString());
                      phone = number.completeNumber;
                      phoneNumber = number;
                      isPhoneValid = valid;
                      final contactProvider =
                          context.read<ContactListProvider>();

                      /// 🔹 Duplicate Check
                      bool isNumberExists = contactProvider
                          .isContactNumberExists(number.completeNumber);

                      setState(() {
                        exists = isNumberExists;
                      });
                      authProvider.validateInput();
                    },
                    onCountryChanged: (value) {
                      setState(() {
                        isPhoneValid = false;
                      });
                      authProvider.selectedCountrycode = "+${value.dialCode}";
                      debugPrint(authProvider.selectedCountrycode);

                      authProvider.defaultSelectedCountry = value.name;
                      authProvider.defaultCountrySortName = value.code;
                      debugPrint('Country Name: ${value.name}');
                      debugPrint(
                        'Default Country Name: ${authProvider.defaultSelectedCountry}',
                      );
                      debugPrint('Country Code: ${value.dialCode}');
                      debugPrint('Country ISO Code: ${value.code}');
                    },

                    cursorColor: AppColors.black,
                    autofocus: false,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: AppTypography.innerText11(context),
                    controller: authProvider.mobilecontroller,
                    keyboardType: TextInputType.number,
                    flagsButtonPadding: SizeConfig.getPaddingOnly(left: 5),
                    decoration: InputDecoration(
                      fillColor: AppThemeManage.appTheme.bg4BlackGrey,
                      filled: true,
                      counterText: '',
                      contentPadding: SizeConfig.getPaddingSymmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(
                          color: AppThemeManage.appTheme.greyBlackGrey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(
                          color: AppThemeManage.appTheme.greyBlackGrey,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(
                          color: AppColors.textColor.textErrorColor1,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(
                          color: AppColors.textColor.textErrorColor1,
                        ),
                      ),
                      errorStyle: TextStyle(
                        color: AppColors.textColor.textErrorColor1,
                        fontSize: SizeConfig.getFontSize(12),
                      ),
                    ),
                    validator: (value) {
                      authProvider
                          .validateInput(); // Ensure validation is checked on form submit
                      if (phone == null ||
                          phone!.isEmpty ||
                          authProvider.mobilecontroller.text.isEmpty) {
                        return 'Please Enter Your Valid Number';
                      }
                      return null;
                    },
                  );
                },
              ),
              if (exists) SizedBox(height: 4),
              if (exists)
                Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "This Contact already exists ",
                          style: TextStyle(
                            color: AppColors.grey,
                            fontSize: SizeConfig.getFontSize(13.5),
                          ),
                        ),
                        TextSpan(
                          text: "Flickpitch",
                          style: TextStyle(
                            color: AppColors.appPriSecColor.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: SizeConfig.height(5)),
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return Padding(
                    padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                    child:
                        isSaving
                            ? commonLoading()
                            : customBtn2(
                              context,
                              onTap:
                                  isSaving
                                      ? null
                                      : exists
                                      ? null
                                      : () {
                                        _saveContact(
                                          context,
                                          fname.text,
                                          lname.text,
                                          authProvider.selectedCountrycode +
                                              authProvider
                                                  .mobilecontroller
                                                  .text,
                                        );
                                      },
                              child: Text(
                                "Save",
                                style: AppTypography.h5(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: ThemeColorPalette.getTextColor(
                                    AppColors.appPriSecColor.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveContact(
    BuildContext context,
    String firstName,
    String lastName,
    String phone,
  ) async {
    /// 🔹 At least one name required
    if (firstName.isEmpty && lastName.isEmpty) {
      snackbarNew(context, msg: "Please enter first name or last name");
      return;
    }

    /// 🔹 Phone required
    if (phone.isEmpty) {
      snackbarNew(context, msg: "Phone number is required");
      return;
    }

    /// Request permission
    // if (!await FlutterContacts.requestPermission()) {
    //   if (context.mounted) {
    //     snackbarNew(context, msg: "Permission denied");
    //   }
    //   return;
    // }
    final status = await FlutterContacts.permissions.request(
      PermissionType.readWrite,
    );

    if (status != PermissionStatus.granted) {
      if (context.mounted) {
        if (status == PermissionStatus.permanentlyDenied) {
          // User tapped "Never ask again" — send them to Settings
          snackbarNew(
            context,
            msg: "Permission permanently denied. Please enable it in Settings.",
          );
        } else {
          snackbarNew(context, msg: "Permission denied");
        }
      }
      return;
    }

    setState(() {
      isSaving = true;
    });

    // try {
    //   final newContact =
    //       Contact()
    //         ..name.first = firstName
    //         ..name.last = lastName
    //         ..phones = [Phone(phone)];

    //   await newContact.insert();

    //   await Future.delayed(const Duration(milliseconds: 500));
    //   if (context.mounted) {
    //     // ✅ Clear sync timestamp so incremental sync treats this as changed
    //     await context.read<ContactListProvider>().clearSyncDataAndRefresh();
    //   }
    //   if (context.mounted) {
    //     Navigator.pop(context); // close dialog
    //     snackbarNew(context, msg: "Contact Saved Successfully");
    //   }
    // }
    try {
      // ✅ New — Contact() uses named constructor params
      final newContact = Contact(
        name: Name(first: firstName, last: lastName),
        phones: [Phone(number: phone)],
      );

      // ✅ New — static FlutterContacts.create() instead of newContact.insert()
      // Returns the saved Contact with its device-assigned id
      await FlutterContacts.create(newContact);

      await Future.delayed(const Duration(milliseconds: 500));
      if (context.mounted) {
        await context.read<ContactListProvider>().clearSyncDataAndRefresh();
      }
      if (context.mounted) {
        Navigator.pop(context);
        snackbarNew(context, msg: "Contact Saved Successfully");
      }
    } catch (e) {
      if (context.mounted) {
        snackbarNew(context, msg: "Something went wrong");
      }
    }

    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }
}
