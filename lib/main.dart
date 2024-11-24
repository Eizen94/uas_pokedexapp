import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initializeFirebase();
  runApp(const MyApp());
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

class YourInitialScreen extends StatelessWidget {
  const YourInitialScreen({super.key});

  Future<void> _testFirebase() async {
    try {
      // Test Auth
      final auth = FirebaseAuth.instance;
      print('Current user: ${auth.currentUser}');

      // Test Firestore
      final testDoc =
          await FirebaseFirestore.instance.collection('test').doc('test').get();
      print('Firestore test: ${testDoc.exists ? 'Connected' : 'No document'}');
    } catch (e) {
      print('Test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _testFirebase,
              child: const Text('Test Firebase Connection'),
            ),
            const SizedBox(height: 20),
            const Text('Check console for results'),
          ],
        ),
      ),
    );
  }
}
