import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../domain/rescue_case_models.dart';

class RescueMapPreview extends StatelessWidget {
  const RescueMapPreview({
    super.key,
    required this.items,
    required this.onOpenMap,
    this.backgroundAsset,
    this.selectedCaseId,
    this.onSelectCase,
  });

  final List<RescueCaseSummary> items;
  final VoidCallback onOpenMap;
  final String? backgroundAsset;
  final String? selectedCaseId;
  final ValueChanged<RescueCaseSummary>? onSelectCase;

  @override
  Widget build(BuildContext context) {
    final area = _commonArea(items);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final mapHeight = viewportWidth <= 360
        ? 208.0
        : viewportWidth >= 430
        ? 252.0
        : 240.0;
    final borderRadius = backgroundAsset == null
        ? BorderRadius.circular(AppRadius.mapPreview)
        : BorderRadius.zero;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label:
          'Bản đồ khu vực ước tính gần ${area.isEmpty ? 'khu vực của bạn' : area}, ${items.length} ca cứu hộ. Nhấn để mở bản đồ.',
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          key: const Key('rescue-map-preview'),
          onTap: onOpenMap,
          borderRadius: borderRadius,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: SizedBox(
              height: mapHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (backgroundAsset == null) ...[
                    CustomPaint(
                      painter: _RescueMapPainter(
                        markerCount: items.length,
                        seed: area.hashCode,
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.s16,
                      top: AppSpacing.s12,
                      child: _MapPill(label: 'Khu vực ước tính • công khai'),
                    ),
                    Positioned(
                      right: AppSpacing.s12,
                      bottom: AppSpacing.s12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.mint),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s8,
                          ),
                          child: Text(
                            'Xem bản đồ',
                            style: AppTextStyles.captionStrong(
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Image.asset(
                      backgroundAsset!,
                      fit: BoxFit.cover,
                      semanticLabel:
                          'Bản đồ khu vực ước tính, ${items.length} ca cứu hộ',
                      errorBuilder: (context, error, stackTrace) => CustomPaint(
                        painter: _RescueMapPainter(
                          markerCount: items.length,
                          seed: area.hashCode,
                        ),
                      ),
                    ),
                  if (onSelectCase != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final points = _markerPoints(
                          constraints.biggest,
                          items.length,
                          area.hashCode,
                        );
                        return Stack(
                          children: [
                            for (var index = 0; index < points.length; index++)
                              Positioned(
                                left: points[index].dx - 24,
                                top: points[index].dy - 24,
                                child: Semantics(
                                  key: ValueKey(
                                    'rescue-marker-${items[index].caseId}',
                                  ),
                                  button: true,
                                  onTap: () => onSelectCase!(items[index]),
                                  selected:
                                      items[index].caseId == selectedCaseId,
                                  label:
                                      'Chọn ca ${items[index].petName}, ${items[index].status.label}, khu vực ước tính ${items[index].publicLocation.areaLabel}',
                                  child: ExcludeSemantics(
                                    child: Tooltip(
                                      message: items[index].petName,
                                      child: InkWell(
                                        onTap: () =>
                                            onSelectCase!(items[index]),
                                        borderRadius: BorderRadius.circular(24),
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border:
                                                items[index].caseId ==
                                                    selectedCaseId
                                                ? Border.all(
                                                    color: AppColors.deepGreen,
                                                    width: 3,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _commonArea(List<RescueCaseSummary> values) {
    if (values.isEmpty) return 'empty';
    return values.first.publicLocation.areaLabel;
  }
}

class _MapPill extends StatelessWidget {
  const _MapPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.mint),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 16, color: AppColors.deepGreen),
            const SizedBox(width: AppSpacing.s4),
            Text(label, style: AppTextStyles.captionStrong()),
          ],
        ),
      ),
    );
  }
}

class _RescueMapPainter extends CustomPainter {
  const _RescueMapPainter({required this.markerCount, required this.seed});

  final int markerCount;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = AppColors.mapLand;
    canvas.drawRect(Offset.zero & size, background);

    final grid = Paint()
      ..color = AppColors.mapGrid
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width + size.height; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), grid);
    }
    for (var y = 14.0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 10), grid);
    }

    final river = Paint()
      ..color = AppColors.mapWater
      ..style = PaintingStyle.fill;
    final riverPath = Path()
      ..moveTo(size.width * .69, -8)
      ..cubicTo(
        size.width * .49,
        size.height * .24,
        size.width * .82,
        size.height * .48,
        size.width * .61,
        size.height + 8,
      )
      ..lineTo(size.width * .77, size.height + 8)
      ..cubicTo(
        size.width * .95,
        size.height * .52,
        size.width * .65,
        size.height * .25,
        size.width * .83,
        -8,
      )
      ..close();
    canvas.drawPath(riverPath, river);

    final road = Paint()
      ..color = AppColors.mapRoute
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final roadPath = Path()
      ..moveTo(-8, size.height * .65)
      ..cubicTo(
        size.width * .22,
        size.height * .45,
        size.width * .48,
        size.height * .77,
        size.width + 8,
        size.height * .35,
      );
    canvas.drawPath(roadPath, road);

    for (final point in _markerPoints(size, markerCount, seed)) {
      final uncertainty = Paint()
        ..color = AppColors.mint.withValues(alpha: 0.26)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 22, uncertainty);
      final marker = Paint()..color = AppColors.deepGreen;
      canvas.drawCircle(point, 8, marker);
      final center = Paint()..color = AppColors.surface;
      canvas.drawCircle(point, 3, center);
    }
  }

  @override
  bool shouldRepaint(covariant _RescueMapPainter oldDelegate) =>
      oldDelegate.markerCount != markerCount || oldDelegate.seed != seed;
}

// Shared geometry keeps native 48dp hit targets centered on the preview dots.
// This is an approximate schematic, not a precise geographic map.
List<Offset> _markerPoints(Size size, int count, int seed) {
  if (count > 3) {
    // A five-case preview needs separated targets; wrapping the old index
    // formula places the fifth marker over the first at compact widths.
    const positions = [
      Offset(.2, .36),
      Offset(.5, .36),
      Offset(.8, .36),
      Offset(.35, .7),
      Offset(.65, .7),
    ];
    return positions
        .take(math.min(count, 5))
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList(growable: false);
  }
  final random = math.Random(seed.abs());
  return [
    for (var index = 0; index < math.min(count, 5); index++)
      Offset(
        size.width * (.16 + ((index * .17) % .68)) +
            random.nextDouble() * 10 -
            5,
        size.height * (.36 + ((index * .11) % .34)) +
            random.nextDouble() * 10 -
            5,
      ),
  ];
}
