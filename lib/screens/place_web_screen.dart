import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/gradient_app_bar.dart';

/// Opens a place's Google Maps page inside the app (call, website, order,
/// reserve, directions all live on that page) — nothing leaves the app.
class PlaceWebScreen extends StatefulWidget {
  const PlaceWebScreen({super.key, required this.query, required this.title});

  final String query; // "name address"
  final String title;

  @override
  State<PlaceWebScreen> createState() => _PlaceWebScreenState();
}

class _PlaceWebScreenState extends State<PlaceWebScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.query)}';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: widget.title),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
