// =============================================================================
// OVERPASS SERVICE - Interrogation directe de l'API Overpass OSM
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Types de transport disponibles en Côte d'Ivoire
enum TransportType {
  bus,
  gbaka,
  woroworo,
  taxi,
  mototaxi,
  all,
}

/// Représente un arrêt de transport OSM
class TransportStop {
  final String id;
  final String osmId;
  final String name;
  final LatLng position;
  final String type;
  final Map<String, dynamic> tags;
  final List<TransportType> availableTransports;
  final bool hasShelter;
  final bool hasBench;
  final bool isAccessible;

  TransportStop({
    required this.id,
    required this.osmId,
    required this.name,
    required this.position,
    required this.type,
    required this.tags,
    required this.availableTransports,
    this.hasShelter = false,
    this.hasBench = false,
    this.isAccessible = false,
  });

  factory TransportStop.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};

    return TransportStop(
      id: 'stop-${json['id']}',
      osmId: json['id'].toString(),
      name: tags['name'] ?? 'Arrêt sans nom',
      position: LatLng(
        json['lat'] ?? 0.0,
        json['lon'] ?? 0.0,
      ),
      type: _determineStopType(tags),
      tags: tags,
      availableTransports: _detectTransportTypes(tags),
      hasShelter: tags['shelter'] == 'yes',
      hasBench: tags['bench'] == 'yes',
      isAccessible: tags['wheelchair'] == 'yes',
    );
  }

  static String _determineStopType(Map<String, dynamic> tags) {
    if (tags['woro_woro'] == 'yes' || tags['woro-woro'] == 'yes') {
      return 'WORO_WORO_STOP';
    }
    if (tags['gbaka'] == 'yes' || tags['minibus'] == 'yes') {
      return 'GBAKA_STOP';
    }
    if (tags['amenity'] == 'taxi') {
      return 'TAXI_STAND';
    }
    if (tags['motorcycle_taxi'] == 'yes' || tags['moto_taxi'] == 'yes') {
      return 'MOTO_TAXI_STAND';
    }
    if (tags['public_transport'] == 'station') {
      return 'STATION';
    }
    return 'BUS_STOP';
  }

  static List<TransportType> _detectTransportTypes(Map<String, dynamic> tags) {
    final types = <TransportType>[];
    final name = tags['name']?.toString().toLowerCase() ?? '';

    // Bus
    if (tags['highway'] == 'bus_stop' || tags['public_transport'] != null) {
      types.add(TransportType.bus);
    }

    // Gbaka
    if (tags['gbaka'] == 'yes' || tags['minibus'] == 'yes' || name.contains('gbaka')) {
      types.add(TransportType.gbaka);
    }

    // Woro-woro
    if (tags['woro_woro'] == 'yes' || tags['woro-woro'] == 'yes' || name.contains('woro')) {
      types.add(TransportType.woroworo);
    }

    // Taxi
    if (tags['amenity'] == 'taxi' || tags['taxi'] == 'yes' || name.contains('taxi')) {
      types.add(TransportType.taxi);
    }

    // Moto-taxi
    if (tags['motorcycle_taxi'] == 'yes' || tags['moto_taxi'] == 'yes' || name.contains('moto')) {
      types.add(TransportType.mototaxi);
    }

    return types.isEmpty ? [TransportType.bus] : types;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'osmId': osmId,
    'name': name,
    'lat': position.latitude,
    'lon': position.longitude,
    'type': type,
    'tags': tags,
    'availableTransports': availableTransports.map((e) => e.name).toList(),
    'hasShelter': hasShelter,
    'hasBench': hasBench,
    'isAccessible': isAccessible,
  };
}

