// =============================================================================
// GBAKAMAP - Application de transport public Côte d'Ivoire
// Architecture: Provider + Repository Pattern
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
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