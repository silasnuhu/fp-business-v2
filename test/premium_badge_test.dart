import 'package:flutter_test/flutter_test.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('users/batch premiumUser drives the verified badge set', () {
    final service = ContactNameService.instance;
    // Shape of one `users/batch` item.
    service.noteUserProfile({'userId': 4, 'fullName': 'James', 'premiumUser': true});
    service.noteUserProfile({'userId': 3057, 'fullName': 'AZ', 'premiumUser': false});
    expect(service.isPremiumUser(4), isTrue);
    expect(service.isPremiumUser(3057), isFalse);

    // Flag lost later -> tick disappears; a payload without the key keeps it.
    service.noteUserProfile({'userId': 4, 'fullName': 'James'});
    expect(service.isPremiumUser(4), isTrue);
    service.noteUserProfile({'userId': 4, 'premiumUser': false});
    expect(service.isPremiumUser(4), isFalse);

    // Deleted accounts never show a tick.
    service.noteUserProfile({'userId': 9, 'premiumUser': true});
    service.noteUserProfile({'userId': 9, 'isDeleted': true});
    expect(service.isPremiumUser(9), isFalse);
  });
}
