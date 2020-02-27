
class DataStatus {
  static const NONE = DataStatus(0, 0, '');

  final int accBytes;
  final int realtimeBytes;
  final String value;

  const DataStatus(this.accBytes, this.realtimeBytes, this.value);

  String getAccBytesString() {
    return accBytes.toString();
  }

  String getRealtimeBytesString() {
    return realtimeBytes.toString();
  }
}