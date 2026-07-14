import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/bundled_font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ships the four approved font weights and their OFL licenses', () async {
    for (final asset in [
      'assets/fonts/D2Coding-Regular.ttf',
      'assets/fonts/D2Coding-Bold.ttf',
      'assets/fonts/Pretendard-Regular.otf',
      'assets/fonts/Pretendard-SemiBold.otf',
    ]) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(1_000_000), reason: asset);
    }

    final d2License = await rootBundle.loadString(d2CodingLicenseAsset);
    expect(d2License, contains('NAVER Corporation'));
    expect(d2License, contains('SIL OPEN FONT LICENSE'));

    final pretendardLicense = await rootBundle.loadString(
      pretendardLicenseAsset,
    );
    expect(pretendardLicense, contains('Kil Hyung-jin'));
    expect(pretendardLicense, contains('SIL Open Font License'));
  });
}
