
import 'package:fb_app/AppColors.dart';
import 'package:fb_app/entity/DataStatus.dart';
import 'package:fb_app/entity/ServerConfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

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
  bool _isConnected = false;
  bool _isServerDialogShown = false;
  bool _isServerDialogLoopbackChecked = false;

  TextEditingValue _ipAddressEditingValue;
  TextEditingValue _portEditingValue;
  TextEditingController _ipAddressEditingController;
  TextEditingController _portEditingController;
  FocusNode _ipAddressFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _init();
  }

  void _init() async {
    _ipAddressEditingValue = TextEditingValue(text: _serverConfig.ipAddress);
    _portEditingValue = TextEditingValue(text: _serverConfig.port);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_handleBackPress(),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 28,),
                    // Server Button
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _onServerBoxClicked,
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
                                _serverConfig.isLoopback() ? 'Loopback'
                                  : '${_serverConfig.ipAddress}:${_serverConfig.port}',
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
                    ),
                    const SizedBox(height: 28,),
                    // No Video box
                    Padding(
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
                    ),
                    const SizedBox(height: 10,),
                    // Mic and Video buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        InkWell(
                          customBorder: CircleBorder(),
                          onTap: _onMicIconClicked,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isMicTurnedOn ? AppColors.PRIMARY : AppColors.BACKGROUND_GREY,
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                _isMicTurnedOn ? 'assets/ic_mic_on.png' : 'assets/ic_mic_off.png',
                              ),
                            )
                          ),
                        ),
                        InkWell(
                          customBorder: CircleBorder(),
                          onTap: _onVideoIconClicked,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isVideoTurnedOn ? AppColors.PRIMARY : AppColors.BACKGROUND_GREY,
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                _isVideoTurnedOn ? 'assets/ic_video_on.png' : 'assets/ic_video_off.png',
                              ),
                            )
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 10,),
                    // Data statuses
                    Padding(
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
                                  _sentDataStatus.getAccBytesString(),
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
                                  _receivedDataStatus.getAccBytesString(),
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
                                  _sentDataStatus.getRealtimeBytesString(),
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
                                  _receivedDataStatus.getRealtimeBytesString(),
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
                                  _sentDataStatus.value,
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
                                  _receivedDataStatus.value,
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
                    ),
                    Expanded(
                      child: Center(
                        child: Material(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          color: _isConnected ? AppColors.PRIMARY : AppColors.BACKGROUND_WHITE,
                          child: InkWell(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                            onTap: _onConnectButtonClicked,
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
                                  _isConnected ? 'Disconnect' : 'Connect',
                                  style: TextStyle(
                                    color: _isConnected ? AppColors.TEXT_WHITE : AppColors.TEXT_BLACK,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrim
              _isServerDialogShown ? Container(
                color: AppColors.SCRIM,
              ) : const SizedBox.shrink(),
              // Server Dialog
              _isServerDialogShown ? Center(
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
                          focusNode: _ipAddressFocusNode,
                          controller: _ipAddressEditingController,
                          style: TextStyle(
                            fontSize: 16,
                            color: _isServerDialogLoopbackChecked ? AppColors.TEXT_BLACK_LIGHT
                              : AppColors.TEXT_BLACK,
                          ),
                          decoration: null,
                          cursorColor: AppColors.TEXT_BLACK,
                          autofocus: true,
                          enabled: !_isServerDialogLoopbackChecked,
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
                          controller: _portEditingController,
                          style: TextStyle(
                            fontSize: 16,
                            color: _isServerDialogLoopbackChecked ? AppColors.TEXT_BLACK_LIGHT
                              : AppColors.TEXT_BLACK,
                          ),
                          decoration: null,
                          cursorColor: AppColors.TEXT_BLACK,
                          enabled: !_isServerDialogLoopbackChecked,
                        ),
                        const SizedBox(height: 8,),
                        Row(
                          children: <Widget>[
                            Checkbox(
                              value: _isServerDialogLoopbackChecked,
                              onChanged: _onServerDialogLoopbackCheckChanged,
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
                                  onTap: _onServerDialogCancelClicked,
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
                                  onTap: _onServerDialogOkClicked,
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

  void _onVideoIconClicked() {
    setState(() {
      _isVideoTurnedOn = !_isVideoTurnedOn;
    });
  }

  void _onConnectButtonClicked() {
    setState(() {
      _isConnected = !_isConnected;
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