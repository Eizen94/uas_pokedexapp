import 'package:flutter/material.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';
import 'package:uas_pokedexapp/features/test/screens/test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseConfig.initializeFirebase();
    runApp(const MyApp());
  } catch (e) {
    print('Error in main: $e');
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
      home: const YourInitialScreen(), // Menggunakan screen dari file terpisah
    );
  }
}
