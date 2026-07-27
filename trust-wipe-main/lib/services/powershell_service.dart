import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

sealed class PowerShellEvent {}

class LogEvent extends PowerShellEvent {
  final String message;
  final bool isError;
  LogEvent(this.message, {this.isError = false});
}

class ProgressEvent extends PowerShellEvent {
  final WipeProgress progress;
  ProgressEvent(this.progress);
}

class CompletedEvent extends PowerShellEvent {
  final int bytesWiped;
  final int filesWiped;
  final double durationSeconds;
  final String verificationHash;
  CompletedEvent({
    required this.bytesWiped,
    required this.filesWiped,
    required this.durationSeconds,
    required this.verificationHash,
  });
}

class ErrorEvent extends PowerShellEvent {
  final String message;
  final String code;
  ErrorEvent(this.message, this.code);
}

class PowerShellService {
  Process? _activeProcess;

  Future<bool> checkElevation() async {
    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)'
        ],
      );
      return result.stdout.toString().trim().toLowerCase() == 'true';
    } catch (e) {
      debugPrint('Error checking elevation: $e');
      return false;
    }
  }

  Future<List<WipeTarget>> detectDrives() async {
    try {
      final scriptPath = _getScriptPath();
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
          '-TargetType',
          'Detect',
        ],
      );

      if (result.exitCode != 0) {
        throw Exception('Failed to detect drives: ${result.stderr}');
      }

      final lines = const LineSplitter().convert(result.stdout.toString());
      for (final line in lines) {
        if (line.startsWith('{"type":')) {
          final Map<String, dynamic> json = jsonDecode(line);
          if (json['type'] == 'DETECTION_RESULT') {
            final drivesData = json['data']['drives'] as List<dynamic>;
            return drivesData.map((d) {
              final letter = d['DriveLetter'] as String;
              final volName = d['VolumeName'] as String? ?? '';
              final sizeGB = (d['SizeGB'] as num).toDouble();
              final freeGB = (d['FreeSpaceGB'] as num).toDouble();
              final model = d['Model'] as String? ?? 'Generic Disk';
              final isOS = d['IsOSDrive'] as bool? ?? false;
              
              return WipeTarget(
                name: '$letter ($volName)',
                path: letter,
                type: WipeTargetType.drive,
                sizeGB: sizeGB,
                extraInfo: 'Model: $model | Free: $freeGB GB | OS Drive: ${isOS ? "YES" : "NO"}',
              );
            }).toList();
          }
        }
      }
      return [];
    } catch (e) {
      debugPrint('Exception in detectDrives: $e');
      rethrow;
    }
  }

  Stream<PowerShellEvent> executeWipe(WipeTarget target, WipeAlgorithm algorithm) async* {
    final scriptPath = _getScriptPath();
    final args = [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      '-TargetType',
      _getTargetTypeName(target.type),
      '-TargetPath',
      target.path,
      '-Algorithm',
      algorithm.scriptValue,
    ];

    try {
      _activeProcess = await Process.start('powershell.exe', args);
    } catch (e) {
      yield ErrorEvent('Failed to launch PowerShell engine: $e', 'E_LAUNCH_FAILED');
      return;
    }

    final stdoutStream = _activeProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final stderrStream = _activeProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // Yield raw standard errors
    stderrStream.listen((errLine) {
      debugPrint('PowerShell Stderr: $errLine');
    });

    await for (final line in stdoutStream) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('{"type"')) {
        try {
          final Map<String, dynamic> ipc = jsonDecode(line);
          final String type = ipc['type'];
          final Map<String, dynamic> data = ipc['data'] ?? {};

          switch (type) {
            case 'INIT':
              yield LogEvent('Sanitization session initialized for target: ${data['targetPath']}');
              yield LogEvent('Using overwrite algorithm: ${data['algorithm']}');
              break;
            case 'PROGRESS':
              final progress = WipeProgress.fromJson(data);
              yield ProgressEvent(progress);
              break;
            case 'LOCKED_FILE':
              yield LogEvent('LOCKED FILE: ${data['filePath']}. ${data['message']}', isError: true);
              break;
            case 'WARN':
              yield LogEvent('WARNING: ${data['message']}');
              break;
            case 'ERROR':
              yield ErrorEvent(data['message'] ?? 'Unknown script error', data['code'] ?? 'E_UNKNOWN');
              break;
            case 'COMPLETE':
              if (data['status'] == 'SUCCESS') {
                yield CompletedEvent(
                  bytesWiped: (data['bytesWiped'] as num).toInt(),
                  filesWiped: (data['filesWipedCount'] as num).toInt(),
                  durationSeconds: (data['durationSeconds'] as num).toDouble(),
                  verificationHash: data['verificationHash'] as String? ?? '',
                );
              } else {
                yield ErrorEvent('Execution reported completion with failure.', 'E_COMPLETE_FAIL');
              }
              break;
          }
        } catch (e) {
          yield LogEvent('IPC parse error on line: $line ($e)', isError: true);
        }
      } else {
        // Output raw logs that don't match JSON structure
        yield LogEvent(line);
      }
    }

    final exitCode = await _activeProcess!.exitCode;
    _activeProcess = null;

    if (exitCode != 0) {
      yield LogEvent('PowerShell process exited with code $exitCode', isError: true);
    }
  }

  void cancelActiveWipe() {
    if (_activeProcess != null) {
      _activeProcess!.kill(ProcessSignal.sigterm);
      _activeProcess = null;
    }
  }

  String _getScriptPath() {
    // Look in workspace directories
    final devPath = 'e:\\trust-wipe\\scripts\\trust_wipe_engine.ps1';
    if (File(devPath).existsSync()) {
      return devPath;
    }
    // Fallback relative path
    return 'scripts/trust_wipe_engine.ps1';
  }

  String _getTargetTypeName(WipeTargetType type) {
    switch (type) {
      case WipeTargetType.drive:
        return 'Drive';
      case WipeTargetType.file:
        return 'File';
      case WipeTargetType.folder:
        return 'Folder';
    }
  }
}
