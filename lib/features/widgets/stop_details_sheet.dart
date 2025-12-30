// =============================================================================
// STOP DETAILS SHEET - Avec toutes les fonctionnalités
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/overpass_service.dart';
import '../../core/config/env_config.dart';
import '../providers/route_provider.dart';
import '../map/screens/route_search_screen.dart';

class StopDetailsSheet extends StatelessWidget {
  final TransportStop stop;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;

  const StopDetailsSheet({
    super.key,
    required this.stop,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    Logger.info('Affichage détails arrêt: ${stop.name}', 'StopDetailsSheet');
    Logger.debug('Position: ${stop.position.latitude}, ${stop.position.longitude}', 'StopDetailsSheet');
    Logger.debug('Type: ${stop.type}', 'StopDetailsSheet');
    Logger.debug('Transports: ${stop.availableTransports.map((t) => t.name).join(", ")}', 'StopDetailsSheet');
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle de glissement
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // En-tête avec nom et bouton favori
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStopTypeLabel(stop.type),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Logger.info('Toggle favori: ${stop.name}', 'StopDetailsSheet');
                      onToggleFavorite();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFavorite 
                                ? '❤️ Ajouté aux favoris' 
                                : '💔 Retiré des favoris',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    iconSize: 32,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Types de transport disponibles
              _buildTransportTypes(),

              const SizedBox(height: 20),

              // Équipements
              _buildFacilities(),

              const SizedBox(height: 20),

              // Coordonnées
              _buildCoordinates(context),

              const SizedBox(height: 20),

              // Tags OSM
              if (stop.tags.isNotEmpty) _buildOSMTags(),

              const SizedBox(height: 20),

              // Boutons d'action
              _buildActionButtons(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransportTypes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transports disponibles',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stop.availableTransports.map((type) {
            return Chip(
              avatar: Icon(
                _getIconForTransportType(type),
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                _getTransportTypeLabel(type),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _getColorForTransportType(type),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFacilities() {
    final facilities = <Map<String, dynamic>>[
      if (stop.hasShelter) {
        'icon': Icons.home,
        'label': 'Abri',
        'color': Colors.green,
      },
      if (stop.hasBench) {
        'icon': Icons.weekend,
        'label': 'Banc',
        'color': Colors.blue,
      },
      if (stop.isAccessible) {
        'icon': Icons.accessible,
        'label': 'Accessible',
        'color': Colors.purple,
      },
    ];

    if (facilities.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Équipements',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: facilities.map((facility) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (facility['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: facility['color'] as Color,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    facility['icon'] as IconData,
                    size: 16,
                    color: facility['color'] as Color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    facility['label'] as String,
                    style: TextStyle(
                      color: facility['color'] as Color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCoordinates(BuildContext context) {
    Logger.debug('Affichage coordonnées: ${stop.position.latitude}, ${stop.position.longitude}', 'StopDetailsSheet');
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Coordonnées',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copyCoordinates(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Latitude: ${stop.position.latitude.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Longitude: ${stop.position.longitude.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'OSM ID: ${stop.osmId}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _copyCoordinates(BuildContext context) {
    Logger.info('Copie coordonnées: ${stop.position.latitude}, ${stop.position.longitude}', 'StopDetailsSheet');
    
    final coords = '${stop.position.latitude}, ${stop.position.longitude}';
    Clipboard.setData(ClipboardData(text: coords));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Coordonnées copiées'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildOSMTags() {
    Logger.debug('Affichage ${stop.tags.length} tags OSM', 'StopDetailsSheet');
    
    return ExpansionTile(
      title: const Text(
        'Tags OpenStreetMap',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      children: stop.tags.entries.map((entry) {
        return ListTile(
          dense: true,
          title: Text(
            entry.key,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            entry.value.toString(),
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _navigateToRoute(context),
            icon: const Icon(Icons.directions),
            label: const Text('Itinéraire'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareStop(context),
            icon: const Icon(Icons.share),
            label: const Text('Partager'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToRoute(BuildContext context) {
    Logger.info('Navigation vers itinéraire pour: ${stop.name}', 'StopDetailsSheet');
    Logger.debug('Destination: ${stop.position.latitude}, ${stop.position.longitude}', 'StopDetailsSheet');
    
    Navigator.pop(context); // Fermer le bottom sheet
    
    // Naviguer vers l'écran de recherche d'itinéraire avec destination prédéfinie
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteSearchScreen(
          initialTo: stop.position,
        ),
      ),
    );
    
    Logger.debug('Navigation lancée vers écran itinéraire', 'StopDetailsSheet');
  }

  void _shareStop(BuildContext context) {
    Logger.info('Partage arrêt: ${stop.name}', 'StopDetailsSheet');
    Logger.debug('Position: ${stop.position.latitude}, ${stop.position.longitude}', 'StopDetailsSheet');
    
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${stop.position.latitude},${stop.position.longitude}';
    final osmUrl = 'https://www.openstreetmap.org/?mlat=${stop.position.latitude}&mlon=${stop.position.longitude}#map=18/${stop.position.latitude}/${stop.position.longitude}';
    
    final message = '''
🚏 ${stop.name}
📍 ${_getStopTypeLabel(stop.type)}

Coordonnées:
${stop.position.latitude.toStringAsFixed(6)}, ${stop.position.longitude.toStringAsFixed(6)}

Transports disponibles:
${stop.availableTransports.map((t) => '• ${_getTransportTypeLabel(t)}').join('\n')}

🗺️ Voir sur Google Maps:
$googleMapsUrl

🗺️ Voir sur OpenStreetMap:
$osmUrl

Partagé depuis GbakaMap 🇨🇮
''';

    Logger.debug('Message de partage préparé (${message.length} caractères)', 'StopDetailsSheet');
    
    Share.share(
      message,
      subject: 'Arrêt de transport: ${stop.name}',
    ).then((_) {
      Logger.info('✅ Partage effectué', 'StopDetailsSheet');
    }).catchError((error) {
      Logger.error('❌ Erreur partage', 'StopDetailsSheet', error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du partage: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  String _getStopTypeLabel(String type) {
    switch (type) {
      case 'BUS_STOP':
        return 'Arrêt de bus';
      case 'GBAKA_STOP':
        return 'Arrêt de gbaka';
      case 'WORO_WORO_STOP':
        return 'Arrêt woro-woro';
      case 'TAXI_STAND':
        return 'Station de taxi';
      case 'MOTO_TAXI_STAND':
        return 'Arrêt moto-taxi';
      case 'STATION':
        return 'Gare routière';
      default:
        return 'Arrêt de transport';
    }
  }

  String _getTransportTypeLabel(TransportType type) {
    switch (type) {
      case TransportType.bus:
        return 'Bus';
      case TransportType.gbaka:
        return 'Gbaka';
      case TransportType.woroworo:
        return 'Woro-woro';
      case TransportType.taxi:
        return 'Taxi';
      case TransportType.mototaxi:
        return 'Moto-taxi';
      default:
        return 'Transport';
    }
  }

  IconData _getIconForTransportType(TransportType type) {
    switch (type) {
      case TransportType.bus:
        return Icons.directions_bus;
      case TransportType.gbaka:
        return Icons.airport_shuttle;
      case TransportType.woroworo:
        return Icons.local_taxi;
      case TransportType.taxi:
        return Icons.local_taxi;
      case TransportType.mototaxi:
        return Icons.two_wheeler;
      default:
        return Icons.place;
    }
  }

  Color _getColorForTransportType(TransportType type) {
    switch (type) {
      case TransportType.bus:
        return AppColors.busColor;
      case TransportType.gbaka:
        return AppColors.gbakaColor;
      case TransportType.woroworo:
        return AppColors.woroworoColor;
      case TransportType.taxi:
        return AppColors.taxiColor;
      case TransportType.mototaxi:
        return AppColors.mototaxiColor;
      default:
        return Colors.grey;
    }
  }
}