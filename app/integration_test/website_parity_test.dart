import 'package:integration_test/integration_test.dart';
import 'package:flutter/widgets.dart';
import '../test/website_parity_test.dart' as checks;

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // XCTest enables native accessibility during application launch. Finish the
  // initial frame before testWidgets records its semantics-handle baseline.
  runApp(const SizedBox.shrink());
  await binding.waitUntilFirstFrameRasterized.timeout(
    const Duration(seconds: 30),
  );
  await binding.endOfFrame;
  checks.main();
}
