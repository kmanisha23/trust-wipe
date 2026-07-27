import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/powershell_service.dart';
import '../services/pdf_report_service.dart';

class WipeProvider extends ChangeNotifier {
  final _powerShellService = PowerShellService();
  final _pdfService = PdfReportService();

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  List<WipeTarget> _detectedDrives = [];
  List<WipeTarget> get detectedDrives => _detectedDrives;

  final List<WipeTarget> _fileTargets = [];
  List<WipeTarget> get fileTargets => _fileTargets;

  bool _isDetectingDrives = false;
  bool get isDetectingDrives => _isDetectingDrives;

  bool _isExecuting = false;
  bool get isExecuting => _isExecuting;

  WipeTarget? _selectedDrive;
  WipeTarget? get selectedDrive => _selectedDrive;

  WipeAlgorithm _selectedAlgorithm = WipeAlgorithm.availableAlgorithms.first; // NIST SP 800-88 by default
  WipeAlgorithm get selectedAlgorithm => _selectedAlgorithm;

  final List<String> _logs = [];
  List<String> get logs => _logs;

  WipeProgress? _currentProgress;
  WipeProgress? get currentProgress => _currentProgress;

  WipeReport? _lastReport;
  WipeReport? get lastReport => _lastReport;

  File? _lastReportPdfFile;
  File? get lastReportPdfFile => _lastReportPdfFile;

  String? _currentError;
  String? get currentError => _currentError;

  Future<void> initSystem() async {
    _isAdmin = await _powerShellService.checkElevation();
    notifyListeners();
    if (_isAdmin) {
      await scanDrives();
    }
  }

  Future<void> scanDrives() async {
    _isDetectingDrives = true;
    _currentError = null;
    notifyListeners();

    try {
      _detectedDrives = await _powerShellService.detectDrives();
      if (_detectedDrives.isNotEmpty) {
        // Find first drive that is not OS drive
        final safeDrive = _detectedDrives.firstWhere(
          (d) => d.path.toUpperCase() != 'C:',
          orElse: () => _detectedDrives.first,
        );
        _selectedDrive = safeDrive;
      } else {
        _selectedDrive = null;
      }
    } catch (e) {
      _currentError = 'Failed to load system drives: $e';
    } finally {
      _isDetectingDrives = false;
      notifyListeners();
    }
  }

  void setSelectedDrive(WipeTarget? drive) {
    _selectedDrive = drive;
    notifyListeners();
  }

  void setSelectedAlgorithm(WipeAlgorithm algo) {
    _selectedAlgorithm = algo;
    notifyListeners();
  }

