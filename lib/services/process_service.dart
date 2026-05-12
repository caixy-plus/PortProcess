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
      // Try ss first, then netstat fallback
      final result = await Process.run('ss', ['-tlnp']);
      if (result.exitCode == 0) {
        final parsed = _parseSsOutput(result.stdout as String);
        if (parsed.isNotEmpty) return parsed;
      }

      final netstatResult = await Process.run('netstat', ['-tlnp']);
      if (netstatResult.exitCode == 0) {
        final parsed = _parseNetstatOutput(netstatResult.stdout as String);
        if (parsed.isNotEmpty) return parsed;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<ProcessInfo>> _getWindowsProcesses() async {
    try {
      final result = await Process.run('netstat', ['-ano']);
      if (result.exitCode != 0) return [];
      final processes = _parseWindowsNetstat(result.stdout as String);
      if (processes.isEmpty) return [];

      // Fetch process names via tasklist
      final nameMap = await _getWindowsProcessNames();
      for (final p in processes) {
        if (nameMap.containsKey(p.pid)) {
          p.name = nameMap[p.pid];
        }
      }
      return processes;
    } catch (e) {
      return [];
    }
  }

  Future<Map<int, String>> _getWindowsProcessNames() async {
    try {
      final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
      if (result.exitCode != 0) return {};

      final map = <int, String>{};
      final lines = (result.stdout as String).split('\n');
      for (final line in lines) {
        final parts = line.trim().split('","');
        if (parts.length < 2) continue;
        final name = parts[0].replaceAll('"', '');
        final pidStr = parts[1].replaceAll('"', '');
        final pid = int.tryParse(pidStr);
        if (pid != null) {
          map[pid] = name;
        }
      }
      return map;
    } catch (e) {
      return {};
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
      line = line.trim();
      if (line.isEmpty) continue;

      // ss -tlnp output format varies; try multiple parsing strategies
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 5) continue;

      final protocol = parts[0].toUpperCase();

      // Find local address (usually contains a colon with port)
      String? localAddr;
      int? pid;
      String? name;

      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (localAddr == null && RegExp(r':\d+$').hasMatch(part)) {
          localAddr = part;
        }
        if (part.contains('pid=') || part.contains('users:')) {
          final pidMatch = RegExp(r'pid=(\d+)').firstMatch(part);
          if (pidMatch != null) {
            pid = int.tryParse(pidMatch.group(1)!);
          }
          final nameMatch = RegExp(r'"([^"]+)"').firstMatch(part);
          if (nameMatch != null) {
            name = nameMatch.group(1);
          }
        }
      }

      if (localAddr == null || pid == null) continue;

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
      line = line.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
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
      line = line.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
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

  /// Returns an empty string on success, or an error message on failure.
  Future<String> killProcess(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('taskkill', ['/F', '/PID', pid.toString()]);
        if (result.exitCode == 0) return '';
        final stderr = (result.stderr as String).toLowerCase();
        if (stderr.contains('access is denied')) {
          return 'Access denied: run as administrator to kill this process';
        }
        if (stderr.contains('not found')) {
          return 'Process not found (may have already exited)';
        }
        return 'Failed to kill process: ${result.stderr}';
      } else {
        final result = await Process.run('kill', ['-9', pid.toString()]);
        if (result.exitCode == 0) return '';
        final stderr = (result.stderr as String).toLowerCase();
        if (stderr.contains('operation not permitted')) {
          return 'Permission denied: run with sudo to kill this process';
        }
        if (stderr.contains('no such process')) {
          return 'Process not found (may have already exited)';
        }
        return 'Failed to kill process: ${result.stderr}';
      }
    } catch (e) {
      return 'Failed to kill process: $e';
    }
  }
}
