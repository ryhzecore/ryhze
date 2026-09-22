import 'package:integration_test/integration_test.dart';
import '../test/race_card_test.dart' as race;
import '../test/detail_consistency_test.dart' as details;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  race.main();
  details.main();
}