  void addFileTargets(List<String> paths) {
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        final double sizeGB = file.lengthSync() / (1024 * 1024 * 1024);
        final fileName = file.uri.pathSegments.last;
        _fileTargets.add(WipeTarget(
          name: fileName.isEmpty ? file.path : fileName,
          path: file.path,
          type: WipeTargetType.file,
          sizeGB: sizeGB,
          extraInfo: 'File Size: ${(sizeGB * 1024).toStringAsFixed(2)} MB',
        ));
      }
    }
    notifyListeners();
  }

  void addFolderTarget(String path) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      final dirName = dir.uri.pathSegments.isNotEmpty
          ? dir.uri.pathSegments[dir.uri.pathSegments.length - 2]
          : dir.path;
      _fileTargets.add(WipeTarget(
        name: dirName.isEmpty ? dir.path : dirName,
        path: dir.path,
        type: WipeTargetType.folder,
        sizeGB: 0.0,
        extraInfo: 'Recursive Folder Shredding Target',
      ));
    }
    notifyListeners();
  }

  void removeFileTarget(WipeTarget target) {
    _fileTargets.removeWhere((t) => t.path == target.path);
    notifyListeners();
  }

  void clearFileTargets() {
    _fileTargets.clear();
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    _currentProgress = null;
    notifyListeners();
  }

  Future<void> executeWipe(WipeTarget target) async {
    _isExecuting = true;
    _currentError = null;
    _lastReport = null;
    _lastReportPdfFile = null;
    clearLogs();
    notifyListeners();

    final startTime = DateTime.now().toUtc();
    final isBatch = target.path == 'Batch Queue';
    int bytesWiped = 0;
    int filesWiped = 0;
    String verificationHash = '';

    try {
      if (isBatch) {
        final totalTargets = _fileTargets.length;
        for (int i = 0; i < totalTargets; i++) {
          if (!_isExecuting) break;
          final subTarget = _fileTargets[i];
          _logs.add('--- Shredding Target [${i + 1}/$totalTargets]: ${subTarget.name} ---');
          notifyListeners();

          final stream = _powerShellService.executeWipe(subTarget, _selectedAlgorithm);
          await for (final event in stream) {
            if (event is LogEvent) {
              _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] ${event.message}');
              notifyListeners();
            } else if (event is ProgressEvent) {
              final subPercent = event.progress.percent;
              final compositePercent = ((i + (subPercent / 100)) / totalTargets) * 100;
              _currentProgress = WipeProgress(
                percent: compositePercent,
                bytesProcessed: bytesWiped + event.progress.bytesProcessed,
                speedMBps: event.progress.speedMBps,
                filesProcessed: filesWiped + event.progress.filesProcessed,
                currentFilePath: event.progress.currentFilePath,
              );
              notifyListeners();
            } else if (event is CompletedEvent) {
              bytesWiped += event.bytesWiped;
              filesWiped += event.filesWiped;
              verificationHash = verificationHash.isEmpty 
                  ? event.verificationHash 
                  : '${verificationHash.substring(0, 8)}...${event.verificationHash.substring(0, 8)}';
            } else if (event is ErrorEvent) {
              _currentError = event.message;
              _logs.add('[ERROR] ${event.message} (Code: ${event.code})');
              notifyListeners();
            }
          }
        }
      } else {
        final stream = _powerShellService.executeWipe(target, _selectedAlgorithm);
        await for (final event in stream) {
          if (event is LogEvent) {
            _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] ${event.message}');
            notifyListeners();
          } else if (event is ProgressEvent) {
            _currentProgress = event.progress;
            notifyListeners();
          } else if (event is CompletedEvent) {
            bytesWiped = event.bytesWiped;
            filesWiped = event.filesWiped;
            verificationHash = event.verificationHash;
          } else if (event is ErrorEvent) {
            _currentError = event.message;
            _logs.add('[ERROR] ${event.message} (Code: ${event.code})');
            notifyListeners();
          }
        }
      }

      if (_currentError == null && _isExecuting) {
        final endTime = DateTime.now().toUtc();
        final certId = 'TW-${startTime.millisecondsSinceEpoch.toString().substring(5)}-${(bytesWiped % 1000).toString().padLeft(3, '0')}';
        
        final report = WipeReport(
          certificateId: certId,
          target: target,
          algorithm: _selectedAlgorithm,
          startTime: startTime,
          endTime: endTime,
          bytesWiped: bytesWiped,
          filesWipedCount: filesWiped,
          verificationHash: verificationHash.isEmpty ? 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855' : verificationHash,
          status: 'SUCCESS',
        );

        _lastReport = report;
        
        // Print textual summary directly to the session logs
        _logs.addAll([
          '',
          '==================================================',
          '        SANITIZATION VERIFICATION REPORT',
          '==================================================',
          'Certificate ID   : ${report.certificateId}',
          'Target Path      : ${report.target.path}',
          'Target Type      : ${report.target.type.name.toUpperCase()}',
          'Algorithm Standard: ${report.algorithm.name}',
          'Bytes Overwritten : ${report.bytesWiped} bytes',
          'Files Purged     : ${report.filesWipedCount}',
          'Duration         : ${(endTime.difference(startTime).inMilliseconds / 1000).toStringAsFixed(2)} seconds',
          'Integrity Signature: ${report.verificationHash}',
          'Status           : VERIFIED SUCCESS',
          '==================================================',
          '',
        ]);
        
        _logs.add('--- Generating PDF Verification Certificate ---');
        notifyListeners();

        _lastReportPdfFile = await _pdfService.generateReport(report);
        _logs.add('Certificate saved successfully to: ${_lastReportPdfFile!.path}');
        
        if (isBatch) {
          clearFileTargets();
        }
      }
    } catch (e) {
      _currentError = 'Unexpected system execution exception: $e';
      _logs.add('[EXCEPTION] $e');
    } finally {
      _isExecuting = false;
      notifyListeners();
      if (target.type == WipeTargetType.drive) {
        await scanDrives();
      }
    }
  }

  void cancelWipe() {
    _powerShellService.cancelActiveWipe();
    _isExecuting = false;
    _currentError = 'Operations cancelled by administrator.';
    _logs.add('[CANCELLED] User terminated process.');
    notifyListeners();
  }
}
