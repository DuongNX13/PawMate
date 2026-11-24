import 'package:flutter/material.dart';

/// Single-line screen title that scales down instead of ellipsizing when large
/// text leaves too little width (D122-TB-P2-005, Android Notifications
/// stress). Screen titles are short, so shrinking keeps every word readable.
class PawMateFitTitle extends StatelessWidget {
  const PawMateFitTitle(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(text, maxLines: 1, softWrap: false, style: style),
  );
}
