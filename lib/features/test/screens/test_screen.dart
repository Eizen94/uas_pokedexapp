// lib/features/test/screens/test_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class YourInitialScreen extends StatefulWidget {
  const YourInitialScreen({super.key});

  @override
  State<YourInitialScreen> createState() => _YourInitialScreenState();
}

class _YourInitialScreenState extends State<YourInitialScreen> {
  String _status = 'Ready to test';

  Future<void> _testFirebase() async {
    try {
      setState(() {
        _status = 'Testing connection...';
      });

      // Test Auth
      final auth = FirebaseAuth.instance;
      if (kDebugMode) {
        print('Testing Auth...');
      }

      // Test Firestore
      final testDoc =
          await FirebaseFirestore.instance.collection('test').doc('test').get();

      setState(() {
        _status =
            'Connection successful!\nFirestore document exists: ${testDoc.exists}';
      });
    } catch (e) {
      if (kDebugMode) {
        print('Test failed: $e');
      }
      setState(() {
        _status = 'Test failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _testFirebase,
                child: const Text('Test Firebase Connection'),
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
