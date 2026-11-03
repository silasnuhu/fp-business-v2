import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';

class PrivacyWebView extends StatefulWidget {
  final String htmlContent; // Accept HTML content
  final String title;

  const PrivacyWebView({
    super.key,
    required this.htmlContent,
    required this.title,
  });

  @override
  State<PrivacyWebView> createState() => _PrivacyWebViewState();
}

class _PrivacyWebViewState extends State<PrivacyWebView> {
  String cleanHtmlContent(String html) {
    return html
        .replaceAll(RegExp(r'<p><br></p>', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
            widget.title,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: SizeConfig.getFontSize(1)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Html(
                    data: cleanHtmlContent(widget.htmlContent),
                    onLinkTap: (url, attributes, element) async {
                      debugPrint("Opening $url...");
                      if (url == null) return;
                      final Uri uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        debugPrint("Could not launch $url");
                      }
                    },
                    shrinkWrap: true,
                    style: {
                      "*": Style(
                        // default for all tags
                        color: AppThemeManage.appTheme.textColor,
                        fontFamily: AppTypography.fontFamily.poppins,
                      ),
                      "h1": Style(
                        fontWeight: FontWeight.bold,
                        fontSize: FontSize.xLarge,
                      ),
                      "h2": Style(
                        fontWeight: FontWeight.bold,
                        fontSize: FontSize.larger,
                      ),
                      "h3": Style(fontWeight: FontWeight.w600),
                      "a": Style(
                        color: Colors.blue, // keep links visible
                        textDecoration: TextDecoration.underline,
                      ),
                      // "body": Style(
                      //   color: AppThemeManage.appTheme.textColor,
                      //   fontFamily: "Poppins",
                      // ),
                      // "div": Style(
                      //   color: AppThemeManage.appTheme.textColor,
                      //   fontFamily: "Poppins",
                      // ),
                      // "p": Style(
                      //   color: AppThemeManage.appTheme.textColor,
                      //   fontFamily: "Poppins",
                      // ),
                      // "h1": Style(
                      //   fontWeight: FontWeight.bold,
                      //   color: AppThemeManage.appTheme.textColor,
                      //   fontFamily: "Poppins",
                      // ),
                      // "sup": Style(
                      //   fontSize: FontSize.small,
                      //   color: AppThemeManage.appTheme.textColor,
                      //   fontFamily: "Poppins",
                      // ),
                    },
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
