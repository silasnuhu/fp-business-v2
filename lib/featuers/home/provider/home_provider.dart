import 'package:flutter/material.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class HomeProvider extends ChangeNotifier {
  String isSelected = '';
  int selectedIndex = 0;
  String isSelectLoginType = AppString.homeScreenString.chat;
  PageController pageController = PageController(initialPage: 0);
  TextEditingController chatCtrl = TextEditingController();
}
