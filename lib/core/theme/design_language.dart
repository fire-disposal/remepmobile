import 'package:flutter/material.dart';

class AppDesignLanguage {
  AppDesignLanguage._();

  static const double pageHorizontalPadding = 16;
  static const double sectionSpacing = 12;
  static const BorderRadius panelRadius = BorderRadius.all(Radius.circular(12));

  static TextStyle panelTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);
  }
}
