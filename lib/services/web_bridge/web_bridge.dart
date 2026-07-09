// Browser-only helpers (PWA install prompt, .ics download, platform
// sniffing). On Android/iOS builds the stub versions are compiled in and
// everything returns false.
export 'web_bridge_stub.dart'
    if (dart.library.js_interop) 'web_bridge_web.dart';
