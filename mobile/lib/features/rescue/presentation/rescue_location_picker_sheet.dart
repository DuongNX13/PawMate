import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../data/rescue_location_service.dart';
import '../domain/rescue_draft_models.dart';
import 'rescue_map_canvas.dart';

typedef RescuePickerMapBuilder =
    Widget Function(
      RescueDraftLocation? selected,
      ValueChanged<RescueDraftLocation> onSelect,
      VoidCallback onUnavailable,
    );

final rescuePickerMapBuilderProvider = Provider<RescuePickerMapBuilder>(
  (ref) =>
      (selected, onSelect, onUnavailable) => RescueLocationPickerMap(
        selected: selected,
        onSelect: onSelect,
        onUnavailable: onUnavailable,
      ),
);

/// The selected point remains local until the owner explicitly confirms.
class RescueLocationPickerSheet extends ConsumerStatefulWidget {
  const RescueLocationPickerSheet({super.key, this.initialLocation});
  final RescueDraftLocation? initialLocation;
  @override
  ConsumerState<RescueLocationPickerSheet> createState() =>
      _RescueLocationPickerSheetState();
}

class _RescueLocationPickerSheetState
    extends ConsumerState<RescueLocationPickerSheet> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _address = TextEditingController();
  RescueDraftLocation? _selected;
  bool _loading = false;
  bool _mapUnavailable = false;
  bool _coordinatesEdited = false;
  String? _error;
  int _request = 0;
  int _mapGeneration = 0;
  RescueLocationRequest? _locationRequest;
  bool _gpsInFlight = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation;
    if (initial != null && initial.isValid) {
      _selected = initial;
      _latitude.text = initial.latitude.toString();
      _longitude.text = initial.longitude.toString();
      _address.text = initial.formattedAddress ?? '';
    }
  }

  @override
  void dispose() {
    _locationRequest?.cancel();
    _latitude.dispose();
    _longitude.dispose();
    _address.dispose();
    super.dispose();
  }

  void _select(RescueDraftLocation value) {
    if (!value.isValid) return;
    _locationRequest?.cancel();
    _request++;
    setState(() {
      _selected = value;
      _loading = false;
      _coordinatesEdited = false;
      _error = null;
      _latitude.text = value.latitude.toString();
      _longitude.text = value.longitude.toString();
      _address.text = value.formattedAddress ?? '';
    });
  }

  void _onCoordinateEdit(String _) {
    _locationRequest?.cancel();
    _request++;
    setState(() {
      _coordinatesEdited = true;
      _loading = false;
    });
  }

  Future<void> _locate() async {
    if (_gpsInFlight) return;
    final request = ++_request;
    final lifecycle = RescueLocationRequest(id: request);
    _locationRequest = lifecycle;
    setState(() {
      _gpsInFlight = true;
      _loading = true;
      _error = null;
    });
    try {
      final point = await ref
          .read(rescueLocationServiceProvider)
          .resolveCurrentLocation(request: lifecycle);
      if (!mounted || request != _request) return;
      final selection = RescueDraftLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!selection.isValid) throw const FormatException('Invalid location');
      _select(selection);
    } catch (error) {
      if (!mounted || request != _request || lifecycle.isCancelled) return;
      setState(() {
        _loading = false;
        _error = switch (error) {
          RescueLocationException(
            type: RescueLocationFailureType.permissionDenied,
          ) =>
            'Chưa có quyền định vị. Bạn vẫn có thể chạm bản đồ hoặc nhập tọa độ.',
          RescueLocationException(
            type: RescueLocationFailureType.serviceDisabled,
          ) =>
            'Định vị đang tắt. Hãy chọn trên bản đồ hoặc nhập tọa độ.',
          _ =>
            'Chưa lấy được vị trí. Bạn có thể thử lại hoặc nhập tọa độ thủ công.',
        };
      });
    } finally {
      if (mounted) setState(() => _gpsInFlight = false);
    }
  }

  void _applyCoordinates() {
    final lat = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
    final point = lat == null || lon == null
        ? null
        : RescueDraftLocation(
            latitude: lat,
            longitude: lon,
            formattedAddress: _address.text.trim(),
          );
    if (point == null || !point.isValid) {
      setState(
        () => _error = 'Nhập vĩ độ từ −90 đến 90 và kinh độ từ −180 đến 180.',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _select(point);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _selected != null && !_coordinatesEdited && !_loading;
    final mapBuilder = ref.watch(rescuePickerMapBuilderProvider);
    return FractionallySizedBox(
      heightFactor: .94,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const Key('rescue-location-picker'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Chọn khu vực thất lạc', style: AppTextStyles.h3()),
              ),
              const SizedBox(height: 8),
              Text(
                'Chạm bản đồ để đặt ghim tại nơi bé thất lạc. Vị trí chính xác chỉ lưu riêng cho chủ tin; cộng đồng chỉ thấy khu vực ước tính.',
                style: AppTextStyles.bodyCompact(),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? 210
                      : 260,
                  child: _mapUnavailable
                      ? ColoredBox(
                          color: AppColors.surfaceContainer,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Bản đồ chưa tải được. Nhập tọa độ bên dưới để tiếp tục.',
                                style: AppTextStyles.bodyCompact(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      : KeyedSubtree(
                          key: ValueKey(_mapGeneration),
                          child: mapBuilder(_selected, _select, () {
                            if (mounted && !_mapUnavailable) {
                              setState(() => _mapUnavailable = true);
                            }
                          }),
                        ),
                ),
              ),
              if (_mapUnavailable)
                TextButton(
                  key: const Key('rescue-location-retry-map'),
                  onPressed: () => setState(() {
                    _mapUnavailable = false;
                    _mapGeneration++;
                  }),
                  child: const Text('Thử tải lại bản đồ'),
                ),
              const SizedBox(height: 12),
              PawMateButton(
                key: const Key('rescue-location-gps'),
                label: 'Dùng khu vực hiện tại',
                variant: PawMateButtonVariant.secondary,
                isLoading: _loading,
                onPressed: _loading || _gpsInFlight ? null : _locate,
                leadingIcon: Icons.my_location,
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      key: const Key('rescue-location-error'),
                      style: AppTextStyles.bodyCompact(color: AppColors.error),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Nhập tọa độ thủ công', style: AppTextStyles.h4()),
              const SizedBox(height: 8),
              Text(
                'Dùng khi không có quyền định vị hoặc mất kết nối. Tọa độ này không hiển thị công khai.',
                style: AppTextStyles.caption(),
              ),
              const SizedBox(height: 12),
              PawMateTextField(
                key: const Key('rescue-location-latitude'),
                label: 'Vĩ độ',
                controller: _latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: _onCoordinateEdit,
              ),
              const SizedBox(height: 12),
              PawMateTextField(
                key: const Key('rescue-location-longitude'),
                label: 'Kinh độ',
                controller: _longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: _onCoordinateEdit,
              ),
              const SizedBox(height: 12),
              PawMateTextField(
                key: const Key('rescue-location-address'),
                label: 'Địa chỉ gợi nhớ (không bắt buộc)',
                controller: _address,
                maxLines: 2,
                maxLength: 500,
              ),
              TextButton(
                key: const Key('rescue-location-apply'),
                onPressed: _applyCoordinates,
                child: const Text('Áp dụng tọa độ'),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  _coordinatesEdited
                      ? 'Hãy áp dụng tọa độ mới trước khi xác nhận.'
                      : _selected == null
                      ? 'Chưa chọn vị trí.'
                      : 'Đã chọn vị trí. Kiểm tra ghim trước khi xác nhận.',
                  style: AppTextStyles.bodyCompact(),
                ),
              ),
              const SizedBox(height: 16),
              PawMateButton(
                key: const Key('rescue-location-confirm'),
                label: 'Xác nhận vị trí',
                onPressed: !canConfirm
                    ? null
                    : () {
                        final point = _selected!;
                        Navigator.of(context).pop(
                          RescueDraftLocation(
                            latitude: point.latitude,
                            longitude: point.longitude,
                            formattedAddress: _address.text.trim().isEmpty
                                ? null
                                : _address.text.trim(),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 8),
              PawMateButton(
                key: const Key('rescue-location-cancel'),
                label: 'Hủy',
                variant: PawMateButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live raster map. The world camera is only a viewport, never a draft value.
/// Tests inject a deterministic canvas through rescuePickerMapBuilderProvider.
class RescueLocationPickerMap extends StatefulWidget {
  const RescueLocationPickerMap({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onUnavailable,
  });
  final RescueDraftLocation? selected;
  final ValueChanged<RescueDraftLocation> onSelect;
  final VoidCallback onUnavailable;
  @override
  State<RescueLocationPickerMap> createState() =>
      _RescueLocationPickerMapState();
}

class _RescueLocationPickerMapState extends State<RescueLocationPickerMap> {
  final _controller = MapController();
  static const _tomTomKey = String.fromEnvironment('TOMTOM_MAPS_API_KEY');
  int _errors = 0;
  bool _reported = false;
  bool get _tomtom =>
      RescueTileProvider.resolve() == RescueTileProvider.tomtom &&
      _tomTomKey.isNotEmpty;
  @override
  void didUpdateWidget(covariant RescueLocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final point = widget.selected;
    if (point != null &&
        (point.latitude != oldWidget.selected?.latitude ||
            point.longitude != oldWidget.selected?.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.move(LatLng(point.latitude, point.longitude), 16);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tap(TapPosition _, LatLng point) => widget.onSelect(
    RescueDraftLocation(
      latitude: point.latitude,
      longitude: ((point.longitude + 180) % 360 + 360) % 360 - 180,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final point = widget.selected;
    return FlutterMap(
      mapController: _controller,
      options: point == null
          ? MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.worldSafe(
                  north: 80,
                  south: -80,
                  longitudeCenter: 0,
                  longitudeWidth: 360,
                ),
              ),
              onTap: _tap,
              maxZoom: 19,
            )
          : MapOptions(
              initialCenter: LatLng(point.latitude, point.longitude),
              initialZoom: 16,
              maxZoom: 19,
              onTap: _tap,
            ),
      children: [
        TileLayer(
          urlTemplate: _tomtom
              ? 'https://{s}.api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$_tomTomKey&tileSize=512&view=Unified&language=NGT'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: _tomtom ? const ['a', 'b', 'c', 'd'] : const [],
          userAgentPackageName: 'com.pawmate.pawmate_mobile',
          maxZoom: 19,
          errorTileCallback: (_, _, _) {
            if (_reported || ++_errors < 3) return;
            _reported = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onUnavailable();
            });
          },
        ),
        if (point != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(point.latitude, point.longitude),
                width: 48,
                height: 48,
                child: Semantics(
                  label: 'Vị trí riêng tư đang chọn',
                  child: const Icon(
                    Icons.location_pin,
                    color: AppColors.deepGreen,
                    size: 48,
                  ),
                ),
              ),
            ],
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: ColoredBox(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                _tomtom ? '© TomTom' : '© OpenStreetMap contributors',
                style: AppTextStyles.caption(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
