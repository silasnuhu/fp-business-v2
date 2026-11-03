import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/project-config/data/config_repo.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

/// Theme Color Picker Screen
class ThemeColorPicker extends StatefulWidget {
  const ThemeColorPicker({super.key});

  @override
  State<ThemeColorPicker> createState() => _ThemeColorPickerState();
}

class _ThemeColorPickerState extends State<ThemeColorPicker> {
  String? selectedColorHex;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Get currently selected color
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    selectedColorHex = themeProvider.customThemeColor;
  }

  /// Convert Color to hex string
  String colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Apply selected theme color
  Future<void> applyThemeColor(BuildContext context, String colorHex) async {
    setState(() {
      isLoading = true;
    });

    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      // Save the custom theme color
      await themeProvider.setCustomThemeColor(colorHex);

      // Update app colors
      final cleanHex = colorHex.replaceAll("#", "");
      final colorInt = int.parse("0xFF$cleanHex");
      AppColors.appPriSecColor.primaryColor = Color(colorInt);
      AppColors.appPriSecColor.secondaryColor = Color(colorInt);

      if (context.mounted) {
        Navigator.pop(context);
        snackbarNew(
          context,
          msg: AppString.settingStrigs.themeColorUpdated,
        ); //"Theme color updated successfully");
      }
    } catch (e) {
      if (context.mounted) {
        snackbarNew(context, msg: AppString.errorApplyingThemeColor("$e"));
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Reset to default theme
  Future<void> resetToDefault(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      // Clear custom theme color
      await themeProvider.resetToDefaultTheme();

      // Check if widget is still mounted before using context
      if (!context.mounted) return;

      // Reload project configuration to get default color using dependency injection
      final projectConfigRepo = getIt<ProjectConfigRepository>();
      await projectConfigRepo.getProjectConfiguration();

      // Trigger rebuild by notifying ThemeProvider listeners
      // This ensures the SettingsScreen color circle updates
      themeProvider.triggerRebuild();

      if (context.mounted) {
        Navigator.pop(context);
        snackbarNew(
          context,
          msg: AppString.settingStrigs.themeResetToDefault,
        ); //"Theme reset to default");
      }
    } catch (e) {
      if (context.mounted) {
        snackbarNew(context, msg: AppString.errorResettingTheme("$e"));
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: AppBar(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppThemeManage.appTheme.darkWhiteColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppString.settingStrigs.chatcolor, //"Chat color",
          style: AppTypography.h5(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: SizeConfig.getPaddingSymmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: SizeConfig.width(4),
                      mainAxisSpacing: SizeConfig.height(2),
                    ),
                    itemCount: ThemeColorPalette.colors.length,
                    itemBuilder: (context, index) {
                      final color = ThemeColorPalette.colors[index];
                      final colorHex = colorToHex(color);
                      final isSelected = selectedColorHex == colorHex;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColorHex = colorHex;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppThemeManage.appTheme.darkWhiteColor
                                      : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child:
                              isSelected
                                  ? Icon(
                                    Icons.check,
                                    color: _getContrastColor(color),
                                    size: SizeConfig.height(3),
                                  )
                                  : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Bottom action buttons
              Padding(
                padding: SizeConfig.getPaddingSymmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Reset to Default button
                    Expanded(
                      child: SizedBox(
                        height: SizeConfig.height(5.5),
                        child: OutlinedButton(
                          onPressed:
                              isLoading ? null : () => resetToDefault(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppThemeManage.appTheme.borderColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            AppString
                                .settingStrigs
                                .resetToDefault, //"Reset to Default",
                            style: AppTypography.innerText12Mediu(context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: SizeConfig.width(3)),
                    // Apply button
                    Expanded(
                      child: SizedBox(
                        height: SizeConfig.height(5.5),
                        child: ElevatedButton(
                          onPressed:
                              isLoading || selectedColorHex == null
                                  ? null
                                  : () => applyThemeColor(
                                    context,
                                    selectedColorHex!,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.appPriSecColor.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            AppString.settingStrigs.apply, //"Apply",
                            style: AppTypography.buttonText12(context).copyWith(
                              color: ThemeColorPalette.getTextColor(
                                AppColors.appPriSecColor.primaryColor,
                              ), //AppThemeManage.appTheme.darkWhiteColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
            ],
          ),
          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.appPriSecColor.primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Get contrasting color (white or black) for the given background color
  Color _getContrastColor(Color backgroundColor) {
    // Calculate luminance
    final red = (backgroundColor.r * 255.0).round() & 0xff;
    final green = (backgroundColor.g * 255.0).round() & 0xff;
    final blue = (backgroundColor.b * 255.0).round() & 0xff;

    final luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;

    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
