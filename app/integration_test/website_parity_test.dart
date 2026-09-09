import 'package:integration_test/integration_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/website_parity_test.dart' as checks;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // XCTest enables native accessibility during application launch. Finish the
  // initial frame before testWidgets records its semantics-handle baseline.
  setUpAll(() async {
    final previousPolicy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    try {
      runApp(const SizedBox.shrink());
      await binding.waitUntilFirstFrameRasterized.timeout(
        const Duration(seconds: 30),
      );
      await binding.endOfFrame.timeout(const Duration(seconds: 30));
    } finally {
      binding.framePolicy = previousPolicy;
    }
  });
  checks.main();
}
