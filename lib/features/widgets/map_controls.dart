import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// =============================================================================
// MAP CONTROLS - Contrôles de la carte
// =============================================================================

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRefresh;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildControlButton(
          icon: Icons.add,
          onPressed: onZoomIn,
        ),
        const SizedBox(height: 8),
        _buildControlButton(
          icon: Icons.remove,
          onPressed: onZoomOut,
        ),
        const SizedBox(height: 16),
        _buildControlButton(
          icon: Icons.refresh,
          onPressed: onRefresh,
          backgroundColor: AppColors.primary,
          iconColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: iconColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}