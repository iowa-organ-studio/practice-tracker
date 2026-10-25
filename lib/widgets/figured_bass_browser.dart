import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FiguredBassBrowser extends StatefulWidget {
  final String title;
  final String url;
  final VoidCallback onReturn;

  const FiguredBassBrowser({
    super.key,
    required this.title,
    required this.url,
    required this.onReturn,
  });

  @override
  State<FiguredBassBrowser> createState() => _FiguredBassBrowserState();
}

class _FiguredBassBrowserState extends State<FiguredBassBrowser> {
  late final WebViewController controller;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Allow students to rotate the figured-bass
    // browser between portrait and landscape.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => isLoading = false);
            }
          },
          onWebResourceError: (error) {
            debugPrint('Figured bass WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    // Restore portrait orientation when the
    // figured-bass browser is closed.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thin Flutter toolbar above the website.
        Container(
          height: 48,
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onReturn,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Return to Practice'),
                style: TextButton.styleFrom(foregroundColor: Colors.amber),
              ),
            ],
          ),
        ),

        if (isLoading) const LinearProgressIndicator(minHeight: 3),

        Expanded(child: WebViewWidget(controller: controller)),
      ],
    );
  }
}
