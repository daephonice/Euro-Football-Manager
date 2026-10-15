import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'brand.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'db/seed.dart';
import 'menu.dart';
import 'slots.dart';
import 'util.dart';

const _nations = [
  'Albania', 'Argentina', 'Austria', 'Belgium', 'Bosnia and Herzegovina', 'Brazil',
  'Bulgaria', 'Cameroon', 'Canada', 'Colombia', 'Croatia', 'Czechia', 'Denmark',
  'Egypt', 'England', 'Finland', 'France', 'Germany', 'Ghana', 'Greece', 'Hungary',
  'Iceland', 'Ireland', 'Italy', 'Ivory Coast', 'Japan', 'Mexico', 'Morocco',
  'Netherlands', 'Nigeria', 'Northern Ireland', 'Norway', 'Poland', 'Portugal',
  'Romania', 'Scotland', 'Senegal', 'Serbia', 'Slovakia', 'Slovenia', 'South Korea',
  'Spain', 'Sweden', 'Switzerland', 'Turkey', 'Ukraine', 'United States', 'Uruguay',
  'Wales',
];

class ProfileScreen extends StatefulWidget {
  final int slot;
  const ProfileScreen(this.slot, {super.key});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  AppDatabase? _db;
  final _name = TextEditingController();
  String? _nat;
  Club? _club;
  bool _handed = false, _starting = false;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      var db = AppDatabase(Slots.dbName(widget.slot));
      await seedIfEmpty(db);
      if ((await loadCareer(db)).clubId != null) {
        await db.close();
        await Slots.wipe(widget.slot);
        db = AppDatabase(Slots.dbName(widget.slot));
        await seedIfEmpty(db);
      }
      if (!mounted) {
        await db.close();
        return;
      }
      setState(() => _db = db);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    if (!_handed) _db?.close();
    super.dispose();
  }

  bool get _ready => _name.text.trim().length >= 2 && _nat != null && _club != null;

  Future<void> _pickNat() async {
    final r = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: inkRaised,
        builder: (_) => const _NationSheet());
    if (r != null) setState(() => _nat = r);
  }

  Future<void> _pickClub() async {
    final r = await Navigator.of(context)
        .push<Club>(MaterialPageRoute(builder: (_) => TeamPicker(_db!)));
    if (r != null) setState(() => _club = r);
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final db = _db!;
    final name = _name.text.trim();
    await startCareer(db, _club!.id);
    final s = await loadCareer(db);
    await (db.update(db.careerSaves)..where((t) => t.id.equals(s.id)))
        .write(CareerSavesCompanion(name: Value(name)));
    await Slots.put(SlotMeta(widget.slot, name, _nat!, _club!.name, 1, 1));
    _handed = true;
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => GameHost(db, widget.slot)));
  }

  Widget _row(String icon, String label, Widget child, {VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
              color: inkRaised,
              border: Border.all(color: inkLine),
              borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Ico(icon, color: volt, size: 26),
            const SizedBox(width: 16),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: lStyle()),
              const SizedBox(height: 6),
              child,
            ])),
            if (onTap != null) const Ico('next', color: mist, size: 20),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return BrandPage(title: 'New career', body: Center(child: Text('$_err', style: bStyle())));
    }
    if (_db == null) {
      return const BrandPage(
          title: 'New career', body: Center(child: CircularProgressIndicator(color: volt)));
    }
    Widget val(String? v, String hint) => Text(v ?? hint,
        style: v == null ? bStyle(17, mist.withOpacity(0.6)) : bStyle(17));
    return BrandPage(
      title: 'New career',
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Set up your manager profile', style: bStyle(14, mist)),
        const SizedBox(height: 18),
        _row(
            'user',
            'Manager name',
            TextField(
              controller: _name,
              maxLength: 24,
              onChanged: (_) => setState(() {}),
              style: bStyle(17),
              cursorColor: volt,
              decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  border: InputBorder.none,
                  hintText: 'Enter your name',
                  hintStyle: bStyle(17, mist.withOpacity(0.6))),
            )),
        _row('flag', 'Nationality', val(_nat, 'Select nationality'), onTap: _pickNat),
        _row('shield', 'Club to manage', val(_club?.name, 'Select a club'), onTap: _pickClub),
      ]),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: _starting
            ? const SizedBox(height: 54, child: Center(child: CircularProgressIndicator(color: volt)))
            : BrandButton('Begin career', onTap: _ready ? _start : null),
      ),
    );
  }
}

class _NationSheet extends StatefulWidget {
  const _NationSheet();
  @override
  State<_NationSheet> createState() => _NationSheetState();
}

