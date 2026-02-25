import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/emulator_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const NesEmulatorApp());
}

class NesEmulatorApp extends StatelessWidget {
  const NesEmulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NES Emulator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
      routes: {
        '/emulator': (context) => const EmulatorScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}