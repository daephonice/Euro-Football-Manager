import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/career.dart';
import 'db/competitions.dart';
import 'db/database.dart';
import 'db/seed.dart';
import 'util.dart';

class SlotMeta {
  final int slot;
  final String manager, nationality, club;
  final int season, week;
  const SlotMeta(this.slot, this.manager, this.nationality, this.club, this.season, this.week);
  Map<String, dynamic> toJson() =>
      {'m': manager, 'n': nationality, 'c': club, 's': season, 'w': week};
  factory SlotMeta.fromJson(int slot, Map<String, dynamic> j) =>
      SlotMeta(slot, j['m'], j['n'], j['c'], j['s'], j['w']);
}

class Slots {
  static const max = 5;
  static late SharedPreferences _p;
  static int? active;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    final t = _p.getInt('theme');
    if (t != null) themeNotifier.value = ThemeMode.values[t.clamp(0, 2)];
  }

  static Future<void> setTheme(ThemeMode m) async {
    themeNotifier.value = m;
    await _p.setInt('theme', m.index);
  }

  static String dbName(int i) => 'career_s$i';

  static SlotMeta? get(int i) {
    final s = _p.getString('slot_$i');
    if (s == null) return null;
    try {
      return SlotMeta.fromJson(i, jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  static List<SlotMeta> used() =>
      [for (var i = 1; i <= max; i++) if (get(i) != null) get(i)!];

  static int? freeSlot() {
    for (var i = 1; i <= max; i++) {
      if (get(i) == null) return i;
    }
    return null;
  }

  static Future<void> put(SlotMeta m) =>
      _p.setString('slot_${m.slot}', jsonEncode(m.toJson()));

  static Future<AppDatabase> open(int i) async {
    final db = AppDatabase(dbName(i));
    await seedIfEmpty(db);
    await ensureCompetitions(db);
    return db;
  }

  /// Empties the slot database and frees the slot.
  static Future<void> delete(int i) async {
    await _p.remove('slot_$i');
    await wipe(i);
  }

  static Future<void> wipe(int i) async {
    final db = AppDatabase(dbName(i));
    await db.customStatement('PRAGMA foreign_keys = OFF');
    for (final t in db.allTables) {
      await db.customStatement('DELETE FROM ${t.actualTableName}');
    }
    try {
      await db.customStatement('DELETE FROM sqlite_sequence');
    } catch (_) {}
    await db.close();
  }

  static Future<void> sync(HubData d) async {
    final i = active;
    final m = i == null ? null : get(i);
    if (m == null) return;
    await put(SlotMeta(i!, m.manager, m.nationality, d.me.name,
        d.season.year - 2025, d.season.currentDay ~/ 7 + 1));
  }
}
