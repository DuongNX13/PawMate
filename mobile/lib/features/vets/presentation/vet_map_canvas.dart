import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_tokens.dart';
import '../domain/vet_map_models.dart';
import '../domain/vet_models.dart';

enum VetMapStyle {
  standard,
  night;

  String get tomTomStyle => switch (this) {
    VetMapStyle.standard => 'main',
    VetMapStyle.night => 'night',
  };

  String get label => switch (this) {
    VetMapStyle.standard => 'Bản đồ thường',
    VetMapStyle.night => 'Bản đồ đêm',
  };
}

enum VetTileProvider {
  tomtom,
  osm;

  static VetTileProvider resolve() {
    const raw = String.fromEnvironment(
      'PAWMATE_MAP_TILES_PROVIDER',
      defaultValue: 'tomtom',
    );
    return switch (raw.toLowerCase()) {
      'osm' || 'openstreetmap' => VetTileProvider.osm,
      _ => VetTileProvider.tomtom,
    };
  }
}

typedef VetMapCanvasBuilder =
    Widget Function(
      VetMapLocation center,
      List<VetSummary> items,
      VetMapStyle mapStyle,
      ValueChanged<String> onMarkerTap,
    );

final vetMapCanvasBuilderProvider = Provider<VetMapCanvasBuilder>((ref) {
  return (
    VetMapLocation center,
    List<VetSummary> items,
    VetMapStyle mapStyle,
    ValueChanged<String> onMarkerTap,
  ) {
    return VetRasterMapCanvas(
      center: center,
      items: items,
      mapStyle: mapStyle,
      onMarkerTap: onMarkerTap,
    );
  };
});

class VetRasterMapCanvas extends StatefulWidget {
  const VetRasterMapCanvas({
    super.key,
    required this.center,
    required this.items,
    required this.mapStyle,
    required this.onMarkerTap,
  });

  final VetMapLocation center;
  final List<VetSummary> items;
  final VetMapStyle mapStyle;
  final ValueChanged<String> onMarkerTap;

  @override
  State<VetRasterMapCanvas> createState() => _VetRasterMapCanvasState();
}

class _VetRasterMapCanvasState extends State<VetRasterMapCanvas> {
  static const _tomTomApiKey = String.fromEnvironment('TOMTOM_MAPS_API_KEY');
  static const _tomTomSubdomains = ['a', 'b', 'c', 'd'];
  static const _defaultZoom = 13.6;

  final MapController _controller = MapController();

  @override
  void didUpdateWidget(covariant VetRasterMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final centerChanged =
        oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude;
    final mapStyleChanged = oldWidget.mapStyle != widget.mapStyle;

    if (centerChanged || mapStyleChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _controller.move(_centerPoint, _defaultZoom);
      });
    }
  }

  LatLng get _centerPoint =>
      LatLng(widget.center.latitude, widget.center.longitude);

  VetTileProvider get _provider {
    final configured = VetTileProvider.resolve();
    if (configured == VetTileProvider.tomtom && _tomTomApiKey.isEmpty) {
      return VetTileProvider.osm;
    }
    return configured;
  }

  @override
  Widget build(BuildContext context) {
    final markerWidgets = widget.items
        .where((item) => item.latitude != null && item.longitude != null)
        .map(
          (item) => Marker(
            point: LatLng(item.latitude!, item.longitude!),
            width: 46,
            height: 54,
            child: Semantics(
              button: true,
              label: 'Mở ${item.name}',
              child: GestureDetector(
                onTap: () => widget.onMarkerTap(item.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.is24h == true
                            ? AppColors.primary500
                            : const Color(0xFFE85D9B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: AppShadows.soft,
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        children: [
          FlutterMap(
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
              ),
              MarkerLayer(markers: markerWidgets),
            ],
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Text(
                  _provider == VetTileProvider.tomtom
                      ? '(c) TomTom'
                      : '(c) OpenStreetMap contributors',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _tileUrlTemplate {
    return switch (_provider) {
      VetTileProvider.tomtom =>
        'https://{s}.api.tomtom.com/map/1/tile/basic/'
            '${widget.mapStyle.tomTomStyle}/{z}/{x}/{y}.png'
            '?key=$_tomTomApiKey&tileSize=512&view=Unified&language=NGT',
      VetTileProvider.osm => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    };
  }

  List<String> get _tileSubdomains {
    return switch (_provider) {
      VetTileProvider.tomtom => _tomTomSubdomains,
      VetTileProvider.osm => const [],
    };
  }
}
