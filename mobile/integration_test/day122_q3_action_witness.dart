import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/semantics.dart';

/// A QA-only observer of engine-delivered semantics action requests. It does
/// not create an action, consume it, change focus, or read gesture arguments.
class Day122Q3ActionWitness {
  Day122Q3ActionWitness({required String run, required File sink,
    required SemanticsNode? Function(int) root, required String Function() route})
    : _dispatcher = ui.PlatformDispatcher.instance {
    _previous = _dispatcher.onSemanticsActionEvent;
    if (_previous == null || sink.existsSync()) {
      throw StateError('Semantics dispatcher and fresh witness required');
    }
    _dispatcher.onSemanticsActionEvent = (event) {
      try {
        if (event.type == ui.SemanticsAction.tap) {
          final node = _find(root(event.viewId), event.nodeId);
          final data = node?.getSemanticsData();
          final record = <String, Object?>{
            'run': run,
            'case_id': 'TB-HOME-PET',
            'pid': pid,
            'type': 'ENGINE_SEMANTICS_TAP',
            'node_id': event.nodeId,
            'view_id': event.viewId,
            'label': data?.label,
            'tooltip': data?.tooltip,
            'supports_tap': data?.hasAction(ui.SemanticsAction.tap),
            'route_before': route(),
            'device_wall_ms': DateTime.now().millisecondsSinceEpoch,
          };
          sink.writeAsStringSync('${jsonEncode(record)}\n',
            mode: FileMode.append, flush: true);
        }
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      } finally {
        _previous(event);
      }
    };
  }

  final ui.PlatformDispatcher _dispatcher;
  late final ui.SemanticsActionEventCallback? _previous;
  Object? failure;
  StackTrace? failureStack;

  void dispose() => _dispatcher.onSemanticsActionEvent = _previous;

  static SemanticsNode? _find(SemanticsNode? root, int id) {
    if (root == null || root.id == id) return root;
    SemanticsNode? result;
    root.visitChildren((node) {
      result = _find(node, id);
      return result == null;
    });
    return result;
  }
}
