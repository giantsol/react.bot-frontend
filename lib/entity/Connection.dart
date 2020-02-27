
import 'dart:typed_data';

import 'package:fb_app/entity/ServerConfig.dart';
import 'package:socket_io_client/socket_io_client.dart';

abstract class Connection {
  void sendMicData(List<int> data);
  void sendCameraData(List<Uint8List> data);

  void onDataSent(void Function(dynamic data) callback);
  void onDataReceived(void Function(dynamic data) callback);

  void dispose();
}

class LoopbackConnection implements Connection {
  Function(dynamic data) _onDataSentCallback;
  Function(dynamic data) _onDataReceivedCallback;

  @override
  void sendMicData(List<int> data) {
    if (_onDataSentCallback != null) {
      _onDataSentCallback(data);
    }

    if (_onDataReceivedCallback != null) {
      _onDataReceivedCallback(data);
    }
  }

  @override
  void sendCameraData(List<Uint8List> data) {
    if (_onDataSentCallback != null) {
      _onDataSentCallback('Video');
    }

    if (_onDataReceivedCallback != null) {
      _onDataReceivedCallback('Video');
    }
  }

  @override
  void onDataReceived(Function callback) {
    this._onDataReceivedCallback = callback;
  }

  @override
  void onDataSent(Function callback) {
    this._onDataSentCallback = callback;
  }

  @override
  void dispose() { }

}

class ServerConnection implements Connection {
  Socket _socket;
  Function(dynamic data) _onDataSentCallback;
  Function(dynamic data) _onDataReceivedCallback;

  ServerConnection(ServerConfig config) {
    _socket = io('https://${config.ipAddress}:${config.port}', <String, dynamic>{
      'transports': ['websocket'],
    });
    _socket.on('connect', (_) {
      print('socket connected');
      _socket.emit('fromClient', 'hello!!');
    });
    _socket.on('connect_error', (_) {
      print('socket connection error');
    });
    _socket.on('connect_timeout', (_) {
      print('socket connection timeout');
    });
    _socket.on('fromSerer', (data) {
      print('data from server: $data');

      if (_onDataReceivedCallback != null) {
        _onDataReceivedCallback(data);
      }
    });
    _socket.on('disconnect', (_) {
      print('client socket disconnected');
    });
  }

  @override
  void sendMicData(List<int> data) {
    _socket.emit('mic', data);

    if (_onDataSentCallback != null) {
      _onDataSentCallback(data);
    }
  }

  @override
  void sendCameraData(List<Uint8List> data) {
    _socket.emit('camera', data);

    if (_onDataSentCallback != null) {
      _onDataSentCallback('Video');
    }
  }

  @override
  void onDataSent(Function callback) {
    this._onDataSentCallback = callback;
  }

  @override
  void onDataReceived(Function callback) {
    this._onDataReceivedCallback = callback;
  }

  @override
  void dispose() {
    _socket.close();
  }
}