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
  });

  final List<RescueCaseSummary> items;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final area = _commonArea(items);
    return Semantics(
      container: true,
      button: true,
      label:
          'Bản đồ khu vực ước tính gần ${area.isEmpty ? 'khu vực của bạn' : area}, ${items.length} ca cứu hộ. Nhấn để mở bản đồ.',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.mapPreview),
        child: InkWell(
          key: const Key('rescue-map-preview'),
          onTap: onOpenMap,
          borderRadius: BorderRadius.circular(AppRadius.mapPreview),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.mapPreview),
            child: SizedBox(
              height: 178,
              child: Stack(
                fit: StackFit.expand,
                children: [
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
    final background = Paint()..color = const Color(0xFFE7E8D9);
    canvas.drawRect(Offset.zero & size, background);

    final grid = Paint()
      ..color = const Color(0xFFB9C8B2)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width + size.height; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), grid);
    }
    for (var y = 14.0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 10), grid);
    }

    final river = Paint()
      ..color = const Color(0xFFD2DCD7)
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
      ..color = const Color(0xFFB87858)
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

    final random = math.Random(seed.abs());
    final count = math.min(markerCount, 5);
    for (var index = 0; index < count; index++) {
      final x = size.width * (.16 + ((index * .17) % .68));
      final y = size.height * (.36 + ((index * .11) % .34));
      final point = Offset(
        x + (random.nextDouble() * 10 - 5),
        y + (random.nextDouble() * 10 - 5),
      );
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
