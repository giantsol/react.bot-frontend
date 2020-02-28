
import 'dart:async';
import 'dart:io';

import 'package:audio_streams/audio_streams.dart';
import 'package:camera/camera.dart';
import 'package:fb_app/AppColors.dart';
import 'package:fb_app/entity/Connection.dart';
import 'package:fb_app/entity/DataStatus.dart';
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
  bool _isMicTurnedOn = false;
  bool _isVideoTurnedOn = false;
  DataStatus _sentDataStatus = DataStatus.NONE;
  DataStatus _receivedDataStatus = DataStatus.NONE;
  bool _isServerDialogShown = false;
  bool _isServerDialogLoopbackChecked = false;

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
    _ipAddressEditingValue = TextEditingValue(text: _serverConfig.ipAddress);
    _portEditingValue = TextEditingValue(text: _serverConfig.port);

    // Due to the bugs of these libraries, we begin mic streaming regardless of _isMicTurnedOn flag
    // but send mic data only when _isMicTurnedOn is true
    if (Platform.isAndroid) {
      _micStreamSubscription = _androidMicStream.listen((List<int> samples) {
        if (_isMicTurnedOn) {
          _connection?.sendMicData(samples);
        }
      });
    } else if (Platform.isIOS) {
      await _iosMicController.intialize();
      _micStreamSubscription = _iosMicController.startAudioStream().listen((List<int> samples) {
        if (_isMicTurnedOn) {
          _connection?.sendMicData(samples);
        }
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
                    // Mic and Video buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _MicButton(
                          onTap: _onMicIconClicked,
                          isMicTurnedOn: _isMicTurnedOn,
                        ),
                        _VideoButton(
                          onTap: _onVideoIconClicked,
                          isVideoTurnedOn: _isVideoTurnedOn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10,),
                    _DataStatusTable(
                      sentDataStatus: _sentDataStatus,
                      receivedDataStatus: _receivedDataStatus,
                    ),
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
                isServerDialogLoopbackChecked: _isServerDialogLoopbackChecked,
                ipAddressEditingController: _ipAddressEditingController,
                portEditingController: _portEditingController,
                onLoopbackCheckboxChanged: _onServerDialogLoopbackCheckChanged,
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
      _isServerDialogLoopbackChecked = _serverConfig.isLoopback();

      _ipAddressEditingValue = _ipAddressEditingValue.copyWith(text: _serverConfig.ipAddress);
      _portEditingValue = _portEditingValue.copyWith(text: _serverConfig.port);
      _ipAddressEditingController = TextEditingController.fromValue(_ipAddressEditingValue);
      _portEditingController = TextEditingController.fromValue(_portEditingValue);

      _isServerDialogShown = true;
    });
  }

  void _onMicIconClicked() {
    setState(() {
      _isMicTurnedOn = !_isMicTurnedOn;
    });
  }

  void _onVideoIconClicked() async {
    setState(() {
      _isVideoTurnedOn = !_isVideoTurnedOn;
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
        _sentDataStatus = _sentDataStatus.buildNew(
          value: sentData,
        );
      });
    });
    _connection.onDataReceived((receivedData) {
      setState(() {
        _receivedDataStatus = _receivedDataStatus.buildNew(
          value: receivedData,
        );
      });
    });

    setState(() { });
  }

  void _disconnect() {
    _connection?.dispose();
    _connection = null;

    setState(() {
      _sentDataStatus = DataStatus.NONE;
      _receivedDataStatus = DataStatus.NONE;
    });
  }

  void _onServerDialogLoopbackCheckChanged(bool value) {
    setState(() {
      _isServerDialogLoopbackChecked = !_isServerDialogLoopbackChecked;

      if (!value) {
        WidgetsBinding.instance.addPostFrameCallback((d) {
          _ipAddressFocusNode.requestFocus();
        });
      }
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
      if (_isServerDialogLoopbackChecked) {
        _serverConfig = ServerConfig.LOOPBACK;
      } else {
        _serverConfig = ServerConfig(
          _ipAddressEditingController.text,
          _portEditingController.text,
        );
      }

      _isServerDialogShown = false;
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

class _MicButton extends StatelessWidget {
  final Function onTap;
  final bool isMicTurnedOn;

  _MicButton({
    @required this.onTap,
    @required this.isMicTurnedOn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isMicTurnedOn ? AppColors.PRIMARY : AppColors.BACKGROUND_GREY,
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            isMicTurnedOn ? 'assets/ic_mic_on.png' : 'assets/ic_mic_off.png',
          ),
        )
      ),
    );
  }
}

