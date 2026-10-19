import 'package:flutter/material.dart';

/// Representasi Koordinat Geospasial
class MapLatLng {
  final double latitude;
  final double longitude;

  const MapLatLng(this.latitude, this.longitude);

  @override
  String toString() => 'MapLatLng($latitude, $longitude)';
}

/// Tipe Marker / Pin pada Peta
enum MapMarkerType {
  jobLocation,
  tukangCurrentLocation,
  userLocation,
}

/// Data Marker Peta
class BeresMapMarker {
  final String id;
  final MapLatLng position;
  final MapMarkerType type;
  final String? title;
  final VoidCallback? onTap;

  const BeresMapMarker({
    required this.id,
    required this.position,
    required this.type,
    this.title,
    this.onTap,
  });
}

/// Interface Adapter Peta (NFR-15: OpenStreetMap MVP -> Google Maps Phase 2)
abstract class MapProviderAdapter {
  Widget buildMap({
    required BuildContext context,
    required MapLatLng initialCenter,
    double initialZoom = 15.0,
    List<BeresMapMarker> markers = const [],
    void Function(MapLatLng newCenter)? onCenterChanged,
    void Function(MapLatLng tappedPoint)? onTap,
    bool interactive = true,
  });
}

/// Implementasi Default / Mock Adapter untuk testing & MVP
class DefaultMapProviderAdapter implements MapProviderAdapter {
  const DefaultMapProviderAdapter();

  @override
  Widget buildMap({
    required BuildContext context,
    required MapLatLng initialCenter,
    double initialZoom = 15.0,
    List<BeresMapMarker> markers = const [],
    void Function(MapLatLng newCenter)? onCenterChanged,
    void Function(MapLatLng tappedPoint)? onTap,
    bool interactive = true,
  }) {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 48, color: Color(0xFF64748B)),
                const SizedBox(height: 8),
                Text(
                  'Map (${initialCenter.latitude.toStringAsFixed(4)}, ${initialCenter.longitude.toStringAsFixed(4)})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                Text(
                  'Markers: ${markers.length} | Zoom: ${initialZoom.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          if (markers.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xE6FFFFFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${markers.length} Active Marker(s)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget Peta Beres (BeresMapView) yang membungkus adapter
class BeresMapView extends StatelessWidget {
  final MapLatLng initialCenter;
  final double initialZoom;
  final List<BeresMapMarker> markers;
  final void Function(MapLatLng newCenter)? onCenterChanged;
  final void Function(MapLatLng tappedPoint)? onTap;
  final bool interactive;
  final MapProviderAdapter adapter;

  const BeresMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 15.0,
    this.markers = const [],
    this.onCenterChanged,
    this.onTap,
    this.interactive = true,
    this.adapter = const DefaultMapProviderAdapter(),
  });

  @override
  Widget build(BuildContext context) {
    return adapter.buildMap(
      context: context,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      markers: markers,
      onCenterChanged: onCenterChanged,
      onTap: onTap,
      interactive: interactive,
    );
  }
}
