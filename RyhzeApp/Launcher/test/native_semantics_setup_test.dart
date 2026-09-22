import 'package:flutter_test/flutter_test.dart';
import '../integration_test/native_test_setup.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  configureNativeSemantics(binding);

  testWidgets('late platform accessibility notifications preserve baseline', (
    tester,
  ) async {
    final before = binding.debugOutstandingSemanticsHandles;
    expect(binding.semanticsEnabled, isTrue);
    // Reproduce the platform notification that previously arrived after XCTest
    // launched the app. It must reuse the existing platform-owned handle.
    binding.platformDispatcher.onSemanticsEnabledChanged?.call();
    binding.platformDispatcher.onSemanticsEnabledChanged?.call();
    expect(binding.debugOutstandingSemanticsHandles, before);
    final owned = tester.ensureSemantics();
    expect(binding.debugOutstandingSemanticsHandles, before + 1);
    owned.dispose();
    expect(binding.debugOutstandingSemanticsHandles, before);
  });
}
