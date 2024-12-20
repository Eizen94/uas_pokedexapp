import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/config/firebase_config.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/services/auth_service.dart';
import 'features/pokemon/services/pokemon_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService(firebaseConfig: FirebaseConfig())),
        Provider<PokemonService>(create: (_) => PokemonService()),
      ],
      child: const PokemonApp(),
    );
  }
}
