import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// Keep HTTP outside the Flutter/libmpv isolate. A synchronous native property
/// or Surface seek must never wait for HTTP bytes served by that same isolate.
class LocalTransportServer {
  LocalTransportServer._(
    this.port,
    this._control,
    this._worker,
    this._events,
    this._subscription,
    this._closed,
    this.requests,
  );
  final int port;
  final SendPort _control;
  final Isolate _worker;
  final ReceivePort _events;
  final StreamSubscription<dynamic> _subscription;
  final Completer<void> _closed;
  final List<Map<String, Object?>> requests;

  static Future<LocalTransportServer> start(Uint8List bytes) async {
    final events = ReceivePort();
    final ready = Completer<(int, SendPort)>();
    final closed = Completer<void>();
    final requests = <Map<String, Object?>>[];
    final subscription = events.listen((message) {
      if (message is! Map) return;
      if (message['ready'] is int &&
          message['control'] is SendPort &&
          !ready.isCompleted) {
        ready.complete((
          message['ready'] as int,
          message['control'] as SendPort,
        ));
      }
      if (message['request'] is Map) {
        requests.add(Map<String, Object?>.from(message['request'] as Map));
      }
      if (message['closed'] == true && !closed.isCompleted) closed.complete();
      if (message['error'] != null && !ready.isCompleted) {
        ready.completeError(StateError('Local test server could not start'));
      }
    });
    final worker = await Isolate.spawn(_serveTransport, (
      events.sendPort,
      TransferableTypedData.fromList([bytes]),
    ));
    try {
      final (port, control) = await ready.future.timeout(
        const Duration(seconds: 10),
      );
      return LocalTransportServer._(
        port,
        control,
        worker,
        events,
        subscription,
        closed,
        requests,
      );
    } catch (_) {
      worker.kill(priority: Isolate.immediate);
      await subscription.cancel();
      events.close();
      rethrow;
    }
  }

  Future<void> close({bool force = false}) async {
    _control.send('stop');
    try {
      await _closed.future.timeout(const Duration(seconds: 5));
    } finally {
      _worker.kill(priority: Isolate.immediate);
      await _subscription.cancel();
      _events.close();
    }
  }
}

Future<void> _serveTransport((SendPort, TransferableTypedData) input) async {
  final (events, transfer) = input;
  final bytes = transfer.materialize().asUint8List();
  final commands = ReceivePort();
  HttpServer? server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    events.send({'ready': port, 'control': commands.sendPort});
    server.listen((request) async {
      events.send({
        'request': {
          'path': request.uri.path,
          'method': request.method,
          'range': request.headers.value(HttpHeaders.rangeHeader),
        },
      });
      try {
        if (request.uri.path.endsWith('.m3u8')) {
          final playlist = utf8.encode(
            '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXT-X-TARGETDURATION:13\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:12.0,\nhttp://127.0.0.1:$port/original.ts\n#EXT-X-ENDLIST\n',
          );
          request.response.headers.contentType = ContentType(
            'application',
            'vnd.apple.mpegurl',
          );
          request.response.contentLength = playlist.length;
          if (request.method != 'HEAD') request.response.add(playlist);
        } else if (request.uri.path.endsWith('.ts')) {
          request.response.headers.contentType = ContentType('video', 'mp2t');
          request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
          final range = RegExp(r'^bytes=(\d+)-(\d*)$')
              .firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
          final start = range == null ? 0 : int.parse(range[1]!);
          final end = range == null || range[2]!.isEmpty
              ? bytes.length - 1
              : int.parse(range[2]!);
          if (start >= bytes.length || end < start || end >= bytes.length) {
            request.response.statusCode =
                HttpStatus.requestedRangeNotSatisfiable;
          } else {
            if (range != null) {
              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.set(
                HttpHeaders.contentRangeHeader,
                'bytes $start-$end/${bytes.length}',
              );
            }
            request.response.contentLength = end - start + 1;
            if (request.method != 'HEAD') {
              request.response.add(
                Uint8List.sublistView(bytes, start, end + 1),
              );
            }
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      } catch (_) {
        /* The decoder can intentionally cancel a probe/range. */
      }
    });
    await commands.firstWhere((message) => message == 'stop');
  } catch (_) {
    events.send({'error': true});
  } finally {
    await server?.close(force: true);
    commands.close();
    events.send({'closed': true});
  }
}
