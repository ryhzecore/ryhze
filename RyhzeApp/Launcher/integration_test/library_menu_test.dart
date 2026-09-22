import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import '../test/engine_dropdown_test.dart' as dropdown;
import '../test/engine_demo_test.dart' as versions;
import '../test/big_picture_menu_test.dart' as menu;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  dropdown.main();
  versions.main();
  menu.main();
}