class _VideoButton extends StatelessWidget {
  final Function onTap;
  final bool isVideoTurnedOn;

  _VideoButton({
    @required this.onTap,
    @required this.isVideoTurnedOn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isVideoTurnedOn ? AppColors.PRIMARY : AppColors.BACKGROUND_GREY,
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            isVideoTurnedOn ? 'assets/ic_video_on.png' : 'assets/ic_video_off.png',
          ),
        )
      ),
    );
  }
}

class _DataStatusTable extends StatelessWidget {
  final DataStatus sentDataStatus;
  final DataStatus receivedDataStatus;

  _DataStatusTable({
    @required this.sentDataStatus,
    @required this.receivedDataStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32,),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              Center(
                child: Text(
                  'Sent',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.TEXT_BLACK,
                  ),
                ),
              ),
              const SizedBox.shrink(),
              Center(
                child: Text(
                  'Received',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.TEXT_BLACK,
                  ),
                ),
              ),
            ],
          ),
          TableRow(
            children: [
              const SizedBox(height: 10,),
              const SizedBox(height: 10,),
              const SizedBox(height: 10,),
            ],
          ),
          TableRow(
            children: [
              Center(
                child: Text(
                  sentDataStatus.getAccBytesString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.PRIMARY,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Acc',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.TEXT_BLACK,
                  ),
                ),
              ),
              Center(
                child: Text(
                  receivedDataStatus.getAccBytesString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.PRIMARY,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ),
          TableRow(
            children: [
              Center(
                child: Text(
                  sentDataStatus.getRealtimeBytesString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.PRIMARY,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'RT',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.TEXT_BLACK,
                  ),
                ),
              ),
              Center(
                child: Text(
                  receivedDataStatus.getRealtimeBytesString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.PRIMARY,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ),
          TableRow(
            children: [
              Center(
                child: Text(
                  sentDataStatus.getValueString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.PRIMARY,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Center(
                child: Text(
                  'Value',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.TEXT_BLACK,
                  ),
                ),
              ),
              Center(
                child: Text(
                  receivedDataStatus.getValueString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.PRIMARY,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]
          ),
        ],
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
  final bool isServerDialogLoopbackChecked;
  final TextEditingController ipAddressEditingController;
  final TextEditingController portEditingController;
  final Function onLoopbackCheckboxChanged;
  final Function onCancelClicked;
  final Function onOkClicked;

  _ServerDialog({
    @required this.ipAddressFocusNode,
    @required this.isServerDialogLoopbackChecked,
    @required this.ipAddressEditingController,
    @required this.portEditingController,
    @required this.onLoopbackCheckboxChanged,
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
                  color: isServerDialogLoopbackChecked ? AppColors.TEXT_BLACK_LIGHT
                    : AppColors.TEXT_BLACK,
                ),
                decoration: null,
                cursorColor: AppColors.TEXT_BLACK,
                autofocus: true,
                enabled: !isServerDialogLoopbackChecked,
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
                  color: isServerDialogLoopbackChecked ? AppColors.TEXT_BLACK_LIGHT
                    : AppColors.TEXT_BLACK,
                ),
                decoration: null,
                cursorColor: AppColors.TEXT_BLACK,
                enabled: !isServerDialogLoopbackChecked,
              ),
              const SizedBox(height: 8,),
              Row(
                children: <Widget>[
                  Checkbox(
                    value: isServerDialogLoopbackChecked,
                    onChanged: onLoopbackCheckboxChanged,
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