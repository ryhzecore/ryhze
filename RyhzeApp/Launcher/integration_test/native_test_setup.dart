import 'package:flutter_test/flutter_test.dart';

/// XCTest may enable accessibility after launch, during the first Dart test.
/// Establish the platform-owned handle before testWidgets records its baseline.
/// Keep semantics enabled (including leak checks) throughout the suite.
void configureNativeSemantics(TestWidgetsFlutterBinding binding) {
  binding.platformDispatcher.semanticsEnabledTestValue = true;
  tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);
}
