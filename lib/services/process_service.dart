import 'dart:async';
import 'dart:io';

import '../models/process_info.dart';

class ProcessService {
  static final ProcessService _instance = ProcessService._internal();
  factory ProcessService() => _instance;
  ProcessService._internal();

  Future<List<ProcessInfo>> getListeningProcesses() async {
    if (Platform.isMacOS) {
      return _getMacOSProcesses();
    } else if (Platform.isLinux) {
      return _getLinuxProcesses();
    } else if (Platform.isWindows) {
      return _getWindowsProcesses();
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  Future<List<ProcessInfo>> _getMacOSProcesses() async {
    try {
      final result = await Process.run('lsof', ['-iTCP', '-sTCP:LISTEN', '-P', '-n']);
      if (result.exitCode != 0) return [];
      return _parseLsofOutput(result.stdout as String);
    } catch (e) {
      return [];
    }
  }

  Future<List<ProcessInfo>> _getLinuxProcesses() async {
    try {
      final result = await Process.run('ss', ['-tlnp']);
      if (result.exitCode != 0) {
        final netstatResult = await Process.run('netstat', ['-tlnp']);
        if (netstatResult.exitCode != 0) return [];
        return _parseNetstatOutput(netstatResult.stdout as String);
      }
      return _parseSsOutput(result.stdout as String);
    } catch (e) {
      return [];
    }
  }

  Future<List<ProcessInfo>> _getWindowsProcesses() async {
    try {
      final result = await Process.run('netstat', ['-ano']);
      if (result.exitCode != 0) return [];
      return _parseWindowsNetstat(result.stdout as String);
    } catch (e) {
      return [];
    }
  }

  List<ProcessInfo> _parseLsofOutput(String output) {
    final processes = <ProcessInfo>[];
    final lines = output.split('\n');
    final seen = <String>{};

    for (var line in lines.skip(1)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 9) continue;

      final name = parts[0];
      final pid = int.tryParse(parts[1]);
      final protocol = parts[7].toLowerCase();
      final addressPart = parts[8];

      if (pid == null) continue;

      final portMatch = RegExp(r':(\d+)$').firstMatch(addressPart);
      if (portMatch == null) continue;
      final port = int.tryParse(portMatch.group(1)!);
      if (port == null) continue;

      final key = '$pid-$port';
      if (seen.contains(key)) continue;
      seen.add(key);

      processes.add(ProcessInfo(
        pid: pid,
        port: port,
        protocol: protocol.contains('tcp') ? 'TCP' : 'UDP',
        name: name,
        address: addressPart,
      ));
    }

    return processes;
  }

  List<ProcessInfo> _parseSsOutput(String output) {
    final processes = <ProcessInfo>[];
    final lines = output.split('\n');
    final seen = <String>{};

    for (var line in lines.skip(1)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 6) continue;

      final protocol = parts[0].toUpperCase();
      final localAddr = parts[4];
      final processPart = parts.length > 6 ? parts[6] : '';

      final portMatch = RegExp(r':(\d+)$').firstMatch(localAddr);
      if (portMatch == null) continue;
      final port = int.tryParse(portMatch.group(1)!);
      if (port == null) continue;

      int? pid;
      String? name;
      final pidMatch = RegExp(r'pid=(\d+)').firstMatch(processPart);
      if (pidMatch != null) {
        pid = int.tryParse(pidMatch.group(1)!);
      }
      final nameMatch = RegExp(r'"([^"]+)"').firstMatch(processPart);
      if (nameMatch != null) {
        name = nameMatch.group(1);
      }

      if (pid == null) continue;

      final key = '$pid-$port';
      if (seen.contains(key)) continue;
      seen.add(key);

      processes.add(ProcessInfo(
        pid: pid,
        port: port,
        protocol: protocol.contains('TCP') ? 'TCP' : 'UDP',
        name: name,
        address: localAddr,
      ));
    }

    return processes;
  }

  List<ProcessInfo> _parseNetstatOutput(String output) {
    final processes = <ProcessInfo>[];
    final lines = output.split('\n');
    final seen = <String>{};

    for (var line in lines.skip(2)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 7) continue;

      final protocol = parts[0].toUpperCase();
      final localAddr = parts[3];
      final pidProgram = parts[6];

      final portMatch = RegExp(r':(\d+)$').firstMatch(localAddr);
      if (portMatch == null) continue;
      final port = int.tryParse(portMatch.group(1)!);
      if (port == null) continue;

      final pidParts = pidProgram.split('/');
      final pid = int.tryParse(pidParts[0]);
      if (pid == null) continue;

      final name = pidParts.length > 1 ? pidParts[1] : null;

      final key = '$pid-$port';
      if (seen.contains(key)) continue;
      seen.add(key);

      processes.add(ProcessInfo(
        pid: pid,
        port: port,
        protocol: protocol.contains('TCP') ? 'TCP' : 'UDP',
        name: name,
        address: localAddr,
      ));
    }

    return processes;
  }

  List<ProcessInfo> _parseWindowsNetstat(String output) {
    final processes = <ProcessInfo>[];
    final lines = output.split('\n');
    final seen = <String>{};

    for (var line in lines.skip(4)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) continue;

      final protocol = parts[0].toUpperCase();
      final localAddr = parts[1];
      final state = parts[3];
      final pid = int.tryParse(parts[4]);

      if (pid == null) continue;
      if (!state.toUpperCase().contains('LISTEN')) continue;

      final portMatch = RegExp(r':(\d+)$').firstMatch(localAddr);
      if (portMatch == null) continue;
      final port = int.tryParse(portMatch.group(1)!);
      if (port == null) continue;

      final key = '$pid-$port';
      if (seen.contains(key)) continue;
      seen.add(key);

      processes.add(ProcessInfo(
        pid: pid,
        port: port,
        protocol: protocol.contains('TCP') ? 'TCP' : 'UDP',
        address: localAddr,
      ));
    }

    return processes;
  }

  Future<bool> killProcess(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('taskkill', ['/F', '/PID', pid.toString()]);
        return result.exitCode == 0;
      } else {
        final result = await Process.run('kill', ['-9', pid.toString()]);
        return result.exitCode == 0;
      }
    } catch (e) {
      return false;
    }
  }
}
