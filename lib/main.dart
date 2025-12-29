// =============================================================================
// GBAKAMAP - Application de transport public Côte d'Ivoire
// Version optimisée pour éviter les blocages
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
import 'core/config/env_config.dart';
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

  // Initialisation variables d'environnement
  Logger.info('Démarrage application GbakaMap', 'Main');
  await EnvConfig.init();
  Logger.info('Configuration environnement chargée', 'Main');
  Logger.debug('Mode debug: ${EnvConfig.debugMode}', 'Main');
  Logger.debug('API timeout: ${EnvConfig.apiTimeoutSeconds}s', 'Main');

  // Initialisation Hive (cache local) - RAPIDE
  await Hive.initFlutter();
  await CacheService.init();
  Logger.info('Services initialisés avec succès', 'Main');

  runApp(const GbakaMapApp());
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

/// Wrapper optimisé pour le splash screen
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _isInitializing = true;
  String _statusMessage = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Attendre que le premier frame soit affiché
      await Future.delayed(const Duration(milliseconds: 100));

      // Demander les permissions en arrière-plan
      _requestPermissionsAsync();

      // Initialiser le service de localisation (non bloquant)
      if (mounted) {
        setState(() => _statusMessage = 'Configuration de la localisation...');
      }
      
      final locationService = context.read<LocationService>();
      
      // Initialiser sans attendre une position précise
      locationService.initialize().catchError((error) {
        debugPrint('Erreur localisation: $error');
        // Continuer même en cas d'erreur
      });

      // Attendre un minimum de 2 secondes pour l'UX
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Navigation vers l'écran principal
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainMapScreen(),
        ),
      );
    } catch (e) {
      debugPrint('Erreur initialisation: $e');
      
      if (!mounted) return;

      // En cas d'erreur, continuer quand même après 2 secondes
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainMapScreen(),
        ),
      );
    }
  }

  /// Demande des permissions de manière asynchrone
  void _requestPermissionsAsync() {
    [
      Permission.location,
      Permission.locationWhenInUse,
    ].request().then((status) {
      debugPrint('Permissions accordées: $status');
    }).catchError((error) {
      debugPrint('Erreur permissions: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(statusMessage: _statusMessage);
  }
}

// =============================================================================
// ÉCRANS TEMPORAIRES (optimisés)
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
                  SizedBox(height: 8),
                  Text(
                    'Appuyez sur ⭐ sur un arrêt pour l\'ajouter',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fonctionnalité à venir: centrer sur l\'arrêt'),
                        duration: Duration(seconds: 2),
                      ),
                    );
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
          // Informations
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('À propos'),
            subtitle: Text('GbakaMap v1.0.0'),
          ),
          const Divider(),

          // Cache
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Gestion du cache'),
            subtitle: FutureBuilder<Map<String, int>>(
              future: context.read<CacheService>().getCacheSizes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Calcul...');
                final sizes = snapshot.data!;
                final total = sizes.values.fold(0, (a, b) => a + b);
                return Text('$total éléments en cache');
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Vider le cache'),
            subtitle: const Text('Libérer de l\'espace'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Vider le cache ?'),
                  content: const Text(
                    'Cette action supprimera toutes les données en cache. '
                    'Vos favoris seront conservés.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Vider'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                final cacheService = context.read<CacheService>();
                await cacheService.clearAllCaches();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache vidé avec succès')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Effacer l\'historique'),
            subtitle: const Text('Supprimer l\'historique de recherche'),
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

          // Paramètres de carte
          const ListTile(
            leading: Icon(Icons.map),
            title: Text('Paramètres de carte'),
            subtitle: Text('Rayon de recherche'),
          ),
          Consumer<TransportProvider>(
            builder: (context, provider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rayon de recherche'),
                        Text(
                          '${provider.searchRadius.toInt()}m',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: provider.searchRadius,
                      min: 500,
                      max: 5000,
                      divisions: 9,
                      label: '${provider.searchRadius.toInt()}m',
                      onChanged: (value) {
                        provider.setSearchRadius(value);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          // Informations système
          const ListTile(
            leading: Icon(Icons.phone_android),
            title: Text('Système'),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Permissions de localisation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              openAppSettings();
            },
          ),

          const Divider(),

          // Crédits
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Version'),
            subtitle: Text('1.0.0 (Build 1)'),
          ),
          const ListTile(
            leading: Icon(Icons.favorite, color: Colors.red),
            title: Text('Développé avec ❤️ pour la Côte d\'Ivoire'),
          ),
          const ListTile(
            leading: Icon(Icons.map_outlined),
            title: Text('Données OpenStreetMap'),
            subtitle: Text('© OpenStreetMap contributors'),
          ),
        ],
      ),
    );
  }
}