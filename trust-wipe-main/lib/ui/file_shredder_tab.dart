import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/wipe_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/safety_confirm_dialog.dart';
import 'widgets/wipe_progress_dialog.dart';

class FileShredderTab extends StatelessWidget {
  final WipeProvider provider;

  const FileShredderTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final targets = provider.fileTargets;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassDecoration(
              color: AppTheme.cyberIndigo.withOpacity(0.06),
              borderColor: AppTheme.cyberIndigo.withOpacity(0.3),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.cyberCyan, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Targeted Secure File & Folder Shredding',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.cyberCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Secure shredding overwrites files in-place and randomizes their filesystem metadata before deletion. Safely targets folders recursively.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Layout Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (List of File Targets)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SHREDDING QUEUE (${targets.length} targets)',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        if (targets.isNotEmpty)
                          TextButton(
                            onPressed: provider.isExecuting ? null : provider.clearFileTargets,
                            child: const Text('Clear Queue', style: TextStyle(color: AppTheme.dangerRose, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selector Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: provider.isExecuting ? null : () => _pickFiles(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.cardBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.note_add_outlined, color: AppTheme.cyberCyan),
                            label: const Text('Add Files', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: provider.isExecuting ? null : () => _pickFolder(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.cardBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.create_new_folder_outlined, color: AppTheme.cyberIndigo),
                            label: const Text('Add Folder', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Queue List Card
                    Container(
                      height: 280,
                      decoration: AppTheme.terminalDecoration(),
                      child: targets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.drive_folder_upload, color: AppTheme.textSecondary.withOpacity(0.3), size: 48),
                                  const SizedBox(height: 12),
                                  const Text('Queue is empty. Select files or folder targets to shred.',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemCount: targets.length,
                              separatorBuilder: (context, index) => const Divider(color: Color(0x1F94A3B8), height: 1),
                              itemBuilder: (context, index) {
                                final target = targets[index];
                                final isFolder = target.type == WipeTargetType.folder;
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isFolder ? Icons.folder : Icons.insert_drive_file,
                                    color: isFolder ? AppTheme.cyberIndigo : AppTheme.cyberCyan,
                                    size: 20,
                                  ),
                                  title: Text(
                                    target.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    target.path,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    onPressed: provider.isExecuting ? null : () => provider.removeFileTarget(target),
                                    icon: const Icon(Icons.close, color: AppTheme.dangerRose, size: 18),
                                    tooltip: 'Remove from queue',
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right Column (Wiping Standard Selector)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SANITIZATION ALGORITHM',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    ...WipeAlgorithm.availableAlgorithms.map((algo) {
                      final isSelected = provider.selectedAlgorithm.type == algo.type;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: InkWell(
                          onTap: provider.isExecuting ? null : () => provider.setSelectedAlgorithm(algo),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.cyberIndigo.withOpacity(0.08) : AppTheme.cardDark,
                              border: Border.all(
                                color: isSelected ? AppTheme.cyberIndigo : AppTheme.cardBorder,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? AppTheme.cyberIndigo : AppTheme.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            algo.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppTheme.cyberIndigo.withOpacity(0.2) : AppTheme.cardBorder,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${algo.passes} Pass',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? AppTheme.cyberIndigo : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        algo.description,
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action Button
          ElevatedButton.icon(
            onPressed: targets.isEmpty || provider.isExecuting ? null : () => _confirmAndShred(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyberIndigo,
              disabledBackgroundColor: AppTheme.cardBorder,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: 4,
            ),
            icon: const Icon(Icons.security, size: 24),
            label: Text(
              targets.isNotEmpty 
                  ? 'SHRED AND CERTIFY ${targets.length} SELECTED TARGETS' 
                  : 'ADD QUEUE TARGETS TO BEGIN',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        dialogTitle: 'Select files to permanently shred',
      );
      if (result != null && result.paths.isNotEmpty) {
        final List<String> paths = result.paths.whereType<String>().toList();
        provider.addFileTargets(paths);
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  Future<void> _pickFolder(BuildContext context) async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to recursively shred',
      );
      if (path != null) {
        provider.addFolderTarget(path);
      }
    } catch (e) {
      debugPrint('Error picking directory: $e');
    }
  }

  void _confirmAndShred(BuildContext context) async {
    final targets = provider.fileTargets;
    if (targets.isEmpty) return;

    if (!provider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Administrative privileges required. Run application as Administrator.'),
          backgroundColor: AppTheme.dangerRose,
        ),
      );
      return;
    }

    final batchTarget = WipeTarget(
      name: 'Shredding Queue',
      path: 'Batch Queue',
      type: WipeTargetType.file,
      sizeGB: 0,
      extraInfo: 'Batch of ${targets.length} targets',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SafetyConfirmDialog(
        target: batchTarget,
        algorithm: provider.selectedAlgorithm,
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WipeProgressDialog(
          target: batchTarget,
          provider: provider,
        ),
      );
    }
  }
}
