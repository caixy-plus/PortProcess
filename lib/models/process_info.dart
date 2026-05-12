class ProcessInfo {
  final int pid;
  final int port;
  final String protocol;
  String? name;
  final String? address;

  ProcessInfo({
    required this.pid,
    required this.port,
    required this.protocol,
    this.name,
    this.address,
  });

  @override
  String toString() {
    return 'ProcessInfo(pid: $pid, port: $port, protocol: $protocol, name: $name)';
  }
}