/// Service pour interroger l'API Overpass
class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration _timeout = Duration(seconds: 60);

  final http.Client _client = http.Client();
  final _stopCache = <String, List<TransportStop>>{};
  final _cacheExpiry = <String, DateTime>{};
  static const _cacheDuration = Duration(hours: 6);

  /// Récupère les arrêts de transport dans une zone
  Future<List<TransportStop>> getStopsInArea({
    required LatLng center,
    required double radiusMeters,
    TransportType type = TransportType.all,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${center.latitude},${center.longitude},$radiusMeters,$type';

    // Vérifier le cache
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _stopCache[cacheKey]!;
    }

    final query = _buildOverpassQuery(
      lat: center.latitude,
      lon: center.longitude,
      radius: radiusMeters,
      type: type,
    );

    try {
      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'GbakaMap/1.0 Flutter App',
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stops = _parseOverpassResponse(data);

        // Mettre en cache
        _stopCache[cacheKey] = stops;
        _cacheExpiry[cacheKey] = DateTime.now().add(_cacheDuration);

        return stops;
      } else {
        throw Exception('Erreur Overpass: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback: retourner le cache même expiré
      if (_stopCache.containsKey(cacheKey)) {
        return _stopCache[cacheKey]!;
      }
      rethrow;
    }
  }

  /// Construit la requête Overpass optimisée
  String _buildOverpassQuery({
    required double lat,
    required double lon,
    required double radius,
    required TransportType type,
  }) {
    final baseQuery = '''
[out:json][timeout:60][maxsize:1073741824];
(
  // === ARRÊTS DE BUS OFFICIELS ===
  node(around:$radius, $lat, $lon)["highway"="bus_stop"];
  node(around:$radius, $lat, $lon)["public_transport"="platform"];
  node(around:$radius, $lat, $lon)["public_transport"="station"];
  node(around:$radius, $lat, $lon)["public_transport"="stop_position"];
  
  // === ARRÊTS DE TAXI ===
  node(around:$radius, $lat, $lon)["amenity"="taxi"];
  node(around:$radius, $lat, $lon)["taxi"="yes"];
  
  // === GBAKA ET WORO-WORO ===
  node(around:$radius, $lat, $lon)["minibus"="yes"];
  node(around:$radius, $lat, $lon)["gbaka"="yes"];
  node(around:$radius, $lat, $lon)["woro_woro"="yes"];
  node(around:$radius, $lat, $lon)["woro-woro"="yes"];
  
  // === MOTO-TAXI ===
  node(around:$radius, $lat, $lon)["motorcycle_taxi"="yes"];
  node(around:$radius, $lat, $lon)["moto_taxi"="yes"];
  
  // === RECHERCHE PAR NOM ===
  node(around:$radius, $lat, $lon)["name"~"[Gg]baka"];
  node(around:$radius, $lat, $lon)["name"~"[Ww]oro"];
  node(around:$radius, $lat, $lon)["name"~"[Aa]rrêt"];
  node(around:$radius, $lat, $lon)["name"~"[Gg]are"];
  node(around:$radius, $lat, $lon)["name"~"[Tt]axi"];
  node(around:$radius, $lat, $lon)["name"~"[Mm]oto"];
  
  // === LIEUX D'EMBARQUEMENT ===
  node(around:$radius, $lat, $lon)["public_transport"];
  node(around:$radius, $lat, $lon)["amenity"="marketplace"];
  
  // Gares routières
  way(around:$radius, $lat, $lon)["public_transport"="station"];
  way(around:$radius, $lat, $lon)["amenity"="bus_station"];
);
out body meta;
>;
out skel qt;
''';

    return baseQuery;
  }

  /// Parse la réponse Overpass
  List<TransportStop> _parseOverpassResponse(Map<String, dynamic> data) {
    final elements = data['elements'] as List? ?? [];
    final stops = <TransportStop>[];
    final seenIds = <String>{};

    for (final element in elements) {
      if (element['type'] != 'node') continue;
      if (element['lat'] == null || element['lon'] == null) continue;

      final id = element['id'].toString();
      if (seenIds.contains(id)) continue;

      seenIds.add(id);

      try {
        stops.add(TransportStop.fromJson(element));
      } catch (e) {
        // Ignorer les éléments invalides
        continue;
      }
    }

    // Supprimer les doublons par proximité (< 50m)
    return _removeDuplicatesByProximity(stops);
  }

  /// Supprime les doublons basés sur la proximité
  List<TransportStop> _removeDuplicatesByProximity(List<TransportStop> stops) {
    if (stops.isEmpty) return stops;

    final filtered = <TransportStop>[];
    const Distance distance = Distance();

    for (final stop in stops) {
      bool isDuplicate = false;

      for (final existing in filtered) {
        final dist = distance.as(
          LengthUnit.Meter,
          stop.position,
          existing.position,
        );

        if (dist < 50) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        filtered.add(stop);
      }
    }

    return filtered;
  }

  /// Vérifie si le cache est valide
  bool _isCacheValid(String key) {
    if (!_stopCache.containsKey(key)) return false;
    if (!_cacheExpiry.containsKey(key)) return false;

    return DateTime.now().isBefore(_cacheExpiry[key]!);
  }

  /// Nettoie le cache
  void clearCache() {
    _stopCache.clear();
    _cacheExpiry.clear();
  }

  /// Libère les ressources
  void dispose() {
    _client.close();
    clearCache();
  }
}