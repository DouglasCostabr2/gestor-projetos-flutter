import 'package:flutter/material.dart';

/// Central UI constants to keep visual consistency across the app.
class UIConst {
  // Dashed borders
  static const double dashedStroke = 1.2;
  static const double dashLengthDefault = 6.0;
  static const double dashGapDefault = 6.0;

  // Assets section dash pattern
  static const double dashLengthAssets = 6.0;
  static const double dashGapAssets = 6.0;

  // Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;

  // Common sizes
  static const double assetCardSize = 150.0;

  // Colors (optional defaults; prefer theme when in doubt)
  static const Color sectionBg = Color(0xFF1A1A1A);
  static const Color sectionBorder = Color(0xFF2A2A2A);
  static const Color favoriteColor = Color(0xFFFFD700); // Gold color for favorite star
}

