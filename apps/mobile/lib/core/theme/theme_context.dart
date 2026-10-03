import 'package:flutter/material.dart';

import 'clivora_theme_extensions.dart';

extension ClivoraThemeContext on BuildContext {
  ClivoraSemanticColors get clivoraColors =>
      Theme.of(this).extension<ClivoraSemanticColors>() ?? ClivoraSemanticColors.freelancerLight();

  ClivoraLayoutTokens get clivoraLayout =>
      Theme.of(this).extension<ClivoraLayoutTokens>() ?? ClivoraLayoutTokens.standard;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
