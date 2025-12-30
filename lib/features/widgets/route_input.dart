// =============================================================================
// ROUTE WIDGETS - Composants UI pour les itinéraires
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/route_service.dart' as route_service;

// =============================================================================
// ROUTE INPUT FIELD - Champ de saisie pour départ/arrivée
// =============================================================================

class RouteInputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const RouteInputField({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: value.isEmpty
            ? Text(
                label,
                style: TextStyle(color: Colors.grey[600]),
              )
            : Text(value),
        trailing: value.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: onClear,
              ),
        onTap: onTap,
      ),
    );
  }
}

// =============================================================================
// ROUTE SUMMARY CARD - Résumé de l'itinéraire
// =============================================================================

class RouteSummaryCard extends StatelessWidget {
  final route_service.Route route;
  final VoidCallback onShowSuggestions;

  const RouteSummaryCard({
    super.key,
    required this.route,
    required this.onShowSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Distance
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: route.formattedDistance,
                    color: AppColors.primary,
                  ),
                ),
                
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                
                // Durée
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'Durée',
                    value: route.formattedDuration,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Bouton suggestions
          InkWell(
            onTap: onShowSuggestions,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_bus,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Voir les suggestions de transport',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TRANSPORT SUGGESTION CARD - Carte de suggestion de transport
// =============================================================================

class TransportSuggestionCard extends StatelessWidget {
  final route_service.TransportSuggestion suggestion;

  const TransportSuggestionCard({
    super.key,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: suggestion.rank == 1
              ? AppColors.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: suggestion.rank == 1
                  ? AppColors.primary.withOpacity(0.1)
                  : null,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Emoji transport
                Text(
                  suggestion.modeIcon,
                  style: const TextStyle(fontSize: 32),
                ),
                
                const SizedBox(width: 12),
                
                // Nom et raison
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getModeLabel(suggestion.mode),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (suggestion.rank == 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'RECOMMANDÉ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.reason,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Score
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getScoreColor(suggestion.overallScore),
                  child: Text(
                    '${suggestion.overallScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Infos principales
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.attach_money,
                      label: suggestion.formattedPrice,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.access_time,
                      label: '${(suggestion.duration / 60).round()} min',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.wb_sunny,
                      label: '${suggestion.weatherScore}%',
                      color: Colors.blue,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Avantages
                _buildSection(
                  title: 'Avantages',
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  items: suggestion.pros,
                ),
                
                const SizedBox(height: 12),
                
                // Inconvénients
                _buildSection(
                  title: 'Inconvénients',
                  icon: Icons.cancel,
                  iconColor: Colors.red,
                  items: suggestion.cons,
                ),
                
                if (suggestion.advice.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  
                  // Conseils
                  _buildSection(
                    title: 'Conseils',
                    icon: Icons.lightbulb,
                    iconColor: Colors.amber,
                    items: suggestion.advice,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 22, top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getModeLabel(String mode) {
    switch (mode) {
      case 'bus':
        return 'Bus SOTRA';
      case 'gbaka':
        return 'Gbaka';
      case 'woro_woro':
        return 'Woro-woro';
      case 'taxi':
        return 'Taxi';
      case 'moto_taxi':
        return 'Moto-taxi';
      case 'walking':
        return 'Marche à pied';
      default:
        return mode;
    }
  }
}