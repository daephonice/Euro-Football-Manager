import 'package:flutter/material.dart';
import 'db/database.dart';
import 'db/seed.dart';
import 'hub.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await seedIfEmpty(db);
  runApp(App(db));
}

class App extends StatelessWidget {
  final AppDatabase db;
  const App(this.db, {super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Euro Manager',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.green,
            brightness: Brightness.dark,
            useMaterial3: true),
        themeMode: ThemeMode.system,
        home: HubScreen(db),
      );
}
