// lib/core/constants/app_dimens.dart
import 'package:flutter/material.dart';

class AppDimens {
  static const double kDefaultPadding = 16.0;
  static const double kLargePadding = 24.0;
  static const double kSmallPadding = 8.0;

  static const double kSpacingVLarge = 40.0;
  static const double kSpacingLarge = 24.0;
  static const double kSpacingMedium = 16.0;
  static const double kSpacingSmall = 8.0;

  static const double kInputBorderRadius = 12.0;
  static const double kIconButtonRadius = 22.0;
  // *** ADD THIS LINE ***
  static const double kIconButtonSpacingPercent = 0.04; // Spacing between icons

  // Welcome Screen Specific
  static const double kLogoTopPaddingPercent = 0.06;
  static const double kLogoHeightPercent = 0.18;
  static const double kWelcomeTitleSpacing = kSpacingLarge;
  static const double kPhoneFieldSpacing = kSpacingLarge;
  static const double kContinueButtonSpacing = kSpacingLarge;
  static const double kDividerSpacing = kSpacingLarge;
  static const double kAltLoginSpacing = kSpacingLarge;
  static const double kRegisterButtonSpacing = kDefaultPadding;
  static const double kBottomPadding = kDefaultPadding;

  static const EdgeInsets kContinueButtonPadding = EdgeInsets.symmetric(vertical: 14);
  static const EdgeInsets kRegisterButtonPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 16);

  AppDimens._();
}