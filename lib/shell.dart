import 'package:flutter/material.dart';
import 'db/database.dart';
import 'hub.dart';
import 'finances.dart';
import 'squad.dart';
import 'tactics.dart';
import 'training.dart';
import 'transfers.dart';

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
          2 => TacticsScreen(widget.db, key: const ValueKey('tactics')),
          3 => TransfersScreen(widget.db, key: const ValueKey('transfers')),
          4 => TrainingScreen(widget.db, key: const ValueKey('training')),
          _ => FinancesScreen(widget.db, key: const ValueKey('finances')),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: (i) => setState(() => _i = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Hub'),
            NavigationDestination(icon: Icon(Icons.groups), label: 'Squad'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Tactics'),
            NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Transfers'),
            NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Training'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Finances'),
          ],
        ),
      );
}
