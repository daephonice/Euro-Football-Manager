String fmtMoney(num v) {
  final a = v.abs();
  final s = v < 0 ? '-' : '';
  if (a >= 1e6) return '$s£${(a / 1e6).toStringAsFixed(a >= 1e8 ? 0 : 1)}M';
  if (a >= 1e3) return '$s£${(a / 1e3).round()}K';
  return '$s£${a.round()}';
}
