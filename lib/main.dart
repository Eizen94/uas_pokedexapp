import 'package:flutter/material.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';

void main() async {
  // We need to ensure Flutter bindings are initialized before calling Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initializeFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UAS Pokedex',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // We'll create this screen next
      home: const YourInitialScreen(),
    );
  }
}

// Temporary placeholder screen - we'll replace this later
class YourInitialScreen extends StatelessWidget {
  const YourInitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UAS Pokedex'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Text('Welcome to UAS Pokedex!'),
      ),
    );
  }
}
