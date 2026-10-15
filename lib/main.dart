import 'package:flutter/material.dart';
import 'brand.dart';
import 'menu.dart';
import 'slots.dart';
import 'util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Slots.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
            title: 'Euro Football Manager',
            debugShowCheckedModeBanner: false,
            theme: brandTheme(Brightness.light),
            darkTheme: brandTheme(Brightness.dark),
            themeMode: mode,
            home: const MenuScreen(),
          ));
}
