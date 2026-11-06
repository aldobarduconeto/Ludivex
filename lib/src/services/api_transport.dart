import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:http/http.dart' as http;

class ApiDeferred implements Exception {
  const ApiDeferred(this.retryAt, this.reason);
  final DateTime retryAt;
  final String reason;
  @override
  String toString() => reason;
}

class _Response {
  _Response(this.data, this.at, this.bytes);
  final Map<String, dynamic> data;
  final DateTime at;
  final int bytes;
}

/// One quota policy for catalogs, searches, individual prices and source tests.
class ApiTransport {
  ApiTransport({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _now;
  static const minimumRefresh = Duration(minutes: 1);
  static const maxRequestsPerHost = 12;
  static const maxCacheBytes = 8 * 1024 * 1024;
  final _cache = LinkedHashMap<Uri, _Response>();
  final _pending = <Uri, Future<Map<String, dynamic>>>{};
  final _hostCalls = <String, List<DateTime>>{};
  final _hostRetry = <String, DateTime>{};
  final _uriRetry = <Uri, DateTime>{};
  final _lastSuccess = <Uri, DateTime>{};
  final _failures = <String, int>{};
  final _waiting = Queue<Completer<void>>();
  int _active = 0, _bytes = 0;
  int networkRequests = 0,
      cacheHits = 0,
      joinedRequests = 0,
      deferredRequests = 0;
  bool _closed = false;

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Duration maxAge = const Duration(minutes: 15),
    bool force = false,
    Map<String, dynamic>? body,
  }) {
    if (body != null) uri = uri.replace(fragment: jsonEncode(body));
    if (_closed) return Future.error(StateError('Cliente encerrado'));
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return Future.error(const FormatException('A API precisa usar HTTPS'));
    }
    final now = _now();
    final entry = _cache[uri];
    if (entry != null &&
        now.difference(entry.at) < (force ? minimumRefresh : maxAge)) {
      cacheHits++;
      _cache.remove(uri);
      _cache[uri] = entry;
      return Future.value(entry.data);
    }
    if (_pending.containsKey(uri)) {
      joinedRequests++;
      return _pending[uri]!;
    }
    return _pending[uri] = _download(uri, body: body).whenComplete(() {
      _pending.remove(uri);
    });
  }

  Future<void> _acquire() async {
    if (_active < 2) {
      _active++;
      return;
    }
    if (_waiting.length >= 20)
      throw ApiDeferred(
        _now().add(minimumRefresh),
        'Muitas consultas em andamento',
      );
    final waiter = Completer<void>();
    _waiting.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }

  void _checkBudget(Uri uri) {
    if (_closed) throw StateError('Cliente encerrado');
    final now = _now();
    final previous = _lastSuccess[uri];
    if (previous != null && previous.add(minimumRefresh).isAfter(now)) {
      deferredRequests++;
      throw ApiDeferred(
        previous.add(minimumRefresh),
        'Consulta recente; aguarde antes de atualizar novamente',
      );
    }
    final pauses = [_hostRetry[uri.host], _uriRetry[uri]].whereType<DateTime>();
    for (final until in pauses) {
      if (until.isAfter(now)) {
        deferredRequests++;
        throw ApiDeferred(
          until,
          'API em pausa; uma consulta posterior tentará novamente',
        );
      }
    }
    final calls = _hostCalls.putIfAbsent(uri.host, () => []);
    calls.removeWhere((at) => !at.add(const Duration(minutes: 1)).isAfter(now));
    if (calls.length >= maxRequestsPerHost) {
      deferredRequests++;
      throw ApiDeferred(
        calls.first.add(const Duration(minutes: 1)),
        'Limite local de consultas atingido',
      );
    }
    calls.add(now);
  }

  Future<Map<String, dynamic>> _download(
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    await _acquire();
    Timer? deadline;
    final abort = Completer<void>();
    try {
      _checkBudget(uri);
      networkRequests++;
      try {
        deadline = Timer(const Duration(seconds: 20), () {
          if (!abort.isCompleted) abort.complete();
        });
        final request =
            http.AbortableRequest(
                body == null ? 'GET' : 'POST',
                uri.removeFragment(),
                abortTrigger: abort.future,
              )
              ..headers['Accept'] = 'application/json, text/html;q=0.9'
              ..followRedirects =
                  body == null &&
                  const {
                    'www.nuuvem.com',
                    'store.ubisoft.com',
                    'www.ea.com',
                    'www.nintendo.com',
                    'www.xbox.com',
                    'store.playstation.com',
                    'www.sony.com',
                  }.contains(uri.host)
              ..maxRedirects = 3;
        if (uri.host == 'web.np.playstation.com') {
          request.headers['apollo-require-preflight'] = 'true';
          request.headers['x-apollo-operation-name'] =
              uri.queryParameters['operationName'] ?? 'categoryGridRetrieve';
          request.headers['X-PSN-Store-Locale-Override'] =
              uri.queryParameters['locale'] ?? 'pt-br';
          request.headers['Content-Type'] = 'application/json';
        }
        if (uri.host == 'emerald.xboxservices.com') {
          request.headers['x-ms-api-version'] = '1.1';
          request.headers['MS-CV'] =
              '${base64Encode(List.generate(16, (_) => Random.secure().nextInt(256))).replaceAll('=', '')}.0';
        }
        if (uri.host == 'service-aggregation-layer.juno.ea.com') {
          request.headers['x-client-id'] = 'eacom-fe';
        }
        if (body != null) {
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(body);
        }
        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          await response.stream.listen((_) {}).cancel();
          if (response.statusCode == 429 || response.statusCode == 503) {
            final count = (_failures[uri.host] ?? 0) + 1;
            _failures[uri.host] = count.clamp(1, 6);
            final fallback = _now().add(
              Duration(minutes: 1 << (count - 1).clamp(0, 5)),
            );
            final requested = _retryAfter(response.headers['retry-after']);
            final until = requested != null && requested.isAfter(fallback)
                ? requested
                : fallback;
            _hostRetry[uri.host] = until;
            throw ApiDeferred(
              until,
              'A loja limitou as consultas. Aguardando nova tentativa',
            );
          }
          throw http.ClientException('HTTP ${response.statusCode}');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 15),
        )) {
          if (bytes.length + chunk.length > maxCacheBytes)
            throw const FormatException('Resposta excessiva');
          bytes.add(chunk);
        }
        final size = bytes.length;
        final text = utf8.decode(bytes.takeBytes());
        final Map<String, dynamic> data;
        if ((response.headers['content-type'] ?? '').contains('text/html')) {
          data = {'html': text};
        } else {
          data = jsonDecode(text) as Map<String, dynamic>;
        }
        final old = _cache.remove(uri);
        _bytes -= old?.bytes ?? 0;
        _cache[uri] = _Response(data, _now(), size);
        _bytes += size;
        while (_bytes > maxCacheBytes || _cache.length > 64) {
          _bytes -= _cache.remove(_cache.keys.first)!.bytes;
        }
        _uriRetry.remove(uri);
        _lastSuccess[uri] = _now();
        if (_lastSuccess.length > 128)
          _lastSuccess.remove(_lastSuccess.keys.first);
        _failures.remove(uri.toString());
        _failures.remove(uri.host);
        return data;
      } on ApiDeferred {
        rethrow;
      } catch (_) {
        final count = (_failures[uri.toString()] ?? 0) + 1;
        _failures[uri.toString()] = count.clamp(1, 5);
        _uriRetry[uri] = _now().add(
          Duration(seconds: 30 * (1 << (count - 1).clamp(0, 4))),
        );
        rethrow;
      }
    } finally {
      deadline?.cancel();
      _release();
    }
  }

  DateTime? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null && seconds >= 0)
      return _now().add(Duration(seconds: seconds));
    // IMF-fixdate, used by Retry-After: Wed, 21 Oct 2026 07:28:00 GMT.
    final parts = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value.trim());
    if (parts == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months.indexOf(parts[2]!);
    if (month < 0) return null;
    return DateTime.utc(
      int.parse(parts[3]!),
      month + 1,
      int.parse(parts[1]!),
      int.parse(parts[4]!),
      int.parse(parts[5]!),
      int.parse(parts[6]!),
    );
  }

  /// Clearing prices must never circumvent a provider cooldown or the local budget.
  void clearCache() {
    _cache.clear();
    _bytes = 0;
  }

  void dispose() {
    _closed = true;
    _client.close();
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().completeError(StateError('Cliente encerrado'));
    }
  }
}
