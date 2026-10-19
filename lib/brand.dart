import 'package:flutter/painting.dart';

const kAppName = 'brew';
const kAppVersion = '0.1.0';

// FClash-style color scheme
const kBrewOrange = Color(0xFFF2711C);
const kBrewCoffee = Color(0xFF6F4E37);
const kBrewCaramel = Color(0xFFD99A3E);

// FClash-inspired dark theme colors
const kFClashBackground = Color(0xFF36302C);
const kFClashSurface = Color(0xFF423832);
const kFClashAccent = Color(0xFF6F5B4D);
const kFClashAccentLight = Color(0xFF8B7355);
const kFClashAccentBright = Color(0xFFA67C52);
const kFClashCardBackground = Color(0xFF453B35);

const kBrandFont = 'DM Sans';

/// DM Sans has no Cyrillic; Onest is a close geometric match that covers it.
const kBrandFallback = ['Onest', 'Segoe UI Variable', 'Segoe UI', 'Roboto'];
