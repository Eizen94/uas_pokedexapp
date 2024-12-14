// lib/main.dart

/// Entry point and initialization for Pokedex application.
/// Handles app configuration, Firebase setup, and initial routing.
library;

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_config.dart';
import 'core/config/theme_config.dart';
import 'core/utils/connectivity_manager.dart';
import 'core/utils/monitoring_manager.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/services/auth_service.dart';
import 'features/pokemon/services/pokemon_service.dart';
import 'features/favorites/services/favorite_service.dart';

/// Global navigator key for app-wide navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
 runZonedGuarded(() async {
   WidgetsFlutterBinding.ensureInitialized();

   // Configure system UI
   await SystemChrome.setPreferredOrientations([
     DeviceOrientation.portraitUp,
     DeviceOrientation.portraitDown,
   ]);

   SystemChrome.setSystemUIOverlayStyle(
     const SystemUiOverlayStyle(
       statusBarColor: Colors.transparent,
       statusBarIconBrightness: Brightness.dark,
       systemNavigationBarColor: Colors.white,
       systemNavigationBarIconBrightness: Brightness.dark,
     ),
   );

   // Initialize Firebase
   await Firebase.initializeApp();
   await FirebaseConfig().initialize();
   
   // Initialize services
   final authService = await _initializeAuthService();
   final pokemonService = await _initializePokedexServices();
   final favoriteService = await _initializeFavoriteService();
   final connectivityManager = ConnectivityManager();
   final monitoringManager = MonitoringManager();

   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

   runApp(
     MultiProvider(
       providers: [
         Provider<AuthService>.value(value: authService),
         Provider<PokemonService>.value(value: pokemonService),
         Provider<FavoriteService>.value(value: favoriteService),
         Provider<ConnectivityManager>.value(value: connectivityManager),
         Provider<MonitoringManager>.value(value: monitoringManager),
       ],
       child: AuthStateWrapper(
         child: PokedexApp(
           navigatorKey: navigatorKey,
         ),
       ),
     ),
   );
 }, (error, stack) {
   FirebaseCrashlytics.instance.recordError(error, stack);
 });
}

/// Initialize auth service with proper error handling
Future<AuthService> _initializeAuthService() async {
 try {
   final service = AuthService();
   await service.initialize();
   return service;
 } catch (e) {
   FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
   rethrow;
 }
}

/// Initialize pokemon service with error handling
Future<PokemonService> _initializePokedexServices() async {
 try {
   return await PokemonService.initialize();
 } catch (e) {
   FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
   rethrow;
 }
}

/// Initialize favorites service with error handling
Future<FavoriteService> _initializeFavoriteService() async {
 try {
   return await FavoriteService.initialize();
 } catch (e) {
   FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
   rethrow;
 }
}

/// Root application widget
class PokedexApp extends StatelessWidget {
 /// Global navigator key
 final GlobalKey<NavigatorState> navigatorKey;

 /// Constructor
 const PokedexApp({
   required this.navigatorKey,
   super.key,
 });

 @override
 Widget build(BuildContext context) {
   return MaterialApp(
     title: 'Pokédex',
     debugShowCheckedModeBanner: false,
     navigatorKey: navigatorKey,
     theme: ThemeConfig.lightTheme,
     builder: (context, child) => MediaQuery(
       data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
       child: child!,
     ),
     home: const AuthStateWrapper(
       child: PokedexHomePage(),
     ),
   );
 }
}