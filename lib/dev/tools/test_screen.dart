// lib/dev/tools/test_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../features/pokemon/services/pokemon_service.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/error_dialog.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final Map<String, TestStatus> _testResults = {};
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final PokemonService _pokemonService = PokemonService();
  final ApiHelper _apiHelper = ApiHelper();
  bool _isTestingAll = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await Future.wait([
        _connectivityManager.initialize(),
        _pokemonService.initialize(),
        _apiHelper.initialize(),
      ]);
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize services: $e');
      }
    } finally {
      _initializeTests();
    }
  }

  void _initializeTests() {
    _testResults.addAll({
      'connectivity': TestStatus.waiting,
      'firebase': TestStatus.waiting,
      'auth': TestStatus.waiting,
      'firestore': TestStatus.waiting,
      'api': TestStatus.waiting,
      'cache': TestStatus.waiting,
    });
    setState(() {});
  }

  Future<void> _runAllTests() async {
    if (_isTestingAll || !_isInitialized) return;

    setState(() {
      _isTestingAll = true;
      _testResults.updateAll((key, value) => TestStatus.running);
    });

    try {
      await Future.wait([
        _testConnectivity(),
        _testFirebase(),
        _testAuth(),
        _testFirestore(),
        _testApi(),
        _testCache(),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Test suite error: $e');
      }
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Test Error',
          message: 'Error running tests: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingAll = false);
      }
    }
  }

  Future<void> _testConnectivity() async {
    setState(() => _testResults['connectivity'] = TestStatus.running);

    try {
      final isOnline = await _connectivityManager.checkConnectivity();
      final networkState = _connectivityManager.currentState;

      if (isOnline) {
        setState(() => _testResults['connectivity'] = TestStatus.success);
        if (kDebugMode) {
          print(
              '✅ Connectivity test passed. Network state: ${networkState.name}');
        }
      } else {
        throw Exception('No network connectivity');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connectivity test failed: $e');
      }
      setState(() => _testResults['connectivity'] = TestStatus.failed);
      rethrow;
    }
  }

  Future<void> _testFirebase() async {
    setState(() => _testResults['firebase'] = TestStatus.running);

    try {
      final app = FirebaseAuth.instance.app;
      if (app.name.isNotEmpty) {
        setState(() => _testResults['firebase'] = TestStatus.success);
        if (kDebugMode) {
          print('✅ Firebase test passed. App name: ${app.name}');
        }
      } else {
        throw Exception('Firebase not initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase test failed: $e');
      }
      setState(() => _testResults['firebase'] = TestStatus.failed);
      rethrow;
    }
  }

  Future<void> _testAuth() async {
    setState(() => _testResults['auth'] = TestStatus.running);

    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      setState(() => _testResults['auth'] = TestStatus.success);
      if (kDebugMode) {
        print(
            '✅ Auth test passed. User: ${currentUser?.email ?? 'Not logged in'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auth test failed: $e');
      }
      setState(() => _testResults['auth'] = TestStatus.failed);
      rethrow;
    }
  }

  Future<void> _testFirestore() async {
    setState(() => _testResults['firestore'] = TestStatus.running);

    try {
      final testDoc =
          await FirebaseFirestore.instance.collection('test').doc('test').get();

      setState(() => _testResults['firestore'] = TestStatus.success);
      if (kDebugMode) {
        print(
            '✅ Firestore test passed. Test document exists: ${testDoc.exists}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firestore test failed: $e');
      }
      setState(() => _testResults['firestore'] = TestStatus.failed);
      rethrow;
    }
  }

  Future<void> _testApi() async {
    setState(() => _testResults['api'] = TestStatus.running);

    try {
      final pokemon = await _pokemonService.getPokemonDetail('1');

      if (pokemon.name.isNotEmpty) {
        setState(() => _testResults['api'] = TestStatus.success);
        if (kDebugMode) {
          print('✅ API test passed. Pokemon: ${pokemon.name}');
        }
      } else {
        throw Exception('Invalid Pokemon data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ API test failed: $e');
      }
      setState(() => _testResults['api'] = TestStatus.failed);
      rethrow;
    }
  }

  Future<void> _testCache() async {
    setState(() => _testResults['cache'] = TestStatus.running);

    try {
      const testKey = 'test_cache_key';
      await _apiHelper.clearCache(testKey);

      final testData = {
        'test': 'data',
        'timestamp': DateTime.now().toIso8601String()
      };

      // Test writing to cache
      await _apiHelper.get<Map<String, dynamic>>(
        endpoint: 'test',
        parser: (data) => testData,
        useCache: true,
      );

      // Verify cache
      final cachedResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: 'test',
        parser: (data) => data,
        useCache: true,
      );

      if (cachedResponse.isCached) {
        setState(() => _testResults['cache'] = TestStatus.success);
        if (kDebugMode) {
          print('✅ Cache test passed');
        }
      } else {
        throw Exception('Cache verification failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache test failed: $e');
      }
      setState(() => _testResults['cache'] = TestStatus.failed);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Tests'),
        actions: [
          if (_isTestingAll)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: LoadingIndicator(size: 20),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isInitialized ? _runAllTests : null,
              tooltip: 'Run all tests',
            ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child: LoadingIndicator(
                message: 'Initializing services...',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTestCard(
                  'Network Connectivity',
                  'Test network connection & state',
                  _testResults['connectivity']!,
                  _testConnectivity,
                ),
                const SizedBox(height: 16),
                _buildTestCard(
                  'Firebase Core',
                  'Test Firebase initialization',
                  _testResults['firebase']!,
                  _testFirebase,
                ),
                const SizedBox(height: 16),
                _buildTestCard(
                  'Authentication',
                  'Test Firebase Auth service',
                  _testResults['auth']!,
                  _testAuth,
                ),
                const SizedBox(height: 16),
                _buildTestCard(
                  'Cloud Firestore',
                  'Test Firestore connection',
                  _testResults['firestore']!,
                  _testFirestore,
                ),
                const SizedBox(height: 16),
                _buildTestCard(
                  'PokeAPI',
                  'Test API connection & response',
                  _testResults['api']!,
                  _testApi,
                ),
                const SizedBox(height: 16),
                _buildTestCard(
                  'Cache System',
                  'Test cache write & read',
                  _testResults['cache']!,
                  _testCache,
                ),
              ],
            ),
    );
  }

  Widget _buildTestCard(
    String title,
    String description,
    TestStatus status,
    Future<void> Function() onTest,
  ) {
    return Card(
      child: ListTile(
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 8),
            _buildStatusChip(status),
          ],
        ),
        trailing: status != TestStatus.running
            ? IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: !_isTestingAll && _isInitialized ? onTest : null,
                tooltip: 'Run test',
              )
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }

  Widget _buildStatusChip(TestStatus status) {
    final (color, text) = switch (status) {
      TestStatus.waiting => (Colors.grey, 'Waiting'),
      TestStatus.running => (Colors.blue, 'Running'),
      TestStatus.success => (AppColors.success, 'Success'),
      TestStatus.failed => (AppColors.error, 'Failed'),
    };

    return Chip(
      label: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

enum TestStatus {
  waiting,
  running,
  success,
  failed,
}
