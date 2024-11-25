import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Tambahkan ini
import 'package:uas_pokedexapp/core/config/firebase_config.dart';
import 'package:uas_pokedexapp/features/test/screens/test_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (kDebugMode) {
      print('🚀 Starting app initialization...');
    }

    await FirebaseConfig.initializeFirebase();

    if (kDebugMode) {
      print('✅ App initialization complete');
    }

    runApp(const MyApp());
  } catch (e) {
    if (kDebugMode) {
      print('❌ Fatal error in main: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UAS Pokedex',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const YourInitialScreen(),
    );
  }
}
