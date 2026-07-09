/// Non-web stand-ins — the app isn't running in a browser.
bool canInstallPwa() => false;

Future<bool> promptInstallPwa() async => false;

bool isIosBrowser() => false;

bool isAndroidBrowser() => false;

bool isStandalonePwa() => false;

bool saveIcsFile(String content, String filename) => false;
