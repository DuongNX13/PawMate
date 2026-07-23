import 'dart:io';

import 'package:flutter/material.dart';

class PetAvatarMedia extends StatelessWidget {
  const PetAvatarMedia({
    super.key,
    required this.source,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String? source;
  final Widget fallback;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final value = source?.trim();
    if (value == null || value.isEmpty) {
      return _withSemantics(fallback);
    }

    final Widget image;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      image = Image.network(
        value,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (value.startsWith('assets/')) {
      image = Image.asset(
        value,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      final file = File(value);
      if (!file.existsSync()) {
        return _withSemantics(fallback);
      }
      image = Image.file(
        file,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return _withSemantics(image);
  }

  Widget _withSemantics(Widget child) {
    return semanticLabel == null
        ? ExcludeSemantics(child: child)
        : Semantics(image: true, label: semanticLabel, child: child);
  }
}
