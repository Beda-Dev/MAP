// =============================================================================
// OVERPASS SERVICE - Version corrigée avec requête simplifiée
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/env_config.dart';

enum TransportType {
  bus,
  gbaka,
  woroworo,
  taxi,
  mototaxi,
  all,
}

class TransportRoute {
  final String id;
  final String name;
  final String type;
  final String operator;
  final List<LatLng> geometry;
  final List<TransportStop> stops;
  final Map<String, dynamic> tags;

  TransportRoute({
    required this.id,
    required this.name,
    required this.type,
    required this.operator,
    required this.geometry,
    required this.stops,
    required this.tags,
  });

  factory TransportRoute.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    
    return TransportRoute(
      id: 'route-${json['id']}',
      name: tags['name'] ?? tags['ref'] ?? 'Ligne sans nom',
      type: tags['route'] ?? 'bus',
      operator: tags['operator'] ?? 'Inconnu',
      geometry: [],
      stops: [],
      tags: tags,
    );
  }
}

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
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lon'] as num?)?.toDouble() ?? 0.0,
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

    if (tags['highway'] == 'bus_stop' || tags['public_transport'] != null) {
      types.add(TransportType.bus);
    }
    if (tags['gbaka'] == 'yes' || tags['minibus'] == 'yes' || name.contains('gbaka')) {
      types.add(TransportType.gbaka);
    }
    if (tags['woro_woro'] == 'yes' || tags['woro-woro'] == 'yes' || name.contains('woro')) {
      types.add(TransportType.woroworo);
    }
    if (tags['amenity'] == 'taxi' || tags['taxi'] == 'yes' || name.contains('taxi')) {
      types.add(TransportType.taxi);
    }
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

