// =============================================================================
// ROUTE SEARCH SCREEN - Recherche et affichage d'itinéraires
// Fichier: lib/features/map/screens/route_search_screen.dart
// =============================================================================

import 'package:flutter/material.dart' hide Route;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/route_service.dart';
import '../../../features/providers/route_provider.dart';
import '../../../features/providers/weather_provider.dart';
import '../../../features/widgets/route_input.dart';
// import '../../../features/widgets/transport_suggestion.dart';
// import '../../../features/widgets/route_summary.dart';

class RouteSearchScreen extends StatefulWidget {
  final LatLng? initialFrom;
  final LatLng? initialTo;

  const RouteSearchScreen({
    super.key,
    this.initialFrom,
    this.initialTo,
  });

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialiser avec les coordonnées si fournies
    if (widget.initialFrom != null || widget.initialTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<RouteProvider>();
        if (widget.initialFrom != null) {
          provider.setFrom(widget.initialFrom!, address: 'Position actuelle');
        }
        if (widget.initialTo != null) {
          provider.setTo(widget.initialTo!);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche d\'itinéraire'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Carte'),
            Tab(icon: Icon(Icons.list), text: 'Instructions'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Formulaire de recherche
          _buildSearchForm(),
          
          // Contenu selon l'onglet
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMapView(),
                _buildInstructionsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Consumer<RouteProvider>(
      builder: (context, provider, child) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Point de départ
              RouteInputField(
                label: 'Départ',
                icon: Icons.trip_origin,
                iconColor: Colors.green,
                value: provider.fromAddress,
                onTap: () => _selectLocation(context, isFrom: true),
                onClear: provider.clearFrom,
              ),
              
              const SizedBox(height: 12),
              
              // Bouton inverser
              Center(
                child: IconButton(
                  onPressed: provider.from != null && provider.to != null
                      ? provider.swapLocations
                      : null,
                  icon: const Icon(Icons.swap_vert),
                  color: AppColors.primary,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Point d'arrivée
              RouteInputField(
                label: 'Arrivée',
                icon: Icons.location_on,
                iconColor: Colors.red,
                value: provider.toAddress,
                onTap: () => _selectLocation(context, isFrom: false),
                onClear: provider.clearTo,
              ),
              
              const SizedBox(height: 16),
              
              // Bouton rechercher
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: provider.canCalculateRoute && !provider.isLoading
                      ? () => _calculateRoute(context)
                      : null,
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: Text(
                    provider.isLoading
                        ? 'Calcul en cours...'
                        : 'Rechercher un itinéraire',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              
              // Message d'erreur
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    provider.error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    return Consumer<RouteProvider>(
      builder: (context, provider, child) {
        if (provider.currentRoute == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recherchez un itinéraire pour l\'afficher sur la carte',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            // Carte avec l'itinéraire
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: provider.currentRoute!.geometry.isNotEmpty
                    ? provider.currentRoute!.geometry.first
                    : const LatLng(5.3566, -4.0315),
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 19.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ci.gbakamap.app',
                  maxZoom: 19,
                ),
                
                // Tracé de l'itinéraire
                if (provider.currentRoute!.geometry.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: provider.currentRoute!.geometry,
                        strokeWidth: 5,
                        color: AppColors.primary,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                
                // Marqueurs départ/arrivée
                MarkerLayer(
                  markers: [
                    if (provider.from != null)
                      Marker(
                        point: provider.from!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.trip_origin,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    if (provider.to != null)
                      Marker(
                        point: provider.to!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            // Résumé de l'itinéraire
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RouteSummaryCard(
                route: provider.currentRoute!,
                onShowSuggestions: () => _showTransportSuggestions(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionsView() {
    return Consumer<RouteProvider>(
      builder: (context, provider, child) {
        if (provider.currentRoute == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.list_alt,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun itinéraire calculé',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final route = provider.currentRoute!;
        final steps = route.legs.expand((leg) => leg.steps).toList();

        if (steps.isEmpty) {
          return const Center(
            child: Text('Aucune instruction disponible'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: steps.length + 1, // +1 pour l'arrivée
          separatorBuilder: (context, index) => const Divider(height: 24),
          itemBuilder: (context, index) {
            if (index == steps.length) {
              // Dernière étape : arrivée
              return _buildArrivalStep();
            }
            
            final step = steps[index];
            return _buildInstructionStep(step, index);
          },
        );
      },
    );
  }

  Widget _buildInstructionStep(RouteStep step, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numéro d'étape
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Contenu
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instruction
              Text(
                step.instruction.isNotEmpty
                    ? step.instruction
                    : 'Continuez sur ${step.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Nom de la rue
              if (step.name.isNotEmpty)
                Text(
                  step.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Distance et durée
              Row(
                children: [
                  Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${step.distance.toInt()} m',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${(step.duration / 60).ceil()} min',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Icône de manœuvre
        Icon(
          _getManeuverIcon(step.maneuver),
          color: AppColors.primary,
          size: 28,
        ),
      ],
    );
  }

  Widget _buildArrivalStep() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.flag,
            color: Colors.white,
            size: 20,
          ),
        ),
        
        const SizedBox(width: 16),
        
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arrivée à destination',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Vous êtes arrivé !',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectLocation(BuildContext context, {required bool isFrom}) {
    // TODO: Implémenter sélection sur carte ou recherche d'adresse
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFrom ? 'Point de départ' : 'Point d\'arrivée'),
        content: const Text(
          'Fonctionnalité à implémenter:\n\n'
          '• Sélection sur la carte\n'
          '• Recherche d\'adresse\n'
          '• Utiliser position actuelle\n'
          '• Sélectionner depuis favoris\n'
          '• Historique des lieux',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _calculateRoute(BuildContext context) async {
    final provider = context.read<RouteProvider>();
    final weatherProvider = context.read<WeatherProvider>();
    
    try {
      await provider.calculateRoute();
      
      // Générer les suggestions de transport
      if (provider.currentRoute != null) {
        final weather = weatherProvider.currentWeather;
        provider.generateSuggestions(
          isRaining: weather?.isRaining ?? false,
          temperature: weather?.temp ?? 28.0,
        );
        
        // Centrer la carte sur l'itinéraire
        if (provider.currentRoute!.geometry.isNotEmpty) {
          _centerMapOnRoute(provider.currentRoute!);
        }
      }
    } catch (e) {
      // L'erreur est déjà gérée dans le provider
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${provider.error ?? e.toString()}'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _centerMapOnRoute(Route route) {
    if (route.geometry.isEmpty) return;
    
    try {
      // Calculer les limites de l'itinéraire
      final bounds = LatLngBounds.fromPoints(route.geometry);
      
      // Centrer la carte avec padding
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (e) {
      // Fallback: centrer sur le premier point
      if (route.geometry.isNotEmpty) {
        _mapController.move(route.geometry.first, 13.0);
      }
    }
  }

  void _showTransportSuggestions(BuildContext context) {
    final provider = context.read<RouteProvider>();
    
    if (provider.suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune suggestion disponible'),
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Titre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.compare_arrows,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Suggestions de transport',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Liste des suggestions
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.suggestions.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TransportSuggestionCard(
                          suggestion: provider.suggestions[index],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'turn-right':
      case 'turn right':
        return Icons.turn_right;
      case 'turn-left':
      case 'turn left':
        return Icons.turn_left;
      case 'straight':
      case 'continue':
        return Icons.straight;
      case 'arrive':
      case 'destination':
        return Icons.flag;
      case 'depart':
        return Icons.trip_origin;
      case 'fork-right':
        return Icons.call_split;
      case 'fork-left':
        return Icons.call_split;
      case 'merge':
        return Icons.merge;
      case 'roundabout':
        return Icons.roundabout_right;
      default:
        return Icons.arrow_forward;
    }
  }
}