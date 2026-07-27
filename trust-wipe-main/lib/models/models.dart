
enum WipeTargetType { drive, file, folder }

class WipeTarget {
  final String name;
  final String path;
  final WipeTargetType type;
  final double sizeGB;
  final String? extraInfo;

  const WipeTarget({
    required this.name,
    required this.path,
    required this.type,
    required this.sizeGB,
    this.extraInfo,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'type': type.name,
        'sizeGB': sizeGB,
        'extraInfo': extraInfo,
      };

  factory WipeTarget.fromJson(Map<String, dynamic> json) => WipeTarget(
        name: json['name'] as String,
        path: json['path'] as String,
        type: WipeTargetType.values.byName(json['type'] as String),
        sizeGB: (json['sizeGB'] as num).toDouble(),
        extraInfo: json['extraInfo'] as String?,
      );
}

enum WipeAlgorithmType {
  zeroFill,
  randomFill,
  dod522022m,
  nist80088,
}

class WipeAlgorithm {
  final WipeAlgorithmType type;
  final String name;
  final String description;
  final int passes;
  final String standardCode;

  const WipeAlgorithm({
    required this.type,
    required this.name,
    required this.description,
    required this.passes,
    required this.standardCode,
  });

  String get scriptValue {
    switch (type) {
      case WipeAlgorithmType.zeroFill:
        return 'ZeroFill';
      case WipeAlgorithmType.randomFill:
        return 'RandomFill';
      case WipeAlgorithmType.dod522022m:
        return 'DoD522022M';
      case WipeAlgorithmType.nist80088:
        return 'NIST80088';
    }
  }

  static const List<WipeAlgorithm> availableAlgorithms = [
    WipeAlgorithm(
      type: WipeAlgorithmType.nist80088,
      name: 'NIST SP 800-88 Rev 1 (Clear)',
      description: 'Standard recommendation for logical data sanitization. Single-pass zero-fill with full read verification.',
      passes: 1,
      standardCode: 'NIST SP 800-88',
    ),
    WipeAlgorithm(
      type: WipeAlgorithmType.zeroFill,
      name: 'Single Pass Zero Fill',
      description: 'Writes zeros (0x00) across all storage sectors. Quick protection against basic software recovery tools.',
      passes: 1,
      standardCode: 'Zero Fill',
    ),
    WipeAlgorithm(
      type: WipeAlgorithmType.randomFill,
      name: 'Single Pass Random Fill',
      description: 'Writes pseudo-random cryptographic data across target. Overwrites magnetic/solid-state signatures.',
      passes: 1,
      standardCode: 'Random Overwrite',
    ),
    WipeAlgorithm(
      type: WipeAlgorithmType.dod522022m,
      name: 'DoD 5220.22-M (3-Pass)',
      description: 'US Department of Defense standard. Writes Zeros, Ones (0xFF), then Random bytes, followed by verification.',
      passes: 3,
      standardCode: 'DoD 5220.22-M',
    ),
  ];
}

class WipeProgress {
  final double percent;
  final int bytesProcessed;
  final double speedMBps;
  final int filesProcessed;
  final String currentFilePath;

  const WipeProgress({
    required this.percent,
    required this.bytesProcessed,
    required this.speedMBps,
    required this.filesProcessed,
    required this.currentFilePath,
  });

  factory WipeProgress.fromJson(Map<String, dynamic> json) {
    return WipeProgress(
      percent: (json['percent'] as num).toDouble(),
      bytesProcessed: (json['bytesProcessed'] as num).toInt(),
      speedMBps: (json['speedMBps'] as num).toDouble(),
      filesProcessed: (json['filesProcessed'] as num).toInt(),
      currentFilePath: json['currentFilePath'] as String? ?? '',
    );
  }
}

class WipeReport {
  final String certificateId;
  final WipeTarget target;
  final WipeAlgorithm algorithm;
  final DateTime startTime;
  final DateTime endTime;
  final int bytesWiped;
  final int filesWipedCount;
  final String verificationHash;
  final String status;

  const WipeReport({
    required this.certificateId,
    required this.target,
    required this.algorithm,
    required this.startTime,
    required this.endTime,
    required this.bytesWiped,
    required this.filesWipedCount,
    required this.verificationHash,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'certificateId': certificateId,
        'target': target.toJson(),
        'algorithm': algorithm.type.name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'bytesWiped': bytesWiped,
        'filesWipedCount': filesWipedCount,
        'verificationHash': verificationHash,
        'status': status,
      };
}
