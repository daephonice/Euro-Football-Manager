import 'dart:math';

/// Double round-robin (circle method). Returns rounds of (home, away) club ids.
List<List<(int, int)>> doubleRoundRobin(List<int> teams, Random r) {
  final t = [...teams]..shuffle(r);
  if (t.length.isOdd) t.add(-1);
  final n = t.length;
  final first = <List<(int, int)>>[];
  for (var rd = 0; rd < n - 1; rd++) {
    final m = <(int, int)>[];
    for (var i = 0; i < n ~/ 2; i++) {
      final a = t[i], b = t[n - 1 - i];
      if (a == -1 || b == -1) continue;
      m.add((rd + i).isEven ? (a, b) : (b, a));
    }
    first.add(m);
    t.insert(1, t.removeLast());
  }
  final second = [
    for (final m in first) [for (final (h, a) in m) (a, h)]
  ];
  return [...first, ...second];
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Day 0 = 1 Aug of season year.
String dayLabel(int year, int day) {
  final d = DateTime(year, 8, 1).add(Duration(days: day));
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}
