// =============================================================================
// MAP SCREEN - Écran principal avec carte interactive OSM
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/overpass_service.dart';
import '../../providers/map_provider.dart';
import '../../providers/transport_provider.dart';
import '../../providers/weather_provider.dart';
import '../../widgets/transport_marker.dart';
import '../../widgets/stop_details_sheet.dart';
import '../../widgets/weather_widget.dart';
import '../../widgets/transport_filter_chips.dart';
import '../../widgets/map_controls.dart';


class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> with TickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();

    // Animation des FABs
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );

    _fabAnimationController.forward();

    // Initialiser la carte
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    final mapProvider = context.read<MapProvider>();
    final weatherProvider = context.read<WeatherProvider>();

    await mapProvider.initialize();
    await weatherProvider.loadWeather(mapProvider.center);
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte OSM
          _buildMap(),

          // Header avec météo et filtres
          _buildHeader(),

          // Contrôles de la carte (zoom, etc.)
          _buildMapControls(),

          // Indicateur de chargement
          _buildLoadingIndicator(),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  /// Construit la carte OpenStreetMap
  Widget _buildMap() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        return Consumer<TransportProvider>(
          builder: (context, transportProvider, child) {
            return FlutterMap(
              mapController: mapProvider.mapController,
              options: MapOptions(
                initialCenter: mapProvider.center,
                initialZoom: mapProvider.zoom,
                minZoom: 3.0,
                maxZoom: 19.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && position.center != null && position.zoom != null) {
                    mapProvider.updatePosition(position.center!, position.zoom!);
                  }
                },
                onTap: (tapPosition, point) {
                  // Fermer les bottom sheets ouvertes
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              children: [
                // Tuiles OSM
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ci.gbakamap.app',
                  maxZoom: 19,
                  tileProvider: NetworkTileProvider(),
                ),

                // Marqueurs des arrêts
                MarkerLayer(
                  markers: _buildStopMarkers(
                    transportProvider.filteredStops,
                    transportProvider,
                  ),
                ),

                // Marqueur de position utilisateur
                if (mapProvider.isInitialized)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: mapProvider.center,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.3),
                            border: Border.all(
                              color: Colors.blue,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Construit les marqueurs des arrêts
  List<Marker> _buildStopMarkers(
      List<TransportStop> stops,
      TransportProvider transportProvider,
      ) {
    return stops.map((stop) {
      return Marker(
        point: stop.position,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showStopDetails(context, stop, transportProvider),
          child: TransportMarkerWidget(
            stop: stop,
            isFavorite: transportProvider.isFavorite(stop.id),
          ),
        ),
      );
    }).toList();
  }

  /// Affiche les détails d'un arrêt
  void _showStopDetails(
      BuildContext context,
      TransportStop stop,
      TransportProvider transportProvider,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StopDetailsSheet(
        stop: stop,
        onToggleFavorite: () {
          transportProvider.toggleFavorite(stop);
        },
        isFavorite: transportProvider.isFavorite(stop.id),
      ),
    );
  }

  /// Header avec météo et filtres
  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barre de titre avec météo
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      'GbakaMap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const WeatherWidget(),
                  ],
                ),
              ),

              // Filtres de transport
              const TransportFilterChips(),

              // Compteur d'arrêts
              Consumer<TransportProvider>(
                builder: (context, provider, child) {
                  if (provider.filteredStops.isEmpty) return const SizedBox();

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${provider.filteredStops.length} arrêt(s) trouvé(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contrôles de la carte
  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.4,
      child: MapControls(
        onZoomIn: () => context.read<MapProvider>().zoomIn(),
        onZoomOut: () => context.read<MapProvider>().zoomOut(),
        onRefresh: () async {
          await context.read<MapProvider>().refreshStops(forceRefresh: true);
        },
      ),
    );
  }

  /// Indicateur de chargement
  Widget _buildLoadingIndicator() {
    return Consumer<TransportProvider>(
      builder: (context, provider, child) {
        if (!provider.isLoading) return const SizedBox();

        return Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Chargement des arrêts...'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Boutons d'action flottants
  Widget _buildFloatingActions() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton localisation
            ScaleTransition(
              scale: _fabAnimation,
              child: FloatingActionButton(
                heroTag: 'location',
                onPressed: () async {
                  await mapProvider.centerOnCurrentLocation();
                },
                backgroundColor: mapProvider.followLocation
                    ? AppColors.primary
                    : Colors.white,
                child: Icon(
                  mapProvider.followLocation
                      ? Icons.my_location
                      : Icons.location_searching,
                  color: mapProvider.followLocation
                      ? Colors.white
                      : AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Bouton suivi de position
            ScaleTransition(
              scale: _fabAnimation,
              child: FloatingActionButton.small(
                heroTag: 'follow',
                onPressed: () {
                  mapProvider.toggleFollowLocation();
                },
                backgroundColor: Colors.white,
                child: Icon(
                  mapProvider.followLocation
                      ? Icons.gps_fixed
                      : Icons.gps_not_fixed,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Barre de navigation inférieure
  Widget _buildBottomBar(BuildContext context) {
    return Consumer<TransportProvider>(
      builder: (context, provider, child) {
        return BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            switch (index) {
              case 0:
                // Already on map screen
                break;
              case 1:
                // Navigate to route search
                Navigator.pushNamed(context, '/route_search');
                break;
              case 2:
                // Navigate to favorites
                Navigator.pushNamed(context, '/favorites');
                break;
              case 3:
                // Navigate to settings
                Navigator.pushNamed(context, '/settings');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Carte',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions),
              label: 'Itinéraire',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favoris',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Paramètres',
            ),
          ],
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
        );
      },
    );
  }
}