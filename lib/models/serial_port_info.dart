class SerialPortInfo {
  final String name;
  final String description;

  const SerialPortInfo({required this.name, required this.description});

  factory SerialPortInfo.fromJson(Map<String, dynamic> json) {
    return SerialPortInfo(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SerialPortInfo && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}
