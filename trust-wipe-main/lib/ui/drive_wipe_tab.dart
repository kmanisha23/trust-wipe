import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/wipe_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/safety_confirm_dialog.dart';
import 'widgets/wipe_progress_dialog.dart';

class DriveWipeTab extends StatelessWidget {
  final WipeProvider provider;

  const DriveWipeTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final drives = provider.detectedDrives;
    final selectedDrive = provider.selectedDrive;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassDecoration(
              color: AppTheme.dangerRose.withOpacity(0.06),
              borderColor: AppTheme.dangerRose.withOpacity(0.3),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRose, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WARNING: Drive Overwriting is Permanent',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.dangerRose,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Wiping a drive overwrites all storage blocks. This includes partitioning details, filesystems, and unallocated spaces. Operating System drives are blocked automatically.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Row: Left Column (Drives + Info), Right Column (Algorithms)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Select Target)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SELECT DRIVE TARGET',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.storage, color: AppTheme.cyberIndigo),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<WipeTarget>(
                                  value: selectedDrive,
                                  isExpanded: true,
                                  dropdownColor: AppTheme.cardDark,
                                  hint: const Text('Select a physical drive...'),
                                  onChanged: provider.isExecuting
                                      ? null
                                      : (value) => provider.setSelectedDrive(value),
                                  items: drives.map((drive) {
                                    return DropdownMenuItem<WipeTarget>(
                                      value: drive,
                                      child: Text(
                                        '${drive.path} - ${drive.name} (${drive.sizeGB.toStringAsFixed(1)} GB)',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: provider.isDetectingDrives ? null : provider.scanDrives,
                              icon: provider.isDetectingDrives
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, color: AppTheme.cyberCyan),
                              tooltip: 'Rescan storage drives',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Drive Information card
                    if (selectedDrive != null) ...[
                      Text(
                        'DRIVE METADATA',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: AppTheme.obsidian,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetadataRow('Volume Label', selectedDrive.name),
                              _buildMetadataRow('Device Mount Path', selectedDrive.path),
                              _buildMetadataRow('Total Disk Capacity', '${selectedDrive.sizeGB} GB'),
                              _buildMetadataRow('Hardware Telemetry', selectedDrive.extraInfo ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right Column (Wiping Standards)
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

          // Start Wipe Actions Button
          ElevatedButton.icon(
            onPressed: selectedDrive == null || provider.isExecuting ? null : () => _confirmAndWipe(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRose,
              disabledBackgroundColor: AppTheme.cardBorder,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: 4,
            ),
            icon: const Icon(Icons.lock_reset, size: 24),
            label: Text(
              selectedDrive != null 
                  ? 'WIPE AND CERTIFY DRIVE ${selectedDrive.path}' 
                  : 'SELECT DRIVE TARGET TO BEGIN',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndWipe(BuildContext context) async {
    final target = provider.selectedDrive;
    if (target == null) return;

    // Check if elevation is correct
    if (!provider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Administrative privileges required. Run application as Administrator.'),
          backgroundColor: AppTheme.dangerRose,
        ),
      );
      return;
    }

    // Safety Confirm Modal
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SafetyConfirmDialog(
        target: target,
        algorithm: provider.selectedAlgorithm,
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WipeProgressDialog(
          target: target,
          provider: provider,
        ),
      );
    }
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
