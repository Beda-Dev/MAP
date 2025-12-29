// =============================================================================
// APP COLORS - Couleurs de l'application
// Fichier: lib/core/theme/app_colors.dart
// =============================================================================

import 'package:flutter/material.dart';

class AppColors {
  // Interdire l'instanciation
  AppColors._();

  // ========== COULEURS PRINCIPALES ==========
  
  /// Couleur primaire de l'application (Bleu-vert)
  static const Color primary = Color(0xFF0A9396);
  
  /// Couleur secondaire (Bleu foncé)
  static const Color secondary = Color(0xFF005F73);
  
  /// Couleur d'accent (Orange/Jaune)
  static const Color accent = Color(0xFFEE9B00);

  // ========== COULEURS PAR TYPE DE TRANSPORT ==========
  
  /// Couleur des bus SOTRA (Orange vif)
  static const Color busColor = Color(0xFFFF6B35);
  
  /// Couleur des gbakas (Bleu-vert)
  static const Color gbakaColor = Color(0xFF0A9396);
  
  /// Couleur des woro-woro (Rose fuchsia)
  static const Color woroworoColor = Color(0xFFF72585);
  
  /// Couleur des taxis (Jaune/Or)
  static const Color taxiColor = Color(0xFFFFB703);
  
  /// Couleur des moto-taxis (Violet)
  static const Color mototaxiColor = Color(0xFF8338EC);

  // ========== COULEURS D'ÉTAT ==========
  
  /// Succès / Validation
  static const Color success = Color(0xFF06D6A0);
  
  /// Avertissement
  static const Color warning = Color(0xFFFFB703);
  
  /// Erreur
  static const Color error = Color(0xFFEF476F);
  
  /// Information
  static const Color info = Color(0xFF118AB2);

  // ========== COULEURS DE FOND ==========
  
  /// Fond clair (mode light)
  static const Color backgroundLight = Color(0xFFF8F9FA);
  
  /// Fond sombre (mode dark)
  static const Color backgroundDark = Color(0xFF212529);
  
  /// Fond carte/surface
  static const Color surface = Color(0xFFFFFFFF);
  
  /// Fond carte/surface (dark)
  static const Color surfaceDark = Color(0xFF2C2C2C);

  // ========== COULEURS DE TEXTE ==========
  
  /// Texte principal
  static const Color textPrimary = Color(0xFF212529);
  
  /// Texte secondaire
  static const Color textSecondary = Color(0xFF6C757D);
  
  /// Texte désactivé
  static const Color textDisabled = Color(0xFFADB5BD);
  
  /// Texte sur fond sombre
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ========== COULEURS GRISES ==========
  
  static const Color grey50 = Color(0xFFF8F9FA);
  static const Color grey100 = Color(0xFFE9ECEF);
  static const Color grey200 = Color(0xFFDEE2E6);
  static const Color grey300 = Color(0xFFCED4DA);
  static const Color grey400 = Color(0xFFADB5BD);
  static const Color grey500 = Color(0xFF6C757D);
  static const Color grey600 = Color(0xFF495057);
  static const Color grey700 = Color(0xFF343A40);
  static const Color grey800 = Color(0xFF212529);
  static const Color grey900 = Color(0xFF1A1D20);

  // ========== COULEURS UTILITAIRES ==========
  
  /// Bordure
  static const Color border = Color(0xFFDEE2E6);
  
  /// Diviseur
  static const Color divider = Color(0xFFE9ECEF);
  
  /// Ombre
  static Color shadow = Colors.black.withOpacity(0.1);
  
  /// Overlay (fond modal)
  static Color overlay = Colors.black.withOpacity(0.5);

  // ========== DÉGRADÉS ==========
  
  /// Dégradé primaire
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Dégradé accent
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFFFFD500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Dégradé pour le splash screen
  static const LinearGradient splashGradient = LinearGradient(
    colors: [primary, secondary, Color(0xFF001219)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ========== MÉTHODES UTILITAIRES ==========
  
  /// Retourne la couleur selon le type de transport
  static Color getTransportColor(String type) {
    switch (type.toUpperCase()) {
      case 'BUS':
      case 'BUS_STOP':
        return busColor;
      case 'GBAKA':
      case 'GBAKA_STOP':
        return gbakaColor;
      case 'WORO_WORO':
      case 'WORO_WORO_STOP':
      case 'WOROWORO':
        return woroworoColor;
      case 'TAXI':
      case 'TAXI_STAND':
        return taxiColor;
      case 'MOTO_TAXI':
      case 'MOTO_TAXI_STAND':
      case 'MOTOTAXI':
        return mototaxiColor;
      case 'STATION':
        return primary;
      default:
        return grey500;
    }
  }
  
  /// Retourne une couleur avec opacité
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  /// Retourne une couleur plus claire
  static Color lighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
  
  /// Retourne une couleur plus foncée
  static Color darken(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}