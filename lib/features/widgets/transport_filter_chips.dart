import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/overpass_service.dart';
import '../providers/transport_provider.dart';



// =============================================================================
// TRANSPORT FILTER CHIPS - Filtres par type de transport
// =============================================================================

class TransportFilterChips extends StatelessWidget {
  const TransportFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransportProvider>(
      builder: (context, provider, child) {
        final counts = provider.getStopCounts();

        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip(
                context,
                provider,
                'Tous',
                TransportType.all,
                Icons.map,
                provider.stops.length,
              ),
              _buildFilterChip(
                context,
                provider,
                'Bus',
                TransportType.bus,
                Icons.directions_bus,
                counts[TransportType.bus] ?? 0,
              ),
              _buildFilterChip(
                context,
                provider,
                'Gbaka',
                TransportType.gbaka,
                Icons.airport_shuttle,
                counts[TransportType.gbaka] ?? 0,
              ),
              _buildFilterChip(
                context,
                provider,
                'Woro-woro',
                TransportType.woroworo,
                Icons.local_taxi,
                counts[TransportType.woroworo] ?? 0,
              ),
              _buildFilterChip(
                context,
                provider,
                'Taxi',
                TransportType.taxi,
                Icons.local_taxi,
                counts[TransportType.taxi] ?? 0,
              ),
              _buildFilterChip(
                context,
                provider,
                'Moto',
                TransportType.mototaxi,
                Icons.two_wheeler,
                counts[TransportType.mototaxi] ?? 0,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
      BuildContext context,
      TransportProvider provider,
      String label,
      TransportType type,
      IconData icon,
      int count,
      ) {
    final isSelected = provider.selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          provider.setTransportType(type);
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

