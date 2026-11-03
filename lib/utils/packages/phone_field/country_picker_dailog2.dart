import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/packages/phone_field/countries.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

class CountryPickerDialog2 extends StatefulWidget {
  final List<Country> countries;
  final ValueChanged<Country> onCountrySelected;

  const CountryPickerDialog2({
    super.key,
    required this.countries,
    required this.onCountrySelected,
  });

  @override
  State<CountryPickerDialog2> createState() => _CountryPickerDialog2State();
}

class _CountryPickerDialog2State extends State<CountryPickerDialog2> {
  late List<Country> filteredCountries;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredCountries = widget.countries;
    searchController.addListener(_filterCountries);
  }

  void _filterCountries() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredCountries =
          widget.countries.where((country) {
            return country.name.toLowerCase().contains(query) ||
                country.dialCode.contains(
                  query,
                ); // optional: search by dialCode
          }).toList();
    });
  }

  @override
  void dispose() {
    searchController.removeListener(_filterCountries);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      elevation: 0,
      insetPadding: SizeConfig.getPaddingSymmetric(
        horizontal: 20,
        vertical: 50,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: SizeConfig.height(2)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 3),
                hintText: 'Search country',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(1)),
          Divider(color: AppColors.strokeColor.cEEEEEE),
          Expanded(
            child: ListView.builder(
              itemCount: filteredCountries.length,
              itemBuilder: (context, index) {
                final country = filteredCountries[index];
                return ListTile(
                  title: Text(country.name),
                  leading: Text(country.flag, style: TextStyle(fontSize: 20)),
                  onTap: () => widget.onCountrySelected(country),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// class CountryPickerDialog2 extends StatelessWidget {
//   final List<Country> countries;
//   final ValueChanged<Country> onCountrySelected;

//   const CountryPickerDialog2({
//     super.key,
//     required this.countries,
//     required this.onCountrySelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: AppColors.white,
//       elevation: 0,
//       child: Column(
//         children: [
//           SizedBox(height: SizeConfig.height(2)),
//           Text(
//             "Countries",
//             style: poppinsFont(15, AppColors.black, FontWeight.w600),
//           ),
//           SizedBox(height: SizeConfig.height(0.5)),
//           Divider(color: AppColors.greyShade300),
//           Expanded(
//             child: SingleChildScrollView(
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 padding: EdgeInsets.zero,
//                 physics: NeverScrollableScrollPhysics(),
//                 itemCount: countries.length,
//                 itemBuilder: (context, index) {
//                   final country = countries[index];
//                   return ListTile(
//                     title: Text(country.name),
//                     leading: Text(
//                       country.flag,
//                       style: TextStyle(fontSize: 20),
//                     ), // if you want to show emoji flags
//                     onTap: () => onCountrySelected(country),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
