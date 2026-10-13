import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'db/seed.dart';
import 'hub.dart';
import 'new_career.dart';

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
        home: Root(db),
      );
}

class Root extends StatefulWidget {
  final AppDatabase db;
  const Root(this.db, {super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  late Future<CareerSave> _career = loadCareer(widget.db);

  @override
  Widget build(BuildContext context) => FutureBuilder<CareerSave>(
        future: _career,
        builder: (_, s) {
          if (s.hasError) return Scaffold(body: Center(child: Text('${s.error}')));
          if (!s.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return s.data!.clubId == null
              ? NewCareerScreen(widget.db,
                  onStarted: () => setState(() => _career = loadCareer(widget.db)))
              : HubScreen(widget.db);
        },
      );
}
