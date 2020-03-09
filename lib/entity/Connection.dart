
import 'dart:typed_data';

import 'package:fb_app/entity/ServerConfig.dart';
import 'package:socket_io_client/socket_io_client.dart';

abstract class Connection {

  void sendMicData(List<int> data);
  void sendCameraData(List<Uint8List> data);

  void onConnectionStatus(void Function(ConnectionStatus status) callback);
  void onDataSent(void Function(dynamic data) callback);
  void onDataReceived(void Function(dynamic data) callback);

  void connect(ServerConfig config);
  void disconnect();
}

enum ConnectionStatus {
  DISCONNECTED,
  CONNECTING,
  CONNECTED,
}

class ServerConnection implements Connection {
  Socket _socket;
  ConnectionStatus _connectionStatus = ConnectionStatus.DISCONNECTED;

  Function(dynamic data) _onDataSentCallback;
  Function(dynamic data) _onDataReceivedCallback;
  Function(ConnectionStatus status) _onConnectionStatusCallback;

  @override
  void sendMicData(List<int> data) {
    if (_connectionStatus == ConnectionStatus.CONNECTED) {
      _socket.emit('mic', data);

      if (_onDataSentCallback != null) {
        _onDataSentCallback(data);
      }
    }
  }

  @override
  void sendCameraData(List<Uint8List> data) {
    if (_connectionStatus == ConnectionStatus.CONNECTED) {
      _socket.emit('camera', data);

      if (_onDataSentCallback != null) {
        _onDataSentCallback('Video');
      }
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
  void onConnectionStatus(Function callback) {
    this._onConnectionStatusCallback = callback;
  }

  @override
  void connect(ServerConfig config) {
    _connectionStatus = ConnectionStatus.CONNECTING;
    if (_onConnectionStatusCallback != null) {
      _onConnectionStatusCallback(_connectionStatus);
    }

    _socket = io('http://${config.ipAddress}:${config.port}', <String, dynamic>{
      'transports': ['websocket'],
    });

    _socket.on('connect', (_) {
      print('socket connected');
      _socket.emit('fromClient', 'hello!!');

      _connectionStatus = ConnectionStatus.CONNECTED;
      if (_onConnectionStatusCallback != null) {
        _onConnectionStatusCallback(_connectionStatus);
      }
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

      _connectionStatus = ConnectionStatus.DISCONNECTED;
      if (_onConnectionStatusCallback != null) {
        _onConnectionStatusCallback(_connectionStatus);
      }
    });
  }

  @override
  void disconnect() {
    _socket?.close();

    _connectionStatus = ConnectionStatus.DISCONNECTED;
    if (_onConnectionStatusCallback != null) {
      _onConnectionStatusCallback(_connectionStatus);
    }
  }
}