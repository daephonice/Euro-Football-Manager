import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const ink = Color(0xFF080D1A);
const inkRaised = Color(0xFF121A2E);
const inkLine = Color(0xFF263050);
const volt = Color(0xFFC6FF3D);
const voltDeep = Color(0xFF4F7A00);
const mist = Color(0xFF8C97B5);
const bone = Color(0xFFF2F5FF);
const sky = Color(0xFF5BC0FF);
const amber = Color(0xFFFFD60A);
const alert = Color(0xFFFF5C72);

const kCond = 'sans-serif-condensed';

TextStyle hStyle([double size = 26, Color color = bone]) => TextStyle(
    fontFamily: kCond,
    fontSize: size,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.2,
    color: color,
    height: 1.1);

TextStyle bStyle([double size = 15, Color color = bone]) =>
    TextStyle(fontSize: size, color: color, height: 1.35, letterSpacing: 0.2);

TextStyle lStyle([Color color = mist]) => TextStyle(
    fontFamily: kCond,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
    color: color);

ThemeData brandTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: volt, brightness: b).copyWith(
    primary: dark ? volt : voltDeep,
    onPrimary: dark ? ink : Colors.white,
    surface: dark ? ink : const Color(0xFFF6F8FF),
  );
  return ThemeData(colorScheme: cs, useMaterial3: true);
}

// ---- SVG line icons (stroke only) ----
const _h = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">';
const svgs = <String, String>{
  'back': '$_h<path d="M15 5l-7 7 7 7"/></svg>',
  'next': '$_h<path d="M9 5l7 7-7 7"/></svg>',
  'close': '$_h<path d="M6 6l12 12M18 6L6 18"/></svg>',
  'check': '$_h<path d="M4 12.5l5 5L20 6.5"/></svg>',
  'user': '$_h<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/></svg>',
  'flag': '$_h<path d="M5 21V4M5 4h11l-2 4 2 4H5"/></svg>',
  'shield': '$_h<path d="M12 3l8 3v6c0 4.5-3.4 7.8-8 9-4.6-1.2-8-4.5-8-9V6z"/></svg>',
  'trash': '$_h<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/></svg>',
  'play': '$_h<path d="M7 4l13 8-13 8z"/></svg>',
  'doc': '$_h<path d="M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6"/></svg>',
  'search': '$_h<circle cx="11" cy="11" r="6"/><path d="M16 16l5 5"/></svg>',
  'menu': '$_h<path d="M4 7h16M4 12h10M4 17h16"/></svg>',
  'home': '$_h<path d="M3 11l9-8 9 8M5 9.5V21h14V9.5M10 21v-6h4v6"/></svg>',
  'squad': '$_h<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6M16 4.8a3.5 3.5 0 0 1 0 6.4M18 14.4c2.2.8 3.5 2.6 3.5 5.6"/></svg>',
  'tactics': '$_h<path d="M5 5l4 4M9 5L5 9M16 15l4 4M20 15l-4 4"/><circle cx="18" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><path d="M8 18c6 0 4-8 8-9.5"/></svg>',
  'transfer': '$_h<path d="M4 8h14l-3-3M20 16H6l3 3"/></svg>',
  'training': '$_h<path d="M12 3l6 17H6zM8.5 13h7M7 17h10M4 20h16"/></svg>',
  'finances': '$_h<path d="M4 20V13M10 20V9M16 20V12M22 20H2M14 6l3-3 3 3M17 3v6"/></svg>',
  'facility': '$_h<path d="M3 21h18M5 21V9l7-5 7 5v12M9 21v-6h6v6M9 11h6"/></svg>',
  'trophy': '$_h<path d="M7 4h10v5a5 5 0 0 1-10 0zM7 6H4v2a3 3 0 0 0 3 3M17 6h3v2a3 3 0 0 1-3 3M12 14v4M8 21h8M9 18h6"/></svg>',
  'award': '$_h<circle cx="12" cy="9" r="6"/><path d="M8.5 14L7 22l5-3 5 3-1.5-8"/></svg>',
  'gear': '$_h<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/></svg>',
  'exit': '$_h<path d="M10 4H5v16h5M15 8l4 4-4 4M19 12H9"/></svg>',
  'sun': '$_h<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M19 5l-1.5 1.5M6.5 17.5L5 19"/></svg>',
  'moon': '$_h<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/></svg>',
  'more': '$_h<circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/></svg>',
  'info': '$_h<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/></svg>',
  'ball': '$_h<circle cx="12" cy="12" r="9"/><path d="M12 8l3.5 2.5-1.3 4h-4.4l-1.3-4z"/><path d="M12 8V3M15.5 10.5l5-1.5M14.2 14.5l3 4M9.8 14.5l-3 4M8.5 10.5L3.5 9"/></svg>',
  'card': '$_h<rect x="7" y="4" width="10" height="16" rx="1.5"/></svg>',
  'cross': '$_h<path d="M12 5v14M5 12h14"/></svg>',
  'bars': '$_h<path d="M5 20V10M12 20V4M19 20v-7"/></svg>',
  'trend': '$_h<path d="M3 17l6-6 4 4 8-9M15 6h6v6"/></svg>',
  'board': '$_h<rect x="3" y="5" width="18" height="14"/><path d="M12 5v14"/><circle cx="12" cy="12" r="3"/></svg>',
  'list': '$_h<path d="M9 6h12M9 12h12M9 18h12M3.5 6h.5M3.5 12h.5M3.5 18h.5"/></svg>',
  'fast': '$_h<path d="M4 5l8 7-8 7zM12 5l8 7-8 7z"/></svg>',
  'pause': '$_h<path d="M8 5v14M16 5v14"/></svg>',
  'pitch': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 600" fill="none" stroke="#000" stroke-width="2"><rect x="20" y="20" width="360" height="560"/><path d="M20 300h360"/><circle cx="200" cy="300" r="64"/><circle cx="200" cy="300" r="3"/><rect x="100" y="20" width="200" height="90"/><rect x="150" y="20" width="100" height="36"/><rect x="100" y="490" width="200" height="90"/><rect x="150" y="544" width="100" height="36"/><path d="M140 110a64 64 0 0 0 120 0M140 490a64 64 0 0 1 120 0"/></svg>',
  'emblem': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="#000" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round"><path d="M32 4l24 8v18c0 14-10 24-24 30C18 54 8 44 8 30V12z"/><circle cx="32" cy="30" r="12"/><path d="M32 22l7 5-3 8h-8l-3-8z"/><path d="M32 18v4M39 27l5-2M36 35l3 5M28 35l-3 5M25 27l-5-2"/></svg>',
};

