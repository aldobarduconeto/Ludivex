import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import '../services/desktop_store.dart';

class StoreLoginScreen extends StatefulWidget {
  const StoreLoginScreen({
    super.key,
    required this.provider,
    required this.loginUrl,
  });

  final StoreProvider provider;
  final Uri loginUrl;

  @override
  State<StoreLoginScreen> createState() => _StoreLoginScreenState();
}

class _StoreLoginScreenState extends State<StoreLoginScreen> {
  WebViewController? _controller;
  bool _finished = false;
  bool _failed = false;
  int _progress = 0;
  String? _host;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            if (request.isMainFrame) {
              final code = _redirectCode(uri);
              if (code != null) {
                _finish(code);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (!mounted || _finished) return;
            setState(() {
              _host = Uri.tryParse(url)?.host;
              _progress = 0;
            });
          },
          onUrlChange: (change) {
            final uri = Uri.tryParse(change.url ?? '');
            if (uri == null) return;
            final code = _redirectCode(uri);
            if (code != null) _finish(code);
          },
          onPageFinished: (url) => _readEpicResponse(controller, url),
          onProgress: (value) {
            if (mounted && !_finished) setState(() => _progress = value);
          },
          onWebResourceError: (error) {
            if (mounted && !_finished && error.isForMainFrame == true) {
              setState(() => _failed = true);
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(widget.loginUrl);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String? _redirectCode(Uri uri) {
    if (uri.scheme != 'https' || uri.port != 443) return null;
    return switch (widget.provider) {
      StoreProvider.gog
          when uri.host == 'embed.gog.com' && uri.path == '/on_login_success' =>
        uri.queryParameters['code'],
      StoreProvider.amazon
          when (uri.host == 'www.amazon.com' || uri.host == 'amazon.com') =>
        uri.queryParameters['openid.oa2.authorization_code'],
      _ => null,
    };
  }

  bool _isEpicResponse(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.host == 'www.epicgames.com' &&
      uri.path == '/id/api/redirect';

  Future<void> _readEpicResponse(
    WebViewController controller,
    String url,
  ) async {
    if (_finished ||
        widget.provider != StoreProvider.epic ||
        !_isEpicResponse(Uri.tryParse(url))) {
      return;
    }
    try {
      final result = await controller.runJavaScriptReturningResult(
        'location.origin === "https://www.epicgames.com" && '
        'location.pathname === "/id/api/redirect" ? document.body.innerText : ""',
      );
      Object? decoded = result;
      // Some native engines wrap a JavaScript string in JSON quotes.
      for (var i = 0; i < 2 && decoded is String; i++) {
        decoded = jsonDecode(decoded);
      }
      if (decoded is Map && decoded['authorizationCode'] is String) {
        _finish(decoded['authorizationCode'] as String);
      } else if (mounted && !_finished) {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted && !_finished) setState(() => _failed = true);
    }
  }

  void _finish(String code) {
    if (_finished || !mounted || ModalRoute.of(context)?.isCurrent != true)
      return;
    if (!RegExp(r'^[A-Za-z0-9_.~+=/-]+$').hasMatch(code)) return;
    _finished = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Entrar na ${widget.provider.label}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    ),
    body: Column(
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.lock_outline_rounded),
          title: Text(_host ?? widget.loginUrl.host),
        ),
        if (!_failed && _progress < 100)
          LinearProgressIndicator(
            value: _progress == 0 ? null : _progress / 100,
          ),
        Expanded(
          child: _failed
              ? Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Não foi possível concluir. Voltar'),
                  ),
                )
              : _controller == null
              ? const SizedBox.shrink()
              : WebViewWidget(controller: _controller!),
        ),
      ],
    ),
  );
}
