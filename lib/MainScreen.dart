
import 'dart:async';
import 'dart:io';

import 'package:audio_streams/audio_streams.dart';
import 'package:camera/camera.dart';
import 'package:fb_app/AppColors.dart';
import 'package:fb_app/AppPreferences.dart';
import 'package:fb_app/entity/Connection.dart';
import 'package:fb_app/entity/ServerConfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mic_stream/mic_stream.dart';

class MainScreen extends StatefulWidget {
  @override
  State createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  ServerConfig _serverConfig = ServerConfig.LOOPBACK;
  bool _isVideoTurnedOn = false;
  bool _isServerDialogShown = false;
  bool _isServerDialogVideoChecked = false;

  TextEditingValue _ipAddressEditingValue;
  TextEditingValue _portEditingValue;
  TextEditingController _ipAddressEditingController;
  TextEditingController _portEditingController;
  FocusNode _ipAddressFocusNode = FocusNode();

  Stream<List<int>> _androidMicStream = microphone(
    sampleRate: 44100,
    audioFormat: AudioFormat.ENCODING_PCM_16BIT,
  );
  AudioController _iosMicController = AudioController(CommonFormat.Int16, 44100, 1, true);
  StreamSubscription<List<int>> _micStreamSubscription;

  CameraController _cameraController;

  Connection _connection;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final savedIpAddress = await AppPreferences.getIpAddress();
    final savedPort = await AppPreferences.getPort();
    _serverConfig = ServerConfig(savedIpAddress, savedPort);

    _isVideoTurnedOn = await AppPreferences.getVideoEnabled();

    _ipAddressEditingValue = TextEditingValue(text: _serverConfig.ipAddress);
    _portEditingValue = TextEditingValue(text: _serverConfig.port);

    // Due to the bugs of these libraries, we begin mic streaming right away
    // even though we haven't connected yet.
    if (Platform.isAndroid) {
      _micStreamSubscription = _androidMicStream.listen((List<int> samples) {
        _connection?.sendMicData(samples);
      });
    } else if (Platform.isIOS) {
      await _iosMicController.intialize();
      _micStreamSubscription = _iosMicController.startAudioStream().listen((List<int> samples) {
        _connection?.sendMicData(samples);
      });
    }

    final _cameras = await availableCameras();
    final selfieCamera = _cameras.firstWhere((it) => it.lensDirection == CameraLensDirection.front);
    _cameraController = CameraController(selfieCamera, ResolutionPreset.low, enableAudio: false);
    await _cameraController.initialize();

    if (mounted) {
      setState(() { });
    }
  }

  @override
  void dispose() {
    super.dispose();

    _micStreamSubscription?.cancel();
    if (Platform.isIOS) {
      _iosMicController.stopAudioStream();
    }

    _cameraController.stopImageStream();
    _cameraController.dispose();

    _disconnect();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController != null) {
      if (_isVideoTurnedOn && _cameraController.value.isInitialized && !_cameraController.value.isStreamingImages) {
        _cameraController.startImageStream((image) {
          _connection?.sendCameraData(
            image.planes.map((plane) => plane.bytes).toList());
        });
      } else if (!_isVideoTurnedOn && _cameraController.value.isStreamingImages) {
        _cameraController.stopImageStream();
      }
    }

    return WillPopScope(
      onWillPop: () async => !_handleBackPress(),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              // Main UI
              Center(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 28,),
                    _ServerButton(
                      onTap: _onServerBoxClicked,
                      serverConfig: _serverConfig,
                    ),
                    const SizedBox(height: 28,),
                    _VideoBox(
                      isVideoTurnedOn: _isVideoTurnedOn,
                      cameraController: _cameraController,
                    ),
                    const SizedBox(height: 10,),
                    _ConnectButton(
                      connection: _connection,
                      onTap: _onConnectButtonClicked,
                    ),
                  ],
                ),
              ),
              // Scrim
              _isServerDialogShown ? _Scrim()
                : const SizedBox.shrink(),
              // Server Dialog
              _isServerDialogShown ? _ServerDialog(
                ipAddressFocusNode: _ipAddressFocusNode,
                isServerDialogVideoChecked: _isServerDialogVideoChecked,
                ipAddressEditingController: _ipAddressEditingController,
                portEditingController: _portEditingController,
                onVideoCheckboxChanged: _onServerDialogVideoCheckChanged,
                onCancelClicked: _onServerDialogCancelClicked,
                onOkClicked: _onServerDialogOkClicked,
              ) : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  bool _handleBackPress() {
    if (_isServerDialogShown) {
      _onServerDialogCancelClicked();
      return true;
    }

    return false;
  }

  void _onServerBoxClicked() {
    setState(() {
      _isServerDialogVideoChecked = _isVideoTurnedOn;

      _ipAddressEditingValue = _ipAddressEditingValue.copyWith(text: _serverConfig.ipAddress);
      _portEditingValue = _portEditingValue.copyWith(text: _serverConfig.port);
      _ipAddressEditingController = TextEditingController.fromValue(_ipAddressEditingValue);
      _portEditingController = TextEditingController.fromValue(_portEditingValue);

      _isServerDialogShown = true;
    });
  }

  void _onConnectButtonClicked() {
    if (_connection == null) {
      _connect();
    } else {
      _disconnect();
    }
  }

  void _connect() {
    if (_serverConfig.isLoopback()) {
      _connection = LoopbackConnection();
    } else {
      _connection = ServerConnection(_serverConfig);
    }

    _connection.onDataSent((sentData) {
      setState(() {
//        _sentDataStatus = _sentDataStatus.buildNew(
//          value: sentData,
//        );
      });
    });
    _connection.onDataReceived((receivedData) {
      setState(() {
//        _receivedDataStatus = _receivedDataStatus.buildNew(
//          value: receivedData,
//        );
      });
    });

    setState(() { });
  }

  void _disconnect() {
    _connection?.dispose();
    _connection = null;
  }

  void _onServerDialogVideoCheckChanged(bool value) {
    setState(() {
      _isServerDialogVideoChecked = !_isServerDialogVideoChecked;
    });
  }

  void _onServerDialogCancelClicked() {
    setState(() {
      _isServerDialogShown = false;
    });
  }

  void _onServerDialogOkClicked() {
    _disconnect();

    setState(() {
      _serverConfig = ServerConfig(
        _ipAddressEditingController.text,
        _portEditingController.text,
      );

      _isVideoTurnedOn = _isServerDialogVideoChecked;
      AppPreferences.setVideoEnabled(_isVideoTurnedOn);

      _isServerDialogShown = false;

      AppPreferences.setIpAddress(_serverConfig.ipAddress);
      AppPreferences.setPort(_serverConfig.port);
    });
  }

}

