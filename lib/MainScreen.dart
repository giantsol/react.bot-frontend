
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_streams/audio_streams.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:fb_app/AppColors.dart';
import 'package:fb_app/AppPreferences.dart';
import 'package:fb_app/entity/Connection.dart';
import 'package:fb_app/entity/Persona.dart';
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
    sampleRate: 16000,
    audioFormat: AudioFormat.ENCODING_PCM_16BIT,
  );
  AudioController _iosMicController = AudioController(CommonFormat.Int16, 16000, 1, true);
  StreamSubscription<List<int>> _micStreamSubscription;

  CameraController _cameraController;

  Connection _connection = ServerConnection();
  ConnectionStatus _connectionStatus = ConnectionStatus.DISCONNECTED;

  final List<Persona> _personas = [
    const Persona('Henie', 'assets/persona1/thumbnail.png',
      happyReactions: [
        Reaction('assets/persona1/excited.GIF', 'persona1/excited_1.wav'),
      ], sadReactions: [
        Reaction('assets/persona1/sad.GIF', 'persona1/sad_1.wav'),
        Reaction('assets/persona1/sad.GIF', 'persona1/sad2_1.wav'),
      ], angryReactions: [
        Reaction('assets/persona1/angry.GIF', 'persona1/angry_1.wav'),
      ], neutralReactions: [
        Reaction('assets/persona1/neutral.GIF', 'persona1/neutral_1.wav'),
      ],
    ),
    const Persona('Bro', 'assets/persona4/thumbnail.jpeg',

    ),
    const Persona('Dog', 'assets/persona2/thumbnail.png',

    ),
    const Persona('Cat', 'assets/persona3/thumbnail.png',

    ),
    const Persona('Cha Eun Woo', 'assets/persona5/thumbnail.png'),
  ];
  Persona _selectedPersona;
  Reaction _currentReaction;

  bool _speakPressed = false;

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
        if (_connectionStatus == ConnectionStatus.CONNECTED && _speakPressed) {
          _connection.sendMicData(samples);
        }
      });
    } else if (Platform.isIOS) {
      await _iosMicController.intialize();
      _micStreamSubscription = _iosMicController.startAudioStream().listen((List<int> samples) {
        if (_connectionStatus == ConnectionStatus.CONNECTED && _speakPressed) {
          _connection.sendMicData(samples);
        }
      });
    }

    final _cameras = await availableCameras();
    final selfieCamera = _cameras.firstWhere((it) => it.lensDirection == CameraLensDirection.front, orElse: () => null);
    if (selfieCamera != null) {
      _cameraController = CameraController(selfieCamera, ResolutionPreset.low, enableAudio: false);
      await _cameraController.initialize();
    }

    _connection.onDataReceived((data) {
      final number = int.tryParse(data) ?? 2;
      if (number == 0) {
        _onAngryClicked();
      } else if (number == 1) {
        _onHappyClicked();
      } else if (number == 3) {
        _onSadClicked();
      } else {
        _onNeutralClicked();
      }
    });

    _connection.onConnectionStatus((status) {
      setState(() {
        _connectionStatus = status;
      });
    });

    final selectedPersonaKey = await AppPreferences.getSelectedPersonaKey();
    _selectedPersona = _personas[max<int>(_personas.indexWhere((it) => it.key == selectedPersonaKey), 0)];

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
      if (_cameraController.value.isInitialized && !_cameraController.value.isStreamingImages
        && _isVideoTurnedOn
        && _connectionStatus == ConnectionStatus.CONNECTED) {
        _cameraController.startImageStream((image) {
          _connection.sendCameraData(
            image.planes.map((plane) => plane.bytes).toList());
        });
      } else if (_cameraController.value.isStreamingImages
        && (!_isVideoTurnedOn || _connectionStatus != ConnectionStatus.CONNECTED)) {
        _cameraController.stopImageStream();
      }
    }

    return WillPopScope(
      onWillPop: () async => !_handleBackPress(),
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            // Main UI
            Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const SizedBox(height: 52),
                    Container(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _personas.length,
                        itemBuilder: (context, index) {
                          final persona = _personas[index];
                          return _PersonaListItem(
                            persona: persona,
                            isSelected: persona.key == _selectedPersona?.key,
                            isFirstItem: index == 0,
                            isLastItem: index == _personas.length - 1,
                            onTap: () => _onPersonaListItemClicked(persona),
                          );
                        }
                      ),
                    ),
                    _PersonaView(
                      persona: _selectedPersona,
                      cameraController: _cameraController,
                      isVideoEnabled: _isVideoTurnedOn,
                      reaction: _currentReaction,
                      onReactionFinished: _onReactionFinished,
                    ),
                    _ConnectButton(
                      connectionStatus: _connectionStatus,
                      onTap: _onConnectButtonClicked,
                    ),
                    _connectionStatus == ConnectionStatus.CONNECTING ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onCancelConnectingClicked,
                      child: Container(
                        height: 60,
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.TEXT_BLACK,
                          ),
                        ),
                      ),
                    ) : const SizedBox(height: 60),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onTap: _onSettingsClicked,
                    child: Image.asset(
                      'assets/ic_settings.png',
                      width: 96,
                      height: 96,
                      color: AppColors.BACKGROUND_WHITE,
                    ),
                  ),
                ),
                _connectionStatus == ConnectionStatus.CONNECTED ? Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTapDown: _onSpeakTapDown,
                    onTapUp: _onSpeakTapUp,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: _speakPressed ? AppColors.PRIMARY : AppColors.BACKGROUND_WHITE,
                      ),
                      child: Text(
                        'Speak',
                        style: TextStyle(
                          color: _speakPressed ? AppColors.TEXT_WHITE : AppColors.TEXT_BLACK,
                        ),
                      ),
                    ),
                  ),
                ) : const SizedBox.shrink(),
              ],
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
    );
  }

  bool _handleBackPress() {
    if (_isServerDialogShown) {
      _onServerDialogCancelClicked();
      return true;
    }

    return false;
  }

  void _onSpeakTapDown(TapDownDetails _) {
    _connection.sendSpeakStart();
    setState(() {
      _speakPressed = true;
    });
  }

  void _onSpeakTapUp(TapUpDetails _) {
    _connection.sendSpeakEnd();
    setState(() {
      _speakPressed = false;
    });
  }

  void _onNeutralClicked() {
    setState(() {
      if (_selectedPersona.neutralReactions.length > 0) {
        _currentReaction = _selectedPersona.neutralReactions[Random().nextInt(
          _selectedPersona.neutralReactions.length)];
      }
    });
  }

  void _onHappyClicked() {
    setState(() {
      if (_selectedPersona.happyReactions.length > 0) {
        _currentReaction = _selectedPersona.happyReactions[Random().nextInt(
          _selectedPersona.happyReactions.length)];
      }
    });
  }

  void _onSadClicked() {
    setState(() {
      if (_selectedPersona.sadReactions.length > 0) {
        _currentReaction = _selectedPersona.sadReactions[Random().nextInt(
          _selectedPersona.sadReactions.length)];
      }
    });
  }

  void _onAngryClicked() {
    setState(() {
      if (_selectedPersona.angryReactions.length > 0) {
        _currentReaction = _selectedPersona.angryReactions[Random().nextInt(
          _selectedPersona.angryReactions.length)];
      }
    });
  }

  void _onSettingsClicked() {
    setState(() {
      _isServerDialogVideoChecked = _isVideoTurnedOn;

      _ipAddressEditingValue = _ipAddressEditingValue.copyWith(text: _serverConfig.ipAddress);
      _portEditingValue = _portEditingValue.copyWith(text: _serverConfig.port);
      _ipAddressEditingController = TextEditingController.fromValue(_ipAddressEditingValue);
      _portEditingController = TextEditingController.fromValue(_portEditingValue);

      _isServerDialogShown = true;
    });
  }

  void _onPersonaListItemClicked(Persona item) {
    setState(() {
      _selectedPersona = item;
      AppPreferences.setSelectedPersonaKey(item.key);
    });
  }

  void _onReactionFinished() {
    setState(() {
      _currentReaction = null;
    });
  }

  void _onCancelConnectingClicked() {
    _disconnect();
  }

  void _onConnectButtonClicked() {
    if (_connectionStatus == ConnectionStatus.DISCONNECTED) {
      _connect();
    } else if (_connectionStatus == ConnectionStatus.CONNECTED) {
      _disconnect();
    }
  }

  void _connect() {
    _connection.connect(_serverConfig);
  }

  void _disconnect() {
    _connection.disconnect();
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

class _PersonaListItem extends StatelessWidget {
  final Persona persona;
  final bool isSelected;
  final bool isFirstItem;
  final bool isLastItem;
  final Function onTap;

  _PersonaListItem({
    @required this.persona,
    @required this.isSelected,
    @required this.isFirstItem,
    @required this.isLastItem,
    @required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isFirstItem ? 24 : 0,
        right: isLastItem ? 24 : 0,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Container(
            width: 72,
            height: 72,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: isSelected ? AppColors.PRIMARY : AppColors.BACKGROUND_WHITE,
                width: 4,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              child: Image.asset(persona.thumbnail, fit: BoxFit.cover)
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonaView extends StatefulWidget {
  final Persona persona;
  final CameraController cameraController;
  final bool isVideoEnabled;
  final Reaction reaction;
  final Function onReactionFinished;

  _PersonaView({
    @required this.persona,
    @required this.cameraController,
    @required this.isVideoEnabled,
    @required this.reaction,
    @required this.onReactionFinished,
  });

  @override
  State createState() => _PersonaViewState();

}

class _PersonaViewState extends State<_PersonaView> {
  final AudioCache _audioCache = AudioCache();
  AudioPlayer _audioPlayer;
  StreamSubscription<AudioPlayerState> _stateSubscription;
  String _currentPlayingAudioPath;

  @override
  void didUpdateWidget(_PersonaView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final reaction = widget.reaction;
    if (reaction == null) {
      _stopReactionAudio();
    } else if (reaction != null && _currentPlayingAudioPath != reaction.audioPath) {
      _playReactionAudio(reaction.audioPath);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _stopReactionAudio();
  }

  void _stopReactionAudio() {
    _stateSubscription?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _currentPlayingAudioPath = null;
  }

  void _playReactionAudio(String audioPath) async {
    _stopReactionAudio();

    _currentPlayingAudioPath = audioPath;
    _audioPlayer = await _audioCache.play(audioPath);
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == AudioPlayerState.COMPLETED) {
        widget.onReactionFinished();
        _currentPlayingAudioPath = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final persona = widget.persona;
    final isVideoEnabled = widget.isVideoEnabled;
    final cameraController = widget.cameraController;
    final reaction = widget.reaction;

    if (persona == null) {
      return Expanded(
        child: const SizedBox.shrink(),
      );
    }

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: IntrinsicHeight(
            child: Stack(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Image.asset(
                    reaction == null ? persona.thumbnail : reaction.imgPath,
                  ),
                ),
                isVideoEnabled ? Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 136,
                      maxWidth: 136,
                    ),
                    child: AspectRatio(
                      aspectRatio: cameraController.value.aspectRatio,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.TEXT_BLACK_LIGHT,
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: CameraPreview(cameraController)
                      ),
                    ),
                  ),
                ) : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _ConnectButton extends StatelessWidget {
  final ConnectionStatus connectionStatus;
  final Function onTap;

  _ConnectButton({
    @required this.connectionStatus,
    @required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.all(Radius.circular(24)),
      color: connectionStatus == ConnectionStatus.CONNECTED ? AppColors.PRIMARY : AppColors.BACKGROUND_WHITE,
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
              connectionStatus == ConnectionStatus.CONNECTED ? 'Disconnect'
                : connectionStatus == ConnectionStatus.CONNECTING ? 'Connecting'
                : 'Connect',
              style: TextStyle(
                color: connectionStatus == ConnectionStatus.CONNECTED ? AppColors.TEXT_WHITE
                  : connectionStatus == ConnectionStatus.CONNECTING ? AppColors.TEXT_BLACK_LIGHT
                  : AppColors.TEXT_BLACK,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
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
                    'Enable Video',
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