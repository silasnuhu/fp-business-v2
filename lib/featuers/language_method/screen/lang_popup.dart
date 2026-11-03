import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class LanguagePopUp extends StatefulWidget {
  const LanguagePopUp({super.key});

  @override
  State<LanguagePopUp> createState() => _LanguagePopUpState();
}

class _LanguagePopUpState extends State<LanguagePopUp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      langListGet().whenComplete(() {
        _loadSavedLang();
      });
    });
  }

  Future<void> langListGet() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    await langProvider.languageListApi();
  }

  int? selectedLangIndex;

  Future<void> _loadSavedLang() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    debugPrint(userTextDirection);

    // safely read from secure storage
    String? langD = await SecurePrefs.getString(SecureStorageKeys.LANG_ID);

    langID = langD ?? ""; // assign empty string if null
    debugPrint("langID:$langID");

    if (langID.isNotEmpty) {
      // 🔹 If LANG_ID exists, try to match saved language
      final index = langProvider.languageListData.indexWhere(
        (element) => element.languageId.toString() == langID,
      );

      if (index != -1) {
        setState(() {
          selectedLangIndex = index;
          debugPrint("selectedLangIndex:$selectedLangIndex");
        });
      }
    } else {
      // 🔹 If LANG_ID not found, fallback to English
      final index = langProvider.languageListData.indexWhere(
        (element) => element.language == "English",
      );

      if (index != -1) {
        setState(() {
          selectedLangIndex = index;
          debugPrint("selectedLangIndex:$selectedLangIndex");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        if (langProvider.isLanguagLoading) {
          return Center(child: commonLoading());
        }

        if (langProvider.languageListData.isEmpty) {
          return Align(
            alignment: Alignment.center,
            child: Text("Language Data Not Found"),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    reverse: true,
                    scrollDirection: Axis.vertical,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: langProvider.languageListData.length,
                    itemBuilder: (BuildContext context, int index) {
                      return (langProvider.languageListData[index].status ==
                              true)
                          ? GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              setState(() {
                                selectedLangIndex = index;
                              });
                            },
                            child: Padding(
                              padding: SizeConfig.getPaddingSymmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 20,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            AppColors
                                                .appPriSecColor
                                                .primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(1.5),
                                      decoration:
                                          (selectedLangIndex == index)
                                              ? BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    AppColors
                                                        .appPriSecColor
                                                        .primaryColor,
                                              )
                                              : BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.white,
                                              ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    langProvider
                                        .languageListData[index]
                                        .language,
                                    style: AppTypography.innerText14(context),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: SizeConfig.getPaddingOnly(
                left: 35,
                right: 35,
                bottom: 10,
              ),
              child:
                  langProvider.isGetLanguagsLoading
                      ? SizedBox(height: 40, width: 40, child: commonLoading())
                      : SizedBox(
                        height: SizeConfig.sizedBoxHeight(40),
                        child: customBtn2(
                          context,
                          onTap: () async {
                            if (selectedLangIndex != null) {
                              final success = await langProvider.wordListApi(
                                languageId:
                                    langProvider
                                        .languageListData[selectedLangIndex!]
                                        .languageId
                                        .toString(),
                              );

                              final msg = langProvider.errorMessage.toString();
                              if (success == true) {
                                await SecurePrefs.setString(
                                  SecureStorageKeys.LANG_ID,
                                  langProvider
                                      .languageListData[selectedLangIndex!]
                                      .languageId
                                      .toString(),
                                );
                                String? langD =
                                    (await SecurePrefs.getString(
                                      SecureStorageKeys.LANG_ID,
                                    ))!;
                                langID = langD;
                                debugPrint(
                                  "langID:${langProvider.languageListData[selectedLangIndex!].languageId.toString()}",
                                );
                                langProvider.currentDirection =
                                    langProvider
                                                .languageListData[selectedLangIndex!]
                                                .languageAlignment ==
                                            'RTL'
                                        ? TextDirection.rtl
                                        : TextDirection.ltr;
                                await SecurePrefs.setString(
                                  SecureStorageKeys.textDirection,
                                  langProvider.currentDirection ==
                                          TextDirection.rtl
                                      ? "RTL"
                                      : "LTR",
                                );
                                userTextDirection =
                                    (await SecurePrefs.getString(
                                      SecureStorageKeys.textDirection,
                                    ))!;
                                debugPrint("Navigator Back");
                                langProvider.notify();
                                if (!context.mounted) return;
                                Navigator.pop(context);
                              } else {
                                if (!context.mounted) return;
                                snackbarNew(context, msg: msg);
                              }
                            } else {
                              snackbarNew(
                                context,
                                msg: "Please Select language",
                              );
                            }
                          },
                          child: Text(
                            AppString.save,
                            style: AppTypography.innerText14(context).copyWith(
                              color: ThemeColorPalette.getTextColor(
                                AppColors.appPriSecColor.primaryColor,
                              ), //AppColors.textColor.textBlackColor,
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        );
      },
    );
  }
}
