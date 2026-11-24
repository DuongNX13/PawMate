import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_tokens.dart';
import '../domain/rescue_case_models.dart';
import '../domain/rescue_map_models.dart';

enum RescueTileProvider {
  tomtom,
  osm;

  static RescueTileProvider resolve() {
    const raw = String.fromEnvironment(
      'PAWMATE_MAP_TILES_PROVIDER',
      defaultValue: 'tomtom',
    );
    return switch (raw.toLowerCase()) {
      'osm' || 'openstreetmap' => RescueTileProvider.osm,
      _ => RescueTileProvider.tomtom,
    };
  }
}

typedef RescueMapCanvasBuilder =
    Widget Function(
      RescueMapLocation center,
      List<RescueCaseSummary> items,
      ValueChanged<String> onMarkerTap,
      ValueChanged<Object> onMapUnavailable,
    );

final rescueMapCanvasBuilderProvider = Provider<RescueMapCanvasBuilder>((ref) {
  return (
    RescueMapLocation center,
    List<RescueCaseSummary> items,
    ValueChanged<String> onMarkerTap,
    ValueChanged<Object> onMapUnavailable,
  ) {
    return RescueRasterMapCanvas(
      center: center,
      items: items,
      onMarkerTap: onMarkerTap,
      onMapUnavailable: onMapUnavailable,
    );
  };
});

class RescueRasterMapCanvas extends StatefulWidget {
  const RescueRasterMapCanvas({
    super.key,
    required this.center,
    required this.items,
    required this.onMarkerTap,
    required this.onMapUnavailable,
  });

  final RescueMapLocation center;
  final List<RescueCaseSummary> items;
  final ValueChanged<String> onMarkerTap;
  final ValueChanged<Object> onMapUnavailable;

  @override
  State<RescueRasterMapCanvas> createState() => _RescueRasterMapCanvasState();
}

class _RescueRasterMapCanvasState extends State<RescueRasterMapCanvas> {
  static const _tomTomApiKey = String.fromEnvironment('TOMTOM_MAPS_API_KEY');
  static const _tomTomSubdomains = ['a', 'b', 'c', 'd'];
  static const _defaultZoom = 12.8;
  final MapController _controller = MapController();
  var _tileErrorCount = 0;
  var _reportedUnavailable = false;

  @override
  void didUpdateWidget(covariant RescueRasterMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final centerChanged =
        oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude;
    if (centerChanged) {
      _tileErrorCount = 0;
      _reportedUnavailable = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.move(_centerPoint, _defaultZoom);
        }
      });
    }
  }

  LatLng get _centerPoint =>
      LatLng(widget.center.latitude, widget.center.longitude);

  RescueTileProvider get _provider {
    final configured = RescueTileProvider.resolve();
    if (configured == RescueTileProvider.tomtom && _tomTomApiKey.isEmpty) {
      return RescueTileProvider.osm;
    }
    return configured;
  }

  @override
  Widget build(BuildContext context) {
    final circles = widget.items
        .map(
          (item) => CircleMarker(
            point: LatLng(
              item.publicLocation.approximateLatitude,
              item.publicLocation.approximateLongitude,
            ),
            radius: item.publicLocation.privacyRadiusMeters
                .clamp(500, 3000)
                .toDouble(),
            useRadiusInMeter: true,
            color: AppColors.mint.withValues(alpha: 0.18),
            borderColor: AppColors.deepGreen.withValues(alpha: 0.42),
            borderStrokeWidth: 1,
          ),
        )
        .toList(growable: false);
    final markers = widget.items
        .map(
          (item) => Marker(
            point: LatLng(
              item.publicLocation.approximateLatitude,
              item.publicLocation.approximateLongitude,
            ),
            width: 56,
            height: 64,
            child: Semantics(
              button: true,
              label:
                  'Khu vực ước tính của ${item.petName}, ${item.status.label}, ${item.publicLocation.areaLabel}',
              onTap: () => widget.onMarkerTap(item.caseId),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onMarkerTap(item.caseId),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.deepGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                      boxShadow: AppShadows.soft,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.pets_rounded,
                      color: AppColors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);

    // Figma v0.34 P2-05: the map fills the screen edge to edge.
    return ClipRect(
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: _centerPoint,
          initialZoom: _defaultZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: _tileUrlTemplate,
            subdomains: _tileSubdomains,
            userAgentPackageName: 'com.pawmate.pawmate_mobile',
            maxZoom: 19,
            retinaMode: RetinaMode.isHighDensity(context),
            errorTileCallback: (_, error, _) => _handleTileError(error),
          ),
          CircleLayer(circles: circles),
          MarkerLayer(markers: markers),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    _provider == RescueTileProvider.tomtom
                        ? '(c) TomTom'
                        : '(c) OpenStreetMap contributors',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTileError(Object error) {
    if (_reportedUnavailable) return;
    _tileErrorCount += 1;
    if (_tileErrorCount < 3) return;
    _reportedUnavailable = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMapUnavailable(error);
    });
  }

  String get _tileUrlTemplate {
    return switch (_provider) {
      RescueTileProvider.tomtom =>
        'https://{s}.api.tomtom.com/map/1/tile/basic/'
            'main/{z}/{x}/{y}.png'
            '?key=$_tomTomApiKey&tileSize=512&view=Unified&language=NGT',
      RescueTileProvider.osm =>
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    };
  }

  List<String> get _tileSubdomains {
    return switch (_provider) {
      RescueTileProvider.tomtom => _tomTomSubdomains,
      RescueTileProvider.osm => const [],
    };
  }
}
