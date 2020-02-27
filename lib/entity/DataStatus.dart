
class DataStatus {
  static const NONE = DataStatus(0, 0, '');

  final int accBytes;
  final int realtimeBytes;
  final dynamic value;

  const DataStatus(this.accBytes, this.realtimeBytes, this.value);

  String getAccBytesString() {
    return accBytes.toString();
  }

  String getRealtimeBytesString() {
    return realtimeBytes.toString();
  }

  String getValueString() {
    final s = value.toString();
    if (s.length > 10) {
      return s.substring(10);
    } else {
      return s;
    }
  }

  DataStatus buildNew({
    int accBytes,
    int realtimeBytes,
    dynamic value,
  }) {
    return DataStatus(
      accBytes ?? this.accBytes,
      realtimeBytes ?? this.realtimeBytes,
      value ?? this.value,
    );
  }
}