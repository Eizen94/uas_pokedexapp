import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';
import 'package:uas_pokedexapp/features/auth/screens/login_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/register_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/profile_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_list_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_detail_screen.dart';

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const PokemonListScreen(),
        '/pokemon/detail': (context) => const PokemonDetailScreen(),
      },
    );
  }
}
