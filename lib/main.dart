// =============================================================================
// GBAKAMAP - Application de transport public Côte d'Ivoire
// Architecture: Provider + Repository Pattern
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme/app_theme.dart';
import 'core/services/overpass_service.dart';
import 'core/services/weather_service.dart';
import 'core/services/location_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/route_service.dart';
import 'features/providers/map_provider.dart';
import 'features/providers/transport_provider.dart';
import 'features/providers/route_provider.dart';
import 'features/providers/weather_provider.dart';
import 'features/map/screens/map_screen.dart';
import 'features/map/screens/route_search_screen.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialisation Hive (cache local)
  await Hive.initFlutter();
  await CacheService.init();

  // Permissions
  await _requestPermissions();

  runApp(const GbakaMapApp());
}

/// Demande des permissions nécessaires
Future<void> _requestPermissions() async {
  await [
    Permission.location,
    Permission.locationWhenInUse,
    Permission.storage,
  ].request();
}

class GbakaMapApp extends StatelessWidget {
  const GbakaMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services singletons
        Provider<OverpassService>(
          create: (_) => OverpassService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<WeatherService>(
          create: (_) => WeatherService(),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),
        Provider<CacheService>(
          create: (_) => CacheService(),
        ),
        Provider<RouteService>(
          create: (_) => RouteService(),
          dispose: (_, service) => service.dispose(),
        ),

        // Providers d'état
        ChangeNotifierProxyProvider<OverpassService, TransportProvider>(
          create: (context) => TransportProvider(
            overpassService: context.read<OverpassService>(),
            cacheService: context.read<CacheService>(),
          ),
          update: (_, overpass, previous) => previous ?? TransportProvider(
            overpassService: overpass,
            cacheService: context.read<CacheService>(),
          ),
        ),

        ChangeNotifierProxyProvider2<LocationService, TransportProvider, MapProvider>(
          create: (context) => MapProvider(
            locationService: context.read<LocationService>(),
            transportProvider: context.read<TransportProvider>(),
          ),
          update: (_, location, transport, previous) => previous ?? MapProvider(
            locationService: location,
            transportProvider: transport,
          ),
        ),

        ChangeNotifierProxyProvider<WeatherService, WeatherProvider>(
          create: (context) => WeatherProvider(
            weatherService: context.read<WeatherService>(),
          ),
          update: (_, weather, previous) => previous ?? WeatherProvider(
            weatherService: weather,
          ),
        ),

        ChangeNotifierProxyProvider<RouteService, RouteProvider>(
          create: (context) => RouteProvider(
            routeService: context.read<RouteService>(),
          ),
          update: (_, route, previous) => previous ?? RouteProvider(
            routeService: route,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'GbakaMap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        home: const SplashScreenWrapper(),
        // Configuration des routes
        routes: {
          '/map': (context) => const MainMapScreen(),
          '/route_search': (context) => const RouteSearchScreen(),
          '/favorites': (context) => const FavoritesScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}

/// Wrapper pour le splash screen avec initialisation
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialiser le service de localisation
      final locationService = context.read<LocationService>();
      await locationService.initialize();

      // Attendre 3 secondes minimum pour le splash
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      // Navigation vers l'écran principal
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainMapScreen(),
        ),
      );
    } catch (e) {
      // En cas d'erreur, continuer quand même
      if (!mounted) return;

      await Future.delayed(const Duration(seconds: 2));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainMapScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

// =============================================================================
// ÉCRANS TEMPORAIRES (À IMPLÉMENTER)
// =============================================================================

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoris'),
      ),
      body: Consumer<CacheService>(
        builder: (context, cacheService, child) {
          final favorites = cacheService.getFavorites();
          
          if (favorites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun favori enregistré',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final entry = favorites.entries.elementAt(index);
              final stopData = entry.value as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.red),
                  title: Text(stopData['name'] ?? 'Arrêt sans nom'),
                  subtitle: Text(stopData['type'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await cacheService.removeFavorite(entry.key);
                    },
                  ),
                  onTap: () {
                    // TODO: Centrer la carte sur cet arrêt
                    Navigator.pop(context);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('À propos'),
            subtitle: Text('GbakaMap v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Vider le cache'),
            subtitle: const Text('Libérer de l\'espace'),
            onTap: () async {
              final cacheService = context.read<CacheService>();
              await cacheService.clearAllCaches();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache vidé avec succès')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Effacer l\'historique'),
            onTap: () async {
              final cacheService = context.read<CacheService>();
              await cacheService.clearHistory();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historique effacé')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Rayon de recherche'),
            subtitle: Consumer<TransportProvider>(
              builder: (context, provider, child) {
                return Slider(
                  value: provider.searchRadius,
                  min: 500,
                  max: 5000,
                  divisions: 9,
                  label: '${provider.searchRadius.toInt()}m',
                  onChanged: (value) {
                    provider.setSearchRadius(value);
                  },
                );
              },
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.copyright),
            title: Text('Développé avec ❤️ pour la Côte d\'Ivoire'),
          ),
        ],
      ),
    );
  }
}