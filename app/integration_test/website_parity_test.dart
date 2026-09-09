import 'package:integration_test/integration_test.dart';
import '../test/website_parity_test.dart' as checks;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  checks.main();
}
