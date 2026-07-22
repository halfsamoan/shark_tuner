import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const ibmPlexLicenseAsset = 'assets/fonts/licenses/IBM-Plex-OFL-1.1.txt';
const jetBrainsMonoLicenseAsset =
    'assets/fonts/licenses/JetBrains-Mono-OFL-1.1.txt';

void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'IBM Plex Mono',
      'IBM Plex Sans KR',
    ], await rootBundle.loadString(ibmPlexLicenseAsset));
    yield LicenseEntryWithLineBreaks(const [
      'JetBrains Mono',
    ], await rootBundle.loadString(jetBrainsMonoLicenseAsset));
  });
}
