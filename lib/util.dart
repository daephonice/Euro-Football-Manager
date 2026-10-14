import 'package:flutter/material.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

String fmtMoney(num v) {
  final a = v.abs();
  final s = v < 0 ? '-' : '';
  if (a >= 1e6) return '$s£${(a / 1e6).toStringAsFixed(a >= 1e8 ? 0 : 1)}M';
  if (a >= 1e3) return '$s£${(a / 1e3).round()}K';
  return '$s£${a.round()}';
}

String attrLabel(String k) {
  final s = k.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');
  return s[0].toUpperCase() + s.substring(1);
}