class Ico extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const Ico(this.name, {this.size = 22, this.color = bone, super.key});
  @override
  Widget build(BuildContext context) => SvgPicture.string(svgs[name]!,
      width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
}

// ---- shared widgets ----
class BrandBg extends StatelessWidget {
  final Widget child;
  final bool pitch;
  const BrandBg({required this.child, this.pitch = false, super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0E1630), ink])),
        child: Stack(children: [
          if (pitch)
            Positioned.fill(
                child: Opacity(
                    opacity: 0.09,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 90, 28, 28),
                        child: SvgPicture.string(svgs['pitch']!,
                            fit: BoxFit.fitHeight,
                            colorFilter: const ColorFilter.mode(volt, BlendMode.srcIn))))),
          child,
        ]),
      );
}

class BrandPage extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottom;
  final bool back;
  const BrandPage(
      {required this.title, required this.body, this.bottom, this.back = true, super.key});
  @override
  Widget build(BuildContext context) => Theme(
        data: brandTheme(Brightness.dark),
        child: Scaffold(
          backgroundColor: ink,
          body: BrandBg(
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
                  child: Row(children: [
                    if (back)
                      IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Ico('back'))
                    else
                      const SizedBox(width: 16),
                    Expanded(child: Text(title.toUpperCase(), style: hStyle(20))),
                  ]),
                ),
                Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 20), color: volt.withOpacity(0.9)),
                Expanded(child: body),
                if (bottom != null) bottom!,
              ]),
            ),
          ),
        ),
      );
}

class BrandButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  const BrandButton(this.label, {this.onTap, this.filled = true, this.color, super.key});
  @override
  Widget build(BuildContext context) {
    final c = color ?? volt;
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? (on ? c : c.withOpacity(0.25)) : Colors.transparent,
          border: Border.all(color: on ? c : c.withOpacity(0.3), width: 1.6),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
              topRight: Radius.circular(3),
              bottomLeft: Radius.circular(3)),
        ),
        child: Text(label.toUpperCase(),
            style: hStyle(16, filled ? (on ? ink : ink.withOpacity(0.5)) : (on ? c : c.withOpacity(0.4)))
                .copyWith(letterSpacing: 3)),
      ),
    );
  }
}

class Pips extends StatelessWidget {
  final int n;
  const Pips(this.n, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Container(
              width: 14,
              height: 5,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                  color: i <= n ? volt : Colors.transparent,
                  border: Border.all(color: i <= n ? volt : inkLine),
                  borderRadius: BorderRadius.circular(1))),
      ]);
}

String monogram(String n) {
  final w = n.split(RegExp(r'\s+')).where((x) => x.length > 2).toList();
  final b = (w.isEmpty ? n : w.first).replaceAll(RegExp(r'[^A-Za-z]'), '');
  return (b.length > 3 ? b.substring(0, 3) : b).toUpperCase();
}

String ordinal(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 13) return '${n}th';
  return '$n${switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';
}

class Crest extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const Crest(this.name, {this.color = volt, this.size = 46, super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.8)),
        child: Text(monogram(name), style: hStyle(size * 0.3, color).copyWith(letterSpacing: 0.5)),
      );
}
