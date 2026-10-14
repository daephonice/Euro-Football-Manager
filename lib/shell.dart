import 'package:flutter/material.dart';
import 'db/database.dart';
import 'hub.dart';
import 'squad.dart';
import 'tactics.dart';

class Shell extends StatefulWidget {
  final AppDatabase db;
  const Shell(this.db, {super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: switch (_i) {
          0 => HubScreen(widget.db, key: const ValueKey('hub')),
          1 => SquadScreen(widget.db, key: const ValueKey('squad')),
          _ => TacticsScreen(widget.db, key: const ValueKey('tactics')),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (i) => setState(() => _i = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Hub'),
            NavigationDestination(icon: Icon(Icons.groups), label: 'Squad'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Tactics'),
          ],
        ),
      );
}
