import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/app/bundled_font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ships the approved IBM Plex weights and OFL license', () async {
    for (final asset in [
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
      'assets/fonts/IBMPlexMono-Bold.ttf',
      'assets/fonts/IBMPlexSansKR-Regular.ttf',
      'assets/fonts/IBMPlexSansKR-Medium.ttf',
      'assets/fonts/IBMPlexSansKR-SemiBold.ttf',
      'assets/fonts/IBMPlexSansKR-Bold.ttf',
    ]) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(100_000), reason: asset);
    }

    final license = await rootBundle.loadString(ibmPlexLicenseAsset);
    expect(license, contains('IBM Corp'));
    expect(license, contains('SIL OPEN FONT LICENSE'));
  });
}
