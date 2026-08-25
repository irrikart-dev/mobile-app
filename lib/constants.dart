// ignore_for_file: deprecated_member_use_from_same_package

/// Compatibility shim.
///
/// Every value here now forwards to the token layer in `core/theme/tokens/`.
/// It exists so the ~89 files that import `constants.dart` keep compiling
/// while they migrate one at a time, rather than in a single unreviewable
/// 89-file diff.
///
/// **Do not add anything to this file.** Use the tokens directly:
///   `AppColors.primary`, `AppSpacing.md`, `AppRadius.md`, `AppDurations.normal`
///
/// This file is deleted once nothing imports it.
library;

import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

import 'core/theme/tokens/color_tokens.dart';
import 'core/theme/tokens/duration_tokens.dart';
import 'core/theme/tokens/radius_tokens.dart';
import 'core/theme/tokens/spacing_tokens.dart';
import 'core/theme/tokens/typography_tokens.dart';

// ---------------------------------------------------------------------------
// Demo image URLs. Replaced by assets/mock fixtures in the catalogue module.
// ---------------------------------------------------------------------------
const productDemoImg1 = 'https://i.imgur.com/CGCyp1d.png';
const productDemoImg2 = 'https://i.imgur.com/AkzWQuJ.png';
const productDemoImg3 = 'https://i.imgur.com/J7mGZ12.png';
const productDemoImg4 = 'https://i.imgur.com/q9oF9Yq.png';
const productDemoImg5 = 'https://i.imgur.com/MsppAcx.png';
const productDemoImg6 = 'https://i.imgur.com/JfyZlnO.png';

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------
@Deprecated('Use AppTypography.displayFont')
const grandisExtendedFont = AppTypography.displayFont;

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------
@Deprecated('Use AppColors.primary')
const Color primaryColor = AppColors.primary;

@Deprecated('Use AppColors.primarySwatch')
const MaterialColor primaryMaterialColor = AppColors.primarySwatch;

@Deprecated('Use AppColors.black')
const Color blackColor = AppColors.black;
@Deprecated('Use AppColors.black80')
const Color blackColor80 = AppColors.black80;
@Deprecated('Use AppColors.black60')
const Color blackColor60 = AppColors.black60;
@Deprecated('Use AppColors.black40')
const Color blackColor40 = AppColors.black40;
@Deprecated('Use AppColors.black20')
const Color blackColor20 = AppColors.black20;
@Deprecated('Use AppColors.black10')
const Color blackColor10 = AppColors.black10;
@Deprecated('Use AppColors.black5')
const Color blackColor5 = AppColors.black5;

@Deprecated('Use AppColors.white')
const Color whiteColor = AppColors.white;
// Spelling preserved from the template ("while") so imports keep resolving.
@Deprecated('Use AppColors.white80')
const Color whileColor80 = AppColors.white80;
@Deprecated('Use AppColors.white60')
const Color whileColor60 = AppColors.white60;
@Deprecated('Use AppColors.white40')
const Color whileColor40 = AppColors.white40;
@Deprecated('Use AppColors.white20')
const Color whileColor20 = AppColors.white20;
@Deprecated('Use AppColors.white10')
const Color whileColor10 = AppColors.white10;
@Deprecated('Use AppColors.white5')
const Color whileColor5 = AppColors.white5;

@Deprecated('Use AppColors.grey')
const Color greyColor = AppColors.grey;
@Deprecated('Use AppColors.greyLight')
const Color lightGreyColor = AppColors.greyLight;
@Deprecated('Use AppColors.greyDark')
const Color darkGreyColor = AppColors.greyDark;

@Deprecated('Use AppColors.primary')
const Color purpleColor = AppColors.primary;
@Deprecated('Use context.colors.success')
const Color successColor = AppColors.success;
@Deprecated('Use context.colors.warning')
const Color warningColor = AppColors.warning;
@Deprecated('Use Theme.of(context).colorScheme.error')
const Color errorColor = AppColors.error;

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------
@Deprecated('Use AppSpacing.md')
const double defaultPadding = AppSpacing.md;
// Spelling preserved from the template ("Radious").
@Deprecated('Use AppRadius.md')
const double defaultBorderRadious = AppRadius.md;
@Deprecated('Use AppDurations.normal')
const Duration defaultDuration = AppDurations.normal;

// ---------------------------------------------------------------------------
// Validators. Replaced by core/utils/validators.dart in the auth module.
// ---------------------------------------------------------------------------
final passwordValidator = MultiValidator([
  RequiredValidator(errorText: 'Password is required'),
  MinLengthValidator(8, errorText: 'Password must be at least 8 characters'),
  PatternValidator(
    r'(?=.*?[#?!@$%^&*-])',
    errorText: 'Password must have at least one special character',
  ),
]);

// Spelling preserved from the template ("emaild").
final emaildValidator = MultiValidator([
  RequiredValidator(errorText: 'Email is required'),
  EmailValidator(errorText: 'Enter a valid email address'),
]);

const pasNotMatchErrorText = 'Passwords do not match';
