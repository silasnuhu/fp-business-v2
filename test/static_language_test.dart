import 'package:flutter_test/flutter_test.dart';
import 'package:whoxa/featuers/language_method/data/repository/language_repo.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('static language list has 5 languages, English last for reversed UI', () async {
    final repo = LanguageRepository(null);
    final result = await repo.langListRepo();
    expect(result.data!.records.length, 5);
    expect(result.data!.records.last.language, 'English');
    expect(result.data!.records.first.language, 'العربية');
    expect(
      result.data!.records.firstWhere((r) => r.language == 'العربية').languageAlignment,
      'RTL',
    );
  });

  test('wordListRepo loads bundled Spanish translations', () async {
    final repo = LanguageRepository(null);
    final result = await repo.wordListRepo(languageId: '2');
    expect(result.status, true);
    expect(result.data!.records!.isNotEmpty, true);
    final welcome = result.data!.records!.firstWhere((r) => r.key == 'Welcome');
    expect(welcome.translation, 'Bienvenido');
  });

  test('wordListRepo loads bundled Arabic translations', () async {
    final repo = LanguageRepository(null);
    final result = await repo.wordListRepo(languageId: '5');
    expect(result.status, true);
    final login = result.data!.records!.firstWhere((r) => r.key == 'Login');
    expect(login.translation, 'تسجيل الدخول');
  });

  test('LanguageProvider.textTranslate resolves through loaded map', () async {
    final provider = LanguageProvider(LanguageRepository(null));
    await provider.languageListApi();
    expect(provider.languageListData.length, 5);

    final success = await provider.wordListApi(languageId: '3');
    expect(success, true);
    expect(provider.textTranslate('Login'), 'Connexion');
    expect(provider.textTranslate('Some key that does not exist'), 'Some key that does not exist');
  });

  test('AppString.tr and trParams resolve generic call-site strings', () async {
    final provider = LanguageProvider(LanguageRepository(null));
    await provider.languageListApi();
    AppString.initStrings(provider);

    await provider.wordListApi(languageId: '5'); // Arabic
    expect(AppString.tr('Just now'), 'الآن');
    expect(
      AppString.trParams('{name} left the group', {'name': 'Sam'}),
      'غادر Sam المجموعة',
    );
    expect(AppString.tr('Not a real key anywhere'), 'Not a real key anywhere');
  });
}
