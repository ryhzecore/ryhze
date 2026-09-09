import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import '../test/interaction_checks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  interactionChecks(native: true);
}
