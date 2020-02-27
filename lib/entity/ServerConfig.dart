
class ServerConfig {
  static const LOOPBACK_IP = '127.0.0.1';
  static const LOOPBACK_PORT = '5555';

  static const LOOPBACK = ServerConfig(LOOPBACK_IP, LOOPBACK_PORT);

  final String ipAddress;
  final String port;

  const ServerConfig(this.ipAddress, this.port);

  bool isLoopback() => ipAddress == LOOPBACK_IP && port == LOOPBACK_PORT;
}