/// Transport WebSocketChannel Adapter
///
/// Makes a Transport look like a WebSocketChannel so it can be used
/// with the existing MusicAssistantAPI without modifications.
///
/// This is a thin adapter that bridges our Transport interface to
/// the WebSocketChannel interface expected by MusicAssistantAPI.

import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'transport.dart';

/// Adapter that makes our Transport look like a WebSocketChannel
/// This allows MusicAssistantAPI to use WebRTC (or any transport) transparently
class TransportWebSocketChannelAdapter extends StreamChannelMixin implements WebSocketChannel {
  final ITransport _transport;
  final StreamController<dynamic> _streamController;
  final _TransportWebSocketSink _sink;

  TransportWebSocketChannelAdapter(this._transport)
      : _streamController = StreamController<dynamic>.broadcast(),
        _sink = _TransportWebSocketSink(_transport) {
    
    // Forward messages from transport to stream
    _transport.messageStream.listen(
      (message) {
        if (!_streamController.isClosed) {
          _streamController.add(message);
        }
      },
      onError: (error) {
        if (!_streamController.isClosed) {
          _streamController.addError(error);
        }
      },
      onDone: () {
        if (!_streamController.isClosed) {
          _streamController.close();
        }
      },
    );

    // Forward errors from transport to stream
    _transport.errorStream.listen(
      (error) {
        if (!_streamController.isClosed) {
          _streamController.addError(error);
        }
      },
    );
  }

  @override
  Stream get stream => _streamController.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => _sink._closeCode;

  @override
  String? get closeReason => _sink._closeReason;
}

/// WebSocketSink implementation that forwards to Transport
class _TransportWebSocketSink implements WebSocketSink {
  final ITransport _transport;
  final Completer<void> _doneCompleter = Completer<void>();
  int? _closeCode;
  String? _closeReason;

  _TransportWebSocketSink(this._transport);

  @override
  void add(dynamic data) {
    if (_doneCompleter.isCompleted) {
      throw StateError('WebSocketSink is closed');
    }
    _transport.send(data.toString());
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (_doneCompleter.isCompleted) {
      return _doneCompleter.future;
    }

    _closeCode = closeCode ?? status.normalClosure;
    _closeReason = closeReason;
    
    _transport.disconnect();
    
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    
    return _doneCompleter.future;
  }

  @override
  Future get done => _doneCompleter.future;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_doneCompleter.isCompleted) {
      throw StateError('WebSocketSink is closed');
    }
    // Errors are handled by the transport's error stream
  }

  @override
  Future addStream(Stream stream) {
    if (_doneCompleter.isCompleted) {
      return Future.error(StateError('WebSocketSink is closed'));
    }

    final completer = Completer();
    stream.listen(
      (data) => add(data),
      onError: (error, stackTrace) => completer.completeError(error, stackTrace),
      onDone: () => completer.complete(),
      cancelOnError: true,
    );
    return completer.future;
  }
}
