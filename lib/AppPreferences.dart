
import 'package:fb_app/entity/ServerConfig.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const KEY_IP_ADDRESS = 'ip.address';
  static const KEY_PORT = 'port';
  static const KEY_MIC_ENABLED = 'mic.enabled';
  static const KEY_VIDEO_ENABLED = 'video.enabled';

  static Future<String> getIpAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(KEY_IP_ADDRESS) ?? ServerConfig.LOOPBACK_IP;
  }

  static Future<void> setIpAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(KEY_IP_ADDRESS, value);
  }

  static Future<String> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(KEY_PORT) ?? ServerConfig.LOOPBACK_PORT;
  }

  static Future<void> setPort(String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(KEY_PORT, value);
  }

  static Future<bool> getMicEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_MIC_ENABLED) ?? false;
  }

  static Future<void> setMicEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(KEY_MIC_ENABLED, value);
  }

  static Future<bool> getVideoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_VIDEO_ENABLED) ?? false;
  }

  static Future<void> setVideoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(KEY_VIDEO_ENABLED, value);
  }

}