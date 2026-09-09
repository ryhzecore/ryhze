import 'package:integration_test/integration_test.dart';
import '../test/sign_in_test.dart' as auth;
import '../test/card_hover_test.dart' as hover;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  auth.main();
  hover.main();
}