class _ServerButton extends StatelessWidget {
  final Function onTap;
  final ServerConfig serverConfig;

  _ServerButton({
    @required this.onTap,
    @required this.serverConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Server',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.TEXT_BLACK,
                ),
              ),
              const SizedBox(height: 4,),
              Text(
                serverConfig.isLoopback() ? 'Loopback'
                  : '${serverConfig.ipAddress}:${serverConfig.port}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.PRIMARY,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoBox extends StatelessWidget {
  final bool isVideoTurnedOn;
  final CameraController cameraController;

  _VideoBox({
    @required this.isVideoTurnedOn,
    @required this.cameraController,
  });

  @override
  Widget build(BuildContext context) {
    return isVideoTurnedOn ? Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AspectRatio(
        aspectRatio: 4.0 / 3.0,
        child: CameraPreview(cameraController),
      ),
    ) : Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AspectRatio(
        aspectRatio: 4.0 / 3.0,
        child: Container(
          color: AppColors.BACKGROUND_GREY,
          alignment: Alignment.center,
          child: Text(
            'No Video',
            style: TextStyle(
              fontSize: 24,
              color: AppColors.TEXT_WHITE,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final Connection connection;
  final Function onTap;

  _ConnectButton({
    @required this.connection,
    @required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Material(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          color: connection != null ? AppColors.PRIMARY : AppColors.BACKGROUND_WHITE,
          child: InkWell(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                minWidth: 164,
                minHeight: 42,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(24)),
                border: Border.all(
                  color: AppColors.PRIMARY,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  connection != null ? 'Disconnect' : 'Connect',
                  style: TextStyle(
                    color: connection != null ? AppColors.TEXT_WHITE : AppColors.TEXT_BLACK,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.SCRIM,
    );
  }
}

class _ServerDialog extends StatelessWidget {
  final FocusNode ipAddressFocusNode;
  final bool isServerDialogVideoChecked;
  final TextEditingController ipAddressEditingController;
  final TextEditingController portEditingController;
  final Function onVideoCheckboxChanged;
  final Function onCancelClicked;
  final Function onOkClicked;

  _ServerDialog({
    @required this.ipAddressFocusNode,
    @required this.isServerDialogVideoChecked,
    @required this.ipAddressEditingController,
    @required this.portEditingController,
    @required this.onVideoCheckboxChanged,
    @required this.onCancelClicked,
    @required this.onOkClicked,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            color: AppColors.BACKGROUND_WHITE,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Text(
                  'Server',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.TEXT_BLACK,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'IP Address',
                style: TextStyle(
                  fontSize: 8,
                  color: AppColors.PRIMARY,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              TextField(
                focusNode: ipAddressFocusNode,
                controller: ipAddressEditingController,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.TEXT_BLACK,
                ),
                decoration: null,
                cursorColor: AppColors.TEXT_BLACK,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Port',
                style: TextStyle(
                  fontSize: 8,
                  color: AppColors.PRIMARY,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2,),
              TextField(
                controller: portEditingController,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.TEXT_BLACK,
                ),
                decoration: null,
                cursorColor: AppColors.TEXT_BLACK,
              ),
              const SizedBox(height: 8,),
              Row(
                children: <Widget>[
                  Checkbox(
                    value: isServerDialogVideoChecked,
                    onChanged: onVideoCheckboxChanged,
                  ),
                  Text(
                    'Loopback',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.TEXT_BLACK,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Material(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: onCancelClicked,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.TEXT_BLACK_LIGHT,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.TEXT_BLACK_LIGHT,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8,),
                  Expanded(
                    child: Material(
                      color: AppColors.PRIMARY,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: onOkClicked,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.PRIMARY,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Text(
                            'Ok',
                            style: TextStyle(
                              color: AppColors.TEXT_WHITE,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}