class _NationSheetState extends State<_NationSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = [for (final n in _nations) if (n.toLowerCase().contains(_q.toLowerCase())) n];
    return Theme(
      data: brandTheme(Brightness.dark),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(children: [
              Expanded(child: Text('NATIONALITY', style: hStyle(18, volt))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Ico('close')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: bStyle(),
              cursorColor: volt,
              decoration: InputDecoration(
                  prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Ico('search', size: 20, color: mist)),
                  hintText: 'Search',
                  hintStyle: bStyle(15, mist),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: inkLine)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: volt))),
            ),
          ),
          Expanded(
            child: ListView(children: [
              for (final n in l)
                ListTile(
                    title: Text(n, style: bStyle(16)), onTap: () => Navigator.pop(context, n)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TeamRow {
  final Club club;
  final League league;
  final int value;
  _TeamRow(this.club, this.league, this.value);
}

class TeamPicker extends StatefulWidget {
  final AppDatabase db;
  const TeamPicker(this.db, {super.key});
  @override
  State<TeamPicker> createState() => _TeamPickerState();
}

class _TeamPickerState extends State<TeamPicker> {
  late final Future<(List<League>, List<_TeamRow>)> _f = _load();
  String? _country;
  int _tier = 1;

  Future<(List<League>, List<_TeamRow>)> _load() async {
    final db = widget.db;
    final leagues = await db.select(db.leagues).get();
    final clubs = await db.select(db.clubs).get();
    final vals = await db
        .customSelect('SELECT club_id AS c, SUM(value) AS v FROM players GROUP BY club_id')
        .get();
    final vm = {for (final r in vals) r.read<int>('c'): r.read<int>('v')};
    final lm = {for (final l in leagues) l.id: l};
    return (
      leagues,
      [for (final c in clubs) _TeamRow(c, lm[c.leagueId]!, vm[c.id] ?? 0)]
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _f,
        builder: (_, s) {
          if (s.hasError) {
            return BrandPage(title: 'Select club', body: Center(child: Text('${s.error}', style: bStyle())));
          }
          if (!s.hasData) {
            return const BrandPage(
                title: 'Select club', body: Center(child: CircularProgressIndicator(color: volt)));
          }
          final (leagues, rows) = s.data!;
          final withClubs = {for (final r in rows) r.league.id};
          final countries = <String, int>{};
          for (final l in leagues) {
            if (!withClubs.contains(l.id)) continue;
            if (l.tier == 1 || !countries.containsKey(l.country)) {
              countries[l.country] = l.tier == 1 ? l.strength : countries[l.country] ?? 0;
            }
          }
          final names = countries.keys.toList()
            ..sort((a, b) => countries[b]!.compareTo(countries[a]!));
          final country = _country ?? names.first;
          final tiers = [
            for (final l in leagues)
              if (l.country == country && withClubs.contains(l.id)) l
          ]..sort((a, b) => a.tier.compareTo(b.tier));
          final tier = tiers.any((l) => l.tier == _tier) ? _tier : tiers.first.tier;
          final league = tiers.firstWhere((l) => l.tier == tier);
          final list = [for (final r in rows) if (r.league.id == league.id) r]
            ..sort((a, b) => b.club.reputation.compareTo(a.club.reputation));
          return BrandPage(
            title: 'Select club',
            body: Column(children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    for (final n in names)
                      GestureDetector(
                        onTap: () => setState(() => _country = n),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: n == country ? volt : Colors.transparent,
                              border: Border.all(color: n == country ? volt : inkLine),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(n.toUpperCase(),
                              style: lStyle(n == country ? ink : mist)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(children: [
                  for (final l in tiers)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tier = l.tier),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: l.tier == tier ? volt : inkLine,
                                      width: l.tier == tier ? 3 : 1))),
                          child: Column(children: [
                            Text('TIER ${l.tier}', style: lStyle(l.tier == tier ? volt : mist)),
                            const SizedBox(height: 2),
                            Text(l.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bStyle(12, l.tier == tier ? bone : mist)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _card(list[i]),
                ),
              ),
            ]),
          );
        },
      );

  Widget _card(_TeamRow r) {
    Widget stat(String k, Widget v) => Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.toUpperCase(), style: lStyle()),
          const SizedBox(height: 5),
          v,
        ]));
    Text t(String s) => Text(s, style: hStyle(16).copyWith(letterSpacing: 0.8));
    return GestureDetector(
      onTap: () => Navigator.pop(context, r.club),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: inkRaised,
            border: Border.all(color: inkLine),
            borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.club.name, style: hStyle(20))),
            const Ico('next', color: volt, size: 20),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            stat('Squad value', t(fmtMoney(r.value))),
            stat('Budget', t(fmtMoney(r.club.budget))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            stat('Stadium', Pips(r.club.stadiumLevel)),
            stat('Training', Pips(r.club.trainingLevel)),
          ]),
        ]),
      ),
    );
  }
}
