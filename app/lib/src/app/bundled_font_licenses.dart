import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const d2CodingLicenseAsset = 'assets/fonts/licenses/D2Coding-OFL-1.1.txt';
const pretendardLicenseAsset = 'assets/fonts/licenses/Pretendard-OFL-1.1.txt';

void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'D2Coding',
    ], await rootBundle.loadString(d2CodingLicenseAsset));
    yield LicenseEntryWithLineBreaks(const [
      'Pretendard',
    ], await rootBundle.loadString(pretendardLicenseAsset));
  });
}