class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration _timeout = Duration(seconds: 60);

  final http.Client _client = http.Client();
  final _stopCache = <String, List<TransportStop>>{};
  final _routeCache = <String, List<TransportRoute>>{};
  final _cacheExpiry = <String, DateTime>{};
  static const _cacheDuration = Duration(hours: 6);

  OverpassService() {
    Logger.info('OverpassService initialisé', 'OverpassService');
    Logger.debug('URL API: $_baseUrl', 'OverpassService');
    Logger.debug('Timeout: ${_timeout.inSeconds}s', 'OverpassService');
    Logger.debug('Durée cache: ${_cacheDuration.inHours}h', 'OverpassService');
  }

  /// Récupère les arrêts ET les routes de transport
  Future<Map<String, dynamic>> getTransportData({
    required LatLng center,
    required double radiusMeters,
    TransportType type = TransportType.all,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${center.latitude},${center.longitude},$radiusMeters,$type';
    
    Logger.debug('=== DÉBUT getTransportData ===', 'OverpassService');
    Logger.debug('Position: ${center.latitude}, ${center.longitude}', 'OverpassService');
    Logger.debug('Rayon: ${radiusMeters}m', 'OverpassService');
    Logger.debug('Type: $type', 'OverpassService');
    Logger.debug('Force refresh: $forceRefresh', 'OverpassService');

    if (!forceRefresh && _isCacheValid(cacheKey)) {
      final cachedStops = _stopCache[cacheKey] ?? [];
      final cachedRoutes = _routeCache[cacheKey] ?? [];
      Logger.info('✅ Données récupérées depuis le cache', 'OverpassService');
      Logger.debug('Arrêts: ${cachedStops.length}, Routes: ${cachedRoutes.length}', 'OverpassService');
      return {
        'stops': cachedStops,
        'routes': cachedRoutes,
      };
    }

    // CORRECTION: Utiliser un rayon raisonnable
    final adjustedRadius = radiusMeters > 2000 ? 2000.0 : radiusMeters;
    if (adjustedRadius != radiusMeters) {
      Logger.warning('⚠️ Rayon réduit: ${radiusMeters}m → ${adjustedRadius}m', 'OverpassService');
    }

    final query = _buildSimplifiedOverpassQuery(
      lat: center.latitude,
      lon: center.longitude,
      radius: adjustedRadius,
      type: type,
    );

    Logger.debug('📝 Requête générée (${query.length} caractères)', 'OverpassService');
    Logger.debug('Requête complète:\n$query', 'OverpassService');

    try {
      final url = Uri.parse(EnvConfig.overpassApiUrl);
      Logger.info('🌐 Envoi requête POST vers Overpass API', 'OverpassService');
      Logger.debug('URL: $url', 'OverpassService');
      
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'GbakaMap/1.0 Flutter App',
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 30)); // CORRECTION: Timeout augmenté

      Logger.info('📡 Réponse reçue - Status: ${response.statusCode}', 'OverpassService');
      Logger.debug('Taille réponse: ${response.body.length} octets', 'OverpassService');
      Logger.debug('Content-Type: ${response.headers['content-type']}', 'OverpassService');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        Logger.info('=== ANALYSE RÉPONSE JSON ===', 'OverpassService');
        Logger.debug('Type données: ${data.runtimeType}', 'OverpassService');
        Logger.debug('Clés: ${data.keys.toList()}', 'OverpassService');
        
        if (data['elements'] != null) {
          final elements = data['elements'] as List;
          Logger.info('✅ ${elements.length} éléments reçus', 'OverpassService');
          
          final types = elements.map((e) => e['type']).toSet().toList();
          Logger.debug('Types d\'éléments: $types', 'OverpassService');
          
          // Compter par type
          final nodeCount = elements.where((e) => e['type'] == 'node').length;
          final wayCount = elements.where((e) => e['type'] == 'way').length;
          final relationCount = elements.where((e) => e['type'] == 'relation').length;
          Logger.debug('Nodes: $nodeCount, Ways: $wayCount, Relations: $relationCount', 'OverpassService');
          
          // Afficher les premiers éléments
          Logger.info('=== ÉCHANTILLON ÉLÉMENTS (5 premiers) ===', 'OverpassService');
          for (int i = 0; i < elements.length && i < 5; i++) {
            final element = elements[i];
            Logger.debug('[$i] ${element['type']} ID:${element['id']}', 'OverpassService');
            if (element['tags'] != null) {
              final tags = element['tags'] as Map<String, dynamic>;
              Logger.debug('    Tags: ${tags.keys.take(5).toList()}', 'OverpassService');
              if (tags['name'] != null) {
                Logger.debug('    Nom: ${tags['name']}', 'OverpassService');
              }
            }
            if (element['lat'] != null && element['lon'] != null) {
              Logger.debug('    Position: ${element['lat']}, ${element['lon']}', 'OverpassService');
            }
          }
        } else {
          Logger.warning('⚠️ Aucun élément dans la réponse', 'OverpassService');
        }
        
        Logger.info('🔄 Parsing des données...', 'OverpassService');
        final result = _parseOverpassResponseWithRoutes(data);
        final stops = result['stops'] as List<TransportStop>;
        final routes = result['routes'] as List<TransportRoute>;

        _stopCache[cacheKey] = stops;
        _routeCache[cacheKey] = routes;
        _cacheExpiry[cacheKey] = DateTime.now().add(_cacheDuration);

        Logger.info('✅ SUCCÈS - Arrêts: ${stops.length}, Routes: ${routes.length}', 'OverpassService');
        Logger.debug('Cache mis à jour avec expiration: ${_cacheExpiry[cacheKey]}', 'OverpassService');

        return result;
      } else if (response.statusCode == 504) {
        Logger.error('❌ Timeout serveur (504)', 'OverpassService', response.body);
        return {'stops': <TransportStop>[], 'routes': <TransportRoute>[]};
      } else if (response.statusCode == 429) {
        Logger.error('❌ Rate limit (429)', 'OverpassService', response.body);
        return {'stops': <TransportStop>[], 'routes': <TransportRoute>[]};
      } else {
        Logger.error('❌ Erreur HTTP ${response.statusCode}', 'OverpassService', response.body);
        throw Exception('Erreur Overpass: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      Logger.error('❌ Exception getTransportData', 'OverpassService', e);
      Logger.debug('Stack trace:\n$stackTrace', 'OverpassService');
      
      if (_stopCache.containsKey(cacheKey)) {
        Logger.info('🔄 Récupération depuis cache après erreur', 'OverpassService');
        return {
          'stops': _stopCache[cacheKey] ?? [],
          'routes': _routeCache[cacheKey] ?? [],
        };
      }
      
      Logger.warning('⚠️ Retour données vides', 'OverpassService');
      return {'stops': <TransportStop>[], 'routes': <TransportRoute>[]};
    }
  }

  /// CORRECTION: Requête Overpass simplifiée qui fonctionne réellement
  String _buildSimplifiedOverpassQuery({
    required double lat,
    required double lon,
    required double radius,
    required TransportType type,
  }) {
    Logger.debug('Construction requête simplifiée', 'OverpassService');
    Logger.debug('Position: $lat, $lon - Rayon: $radius', 'OverpassService');
    
    // Requête SIMPLE qui renvoie VRAIMENT des résultats
    return '''
[out:json][timeout:25];
(
  // Arrêts de bus standard
  node(around:$radius,$lat,$lon)["highway"="bus_stop"];
  
  // Plateformes de transport public
  node(around:$radius,$lat,$lon)["public_transport"="platform"];
  node(around:$radius,$lat,$lon)["public_transport"="stop_position"];
  
  // Stations de taxi
  node(around:$radius,$lat,$lon)["amenity"="taxi"];
  
  // Transport informel (si taggé)
  node(around:$radius,$lat,$lon)["minibus"="yes"];
  node(around:$radius,$lat,$lon)["share_taxi"="yes"];
);
out body;
>;
out skel qt;
''';
  }

  /// Parse la réponse incluant routes et arrêts
  Map<String, dynamic> _parseOverpassResponseWithRoutes(Map<String, dynamic> data) {
    Logger.debug('=== DÉBUT PARSING ===', 'OverpassService');
    
    final elements = data['elements'] as List? ?? [];
    Logger.info('📊 ${elements.length} éléments à parser', 'OverpassService');
    
    final stops = <TransportStop>[];
    final routes = <TransportRoute>[];
    final ways = <String, List<LatLng>>{};
    final routeMembers = <String, List<String>>{};
    
    int nodeCount = 0, wayCount = 0, relationCount = 0;
    int stopsFound = 0, stopsSkipped = 0;
    
    Logger.debug('🔍 Premier passage: identification éléments', 'OverpassService');
    
    // Premier passage: collecter ways et relations
    for (final element in elements) {
      try {
        if (element['type'] == 'way' && element['nodes'] != null) {
          ways[element['id'].toString()] = [];
          wayCount++;
          
        } else if (element['type'] == 'relation') {
          relationCount++;
          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          if (tags['type'] == 'route') {
            final route = TransportRoute.fromJson(element);
            routes.add(route);
            
            final members = element['members'] as List? ?? [];
            routeMembers[route.id] = members
                .where((m) => m['type'] == 'way')
                .map((m) => m['ref'].toString())
                .toList();
            
            Logger.debug('  Route: ${route.name} (${members.length} membres)', 'OverpassService');
          }
          
        } else if (element['type'] == 'node' && element['lat'] != null && element['lon'] != null) {
          nodeCount++;
          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          
          // CORRECTION: Accepter TOUS les nodes avec tags de transport
          final isTransportStop = tags['highway'] == 'bus_stop' || 
              tags['public_transport'] != null ||
              tags['amenity'] == 'taxi' ||
              tags['minibus'] == 'yes' ||
              tags['share_taxi'] == 'yes';
              
          if (isTransportStop) {
            try {
              final stop = TransportStop.fromJson(element);
              stops.add(stop);
              stopsFound++;
              
              if (stopsFound <= 3) {
                Logger.debug('  ✅ Arrêt: ${stop.name} (${stop.type})', 'OverpassService');
              }
            } catch (e) {
              stopsSkipped++;
              Logger.warning('  ⚠️ Erreur parsing arrêt: $e', 'OverpassService');
            }
          }
        }
      } catch (e) {
        Logger.warning('⚠️ Erreur élément: $e', 'OverpassService');
      }
    }
    
    Logger.info('📊 Comptage: Nodes=$nodeCount, Ways=$wayCount, Relations=$relationCount', 'OverpassService');
    Logger.info('🎯 Arrêts trouvés=$stopsFound, ignorés=$stopsSkipped', 'OverpassService');
    Logger.info('🚏 Routes extraites: ${routes.length}', 'OverpassService');
    
    // Second passage: construire géométries des ways
    Logger.debug('🔄 Second passage: géométries', 'OverpassService');
    int geometryCount = 0;
    for (final element in elements) {
      if (element['type'] == 'node' && element['lat'] != null) {
        final nodeId = element['id'].toString();
        final lat = (element['lat'] as num).toDouble();
        final lon = (element['lon'] as num).toDouble();
        
        for (final wayEntry in ways.entries) {
          ways[wayEntry.key]!.add(LatLng(lat, lon));
        }
        geometryCount++;
      }
    }
    Logger.debug('  Géométries construites: $geometryCount points', 'OverpassService');
    
    // Associer géométries aux routes
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final memberIds = routeMembers[route.id] ?? [];
      final geometry = <LatLng>[];
      
      for (final wayId in memberIds) {
        if (ways.containsKey(wayId)) {
          geometry.addAll(ways[wayId]!);
        }
      }
      
      routes[i] = TransportRoute(
        id: route.id,
        name: route.name,
        type: route.type,
        operator: route.operator,
        geometry: geometry,
        stops: route.stops,
        tags: route.tags,
      );
      
      if (geometry.isNotEmpty) {
        Logger.debug('  Route ${route.name}: ${geometry.length} points', 'OverpassService');
      }
    }

    Logger.debug('🧹 Suppression doublons...', 'OverpassService');
    final filtered = _removeDuplicatesByProximity(stops);
    
    final result = {
      'stops': filtered,
      'routes': routes,
    };
    
    Logger.info('✅ PARSING TERMINÉ - Arrêts: ${filtered.length}, Routes: ${routes.length}', 'OverpassService');
    Logger.info('======================', 'OverpassService');
    
    return result;
  }

  /// Supprime les doublons par proximité
  List<TransportStop> _removeDuplicatesByProximity(List<TransportStop> stops) {
    if (stops.isEmpty) {
      Logger.debug('Aucun arrêt à filtrer', 'OverpassService');
      return stops;
    }

    Logger.debug('🧹 Filtrage doublons: ${stops.length} arrêts initiaux', 'OverpassService');
    
    final filtered = <TransportStop>[];
    const Distance distance = Distance();
    int duplicatesRemoved = 0;

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
          duplicatesRemoved++;
          if (duplicatesRemoved <= 3) {
            Logger.debug('  🗑️ Doublon: ${stop.name} (${dist.toStringAsFixed(1)}m)', 'OverpassService');
          }
          break;
        }
      }

      if (!isDuplicate) {
        filtered.add(stop);
      }
    }

    Logger.info('✅ Doublons supprimés: $duplicatesRemoved, restants: ${filtered.length}', 'OverpassService');
    return filtered;
  }

  bool _isCacheValid(String key) {
    if (!_cacheExpiry.containsKey(key)) {
      return false;
    }
    final isValid = DateTime.now().isBefore(_cacheExpiry[key]!);
    if (isValid) {
      final remaining = _cacheExpiry[key]!.difference(DateTime.now());
      Logger.debug('Cache valide: ${remaining.inMinutes}min restantes', 'OverpassService');
    }
    return isValid;
  }

  void clearCache() {
    final stopCount = _stopCache.length;
    final routeCount = _routeCache.length;
    _stopCache.clear();
    _routeCache.clear();
    _cacheExpiry.clear();
    Logger.info('🗑️ Cache vidé: $stopCount arrêts, $routeCount routes', 'OverpassService');
  }

  void dispose() {
    Logger.info('👋 OverpassService disposé', 'OverpassService');
    _client.close();
    clearCache();
  }
}