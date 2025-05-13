import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:flutter/material.dart';

class AppTheme {

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    const Color textColor = Colors.black87;
    const Color mutedTextColor = Colors.black54;
    const Color inputBorderColor = Colors.black38;
    const Color inputFillColor = Color(0x0D000000);
    const Color dividerColor = Colors.black26;
    const Color dropdownIconColor = Colors.black54;

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        secondary: AppColors.secondary,
        brightness: Brightness.light,
        background: AppColors.lightBackground,
      ),
      appBarTheme: base.appBarTheme.copyWith(
         backgroundColor: AppColors.lightBackground,
         foregroundColor: Colors.black,
         elevation: 0.5,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
         style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.getButtonForegroundColor(AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),
            padding: const EdgeInsets.symmetric(vertical: 14),
         ),
      ),
      textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
         )
       ),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFillColor,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius)),
              borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius)),
              borderSide: BorderSide(color: inputBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius)),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          labelStyle: TextStyle(color: mutedTextColor),
          hintStyle: TextStyle(color: mutedTextColor),
          prefixStyle: TextStyle(color: textColor),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
       ),
       dividerTheme: DividerThemeData(
          color: dividerColor,
          thickness: 1,
       ),
       iconTheme: base.iconTheme.copyWith(color: Colors.black54),
    );
  }

  static ThemeData get darkTheme {
     final base = ThemeData.dark(useMaterial3: true);
     const Color textColor = Color(0xE6FFFFFF);
     const Color mutedTextColor = Colors.white70;
     const Color inputBorderColor = Colors.white54;
     const Color inputFillColor = Color(0x14FFFFFF);
     const Color dividerColor = Colors.white38;
     const Color dropdownIconColor = Colors.white70;


     return base.copyWith(
       brightness: Brightness.dark,
       scaffoldBackgroundColor: AppColors.darkBackground,
       primaryColor: AppColors.primary,
       colorScheme: ColorScheme.fromSeed(
         seedColor: AppColors.primary,
         secondary: AppColors.secondary,
         brightness: Brightness.dark,
         background: AppColors.darkBackground,
       ),
       appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: Colors.white,
          elevation: 0.5,
       ),
       elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
             backgroundColor: AppColors.primary,
             foregroundColor: AppColors.getButtonForegroundColor(AppColors.primary),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),
             padding: const EdgeInsets.symmetric(vertical: 14),
          ),
       ),
       textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
            foregroundColor: mutedTextColor,
         )
       ),
       inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFillColor,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius)),
               borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius)),
              borderSide: BorderSide(color: inputBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius)),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          labelStyle: TextStyle(color: mutedTextColor), 
          hintStyle: TextStyle(color: mutedTextColor), 
          prefixStyle: TextStyle(color: textColor),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
       ),
       dividerTheme: DividerThemeData(
          color: dividerColor,
          thickness: 1,
       ),
       iconTheme: base.iconTheme.copyWith(color: Colors.white70),
     );
  }

  AppTheme._();
}