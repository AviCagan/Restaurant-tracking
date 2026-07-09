import 'dart:js_interop';

// Implemented in web/index.html.
@JS('yumsCanInstall')
external bool _canInstall();

@JS('yumsInstall')
external JSPromise<JSBoolean> _install();

@JS('yumsIsIos')
external bool _isIos();

@JS('yumsIsAndroid')
external bool _isAndroid();

@JS('yumsIsStandalone')
external bool _isStandalone();

@JS('yumsSaveIcs')
external void _saveIcs(String content, String filename);

/// Chrome/Edge on Android fire `beforeinstallprompt` — when captured, we
/// can pop the real install dialog from a button.
bool canInstallPwa() {
  try {
    return _canInstall();
  } catch (_) {
    return false;
  }
}

Future<bool> promptInstallPwa() async {
  try {
    return (await _install().toDart).toDart;
  } catch (_) {
    return false;
  }
}

bool isIosBrowser() {
  try {
    return _isIos();
  } catch (_) {
    return false;
  }
}

bool isAndroidBrowser() {
  try {
    return _isAndroid();
  } catch (_) {
    return false;
  }
}

bool isStandalonePwa() {
  try {
    return _isStandalone();
  } catch (_) {
    return false;
  }
}

/// Downloads an .ics calendar file — Safari/Chrome then offer to add the
/// event to the phone's calendar.
bool saveIcsFile(String content, String filename) {
  try {
    _saveIcs(content, filename);
    return true;
  } catch (_) {
    return false;
  }
}
