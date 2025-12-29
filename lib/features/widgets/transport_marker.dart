// =============================================================================
// UI WIDGETS - Composants visuels réutilisables
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/overpass_service.dart';
import '../providers/transport_provider.dart';
import '../providers/map_provider.dart';

// =============================================================================
// TRANSPORT MARKER - Marqueur personnalisé par type de transport
// =============================================================================

class TransportMarkerWidget extends StatelessWidget {
  final TransportStop stop;
  final bool isFavorite;

  const TransportMarkerWidget({
    super.key,
    required this.stop,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Icône principale
        Container(
          decoration: BoxDecoration(
            color: _getColorForType(stop.type),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              _getIconForType(stop.type),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

        // Badge favori
        if (isFavorite)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
      ],
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'BUS_STOP':
        return AppColors.busColor;
      case 'GBAKA_STOP':
        return AppColors.gbakaColor;
      case 'WORO_WORO_STOP':
        return AppColors.woroworoColor;
      case 'TAXI_STAND':
        return AppColors.taxiColor;
      case 'MOTO_TAXI_STAND':
        return AppColors.mototaxiColor;
      case 'STATION':
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'BUS_STOP':
        return Icons.directions_bus;
      case 'GBAKA_STOP':
        return Icons.airport_shuttle;
      case 'WORO_WORO_STOP':
        return Icons.local_taxi;
      case 'TAXI_STAND':
        return Icons.local_taxi;
      case 'MOTO_TAXI_STAND':
        return Icons.two_wheeler;
      case 'STATION':
        return Icons.location_city;
      default:
        return Icons.place;
    }
  }
}

