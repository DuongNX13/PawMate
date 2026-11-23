// QA-only binding setup. Never dispatches a gesture or semantics action.
import 'package:flutter_test/flutter_test.dart';

void configureDay122PassiveBinding(LiveTestWidgetsFlutterBinding binding) {
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.shouldPropagateDevicePointerEvents = true;
}
