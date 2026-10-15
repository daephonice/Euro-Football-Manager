import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'brand.dart';
import 'db/database.dart';
import 'new_game.dart';
import 'shell.dart';
import 'slots.dart';

const kVersion = '1.0.0';

const _policy = [
  ('Overview',
      'Euro Football Manager is an offline game. It runs entirely on your device and does not require an account.'),
  ('Data we collect',
      'None. The app does not collect, transmit, sell or share personal information, analytics or advertising identifiers.'),
  ('Data stored on your device',
      'Your manager name, nationality and career progress are saved locally in up to five save slots. Deleting a save, clearing app data or uninstalling the app permanently removes them.'),
  ('Network access',
      'The game does not connect to the internet for gameplay.'),
  ('Children',
      'The app does not knowingly collect any information from anyone, including children.'),
  ('Changes',
      'If this policy changes, the updated version will be shown here inside the app.'),
];

void showPolicy(BuildContext context) => showDialog(
      context: context,
      builder: (_) => Theme(
        data: brandTheme(Brightness.dark),
        child: Dialog(
          backgroundColor: inkRaised,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: inkLine),
              borderRadius: BorderRadius.circular(6)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                child: Row(children: [
                  Expanded(child: Text('PRIVACY POLICY', style: hStyle(18, volt))),
                  Builder(
                      builder: (c) => IconButton(
                          onPressed: () => Navigator.pop(c), icon: const Ico('close'))),
                ]),
              ),
              Container(height: 1, color: inkLine),
              Flexible(
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  for (final (h, t) in _policy) ...[
                    Text(h.toUpperCase(), style: lStyle(volt)),
                    const SizedBox(height: 6),
                    Text(t, style: bStyle(14, bone.withOpacity(0.85))),
                    const SizedBox(height: 18),
                  ],
                  Text('Last updated: 2026', style: lStyle()),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuState();
}

class _MenuState extends State<MenuScreen> {
  Future<void> _new() async {
    final slot = Slots.freeSlot();
    if (slot == null) {
      await showDialog(
          context: context,
          builder: (c) => Theme(
                data: brandTheme(Brightness.dark),
                child: AlertDialog(
                  backgroundColor: inkRaised,
                  title: Text('SAVES FULL', style: hStyle(18, volt)),
                  content: Text(
                      'All ${Slots.max} save slots are in use. Delete a save to start a new career.',
                      style: bStyle()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c), child: const Text('Close')),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(c);
                          _load();
                        },
                        child: const Text('Open saves')),
                  ],
                ),
              ));
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ProfileScreen(slot)));
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoadScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: brandTheme(Brightness.dark),
        child: Scaffold(
          backgroundColor: ink,
          body: BrandBg(
            pitch: true,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(children: [
                  const Spacer(flex: 2),
                  SvgPicture.string(svgs['emblem']!,
                      width: 84,
                      height: 84,
                      colorFilter: const ColorFilter.mode(volt, BlendMode.srcIn)),
                  const SizedBox(height: 22),
                  Text('EURO', style: hStyle(64, volt).copyWith(letterSpacing: 14, height: 1)),
                  const SizedBox(height: 4),
                  Text('FOOTBALL MANAGER',
                      style: hStyle(22).copyWith(letterSpacing: 6)),
                  const Spacer(flex: 3),
                  BrandButton('New game', onTap: _new),
                  const SizedBox(height: 16),
                  BrandButton('Load game', filled: false, onTap: _load),
                  const Spacer(flex: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('VERSION $kVersion', style: lStyle()),
                    GestureDetector(
                      onTap: () => showPolicy(context),
                      child: Row(children: [
                        const Ico('doc', size: 16, color: mist),
                        const SizedBox(width: 6),
                        Text('PRIVACY POLICY',
                            style: lStyle().copyWith(decoration: TextDecoration.underline)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ),
        ),
      );
}

class LoadScreen extends StatefulWidget {
  const LoadScreen({super.key});
  @override
  State<LoadScreen> createState() => _LoadState();
}

class _LoadState extends State<LoadScreen> {
  bool _busy = false;

  Future<void> _open(int slot) async {
    setState(() => _busy = true);
    try {
      final db = await Slots.open(slot);
      if (!mounted) {
        await db.close();
        return;
      }
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => GameHost(db, slot)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete(SlotMeta m) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => Theme(
              data: brandTheme(Brightness.dark),
              child: AlertDialog(
                backgroundColor: inkRaised,
                title: Text('DELETE SAVE', style: hStyle(18, alert)),
                content: Text(
                    '${m.manager} at ${m.club} will be permanently deleted.',
                    style: bStyle()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete', style: TextStyle(color: alert))),
                ],
              ),
            ));
    if (ok != true) return;
    setState(() => _busy = true);
    await Slots.delete(m.slot);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = Slots.used();
    return BrandPage(
      title: 'Saved careers',
      body: Stack(children: [
        list.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Ico('shield', size: 48, color: inkLine),
                  const SizedBox(height: 14),
                  Text('NO SAVED CAREERS', style: lStyle()),
                ]),
              )
            : ListView(padding: const EdgeInsets.all(20), children: [
                Text('${list.length} OF ${Slots.max} SLOTS USED', style: lStyle()),
                const SizedBox(height: 14),
                for (final m in list) _card(m),
              ]),
        if (_busy)
          Positioned.fill(
              child: Container(
                  color: ink.withOpacity(0.6),
                  child: const Center(child: CircularProgressIndicator(color: volt)))),
      ]),
    );
  }

  Widget _card(SlotMeta m) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: inkRaised,
            border: Border.all(color: inkLine),
            borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('SLOT ${m.slot}', style: lStyle(volt)),
            const Spacer(),
            Text('SEASON ${m.season}  /  WEEK ${m.week}', style: lStyle()),
          ]),
          const SizedBox(height: 10),
          Text(m.club, style: hStyle(22)),
          const SizedBox(height: 4),
          Text('${m.manager}  ·  ${m.nationality}', style: bStyle(14, mist)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _mini('Load', 'play', volt, () => _open(m.slot))),
            const SizedBox(width: 12),
            _mini('', 'trash', alert, () => _delete(m), square: true),
          ]),
        ]),
      );

  Widget _mini(String label, String icon, Color c, VoidCallback t, {bool square = false}) =>
      GestureDetector(
        onTap: _busy ? null : t,
        child: Container(
          height: 44,
          width: square ? 52 : null,
          decoration: BoxDecoration(
              border: Border.all(color: c, width: 1.4), borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Ico(icon, size: 18, color: c),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(label.toUpperCase(), style: hStyle(14, c).copyWith(letterSpacing: 2.5)),
            ],
          ]),
        ),
      );
}

/// Holds a slot database open while the game is on screen.
class GameHost extends StatefulWidget {
  final AppDatabase db;
  final int slot;
  const GameHost(this.db, this.slot, {super.key});
  @override
  State<GameHost> createState() => _GameHostState();
}

class _GameHostState extends State<GameHost> {
  @override
  void initState() {
    super.initState();
    Slots.active = widget.slot;
  }

  @override
  void dispose() {
    Slots.active = null;
    widget.db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shell(widget.db);
}
