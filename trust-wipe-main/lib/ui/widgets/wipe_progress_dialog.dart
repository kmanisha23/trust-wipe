import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../state/wipe_provider.dart';
import '../../theme/app_theme.dart';
import 'certificate_preview_dialog.dart';

class WipeProgressDialog extends StatefulWidget {
  final WipeTarget target;
  final WipeProvider provider;

  const WipeProgressDialog({
    super.key,
    required this.target,
    required this.provider,
  });

  @override
  State<WipeProgressDialog> createState() => _WipeProgressDialogState();
}

class _WipeProgressDialogState extends State<WipeProgressDialog> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startWipeOperation();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startWipeOperation() {
    widget.provider.executeWipe(widget.target).then((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.provider;
    final progress = state.currentProgress;
    
    // Auto scroll logs
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final isDone = !state.isExecuting && state.lastReport != null;
    final isFail = !state.isExecuting && state.currentError != null;

    final numberFormat = NumberFormat('#,##0');

    return PopScope(
      canPop: !state.isExecuting,
      child: Dialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isDone 
                ? AppTheme.successEmerald 
                : isFail 
                    ? AppTheme.dangerRose 
                    : AppTheme.cyberIndigo, 
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Container(
            width: 650,
            height: 580,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (state.isExecuting)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else if (isDone)
                          const Icon(Icons.verified, color: AppTheme.successEmerald, size: 28)
                        else
                          const Icon(Icons.report_problem, color: AppTheme.dangerRose, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          state.isExecuting
                              ? 'SECURE OVERWRITE IN PROGRESS'
                              : isDone
                                  ? 'SANITIZATION SUCCESSFUL'
                                  : 'OPERATION TERMINATED',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: isDone 
                                    ? AppTheme.successEmerald 
                                    : isFail 
                                        ? AppTheme.dangerRose 
                                        : Colors.white,
                              ),
                        ),
                      ],
                    ),
                    Text(
                      'Target: ${widget.target.path}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Progress Bar & Percentage
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress != null ? (progress.percent / 100) : 0,
                          minHeight: 12,
                          backgroundColor: AppTheme.cardBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDone 
                                ? AppTheme.successEmerald 
                                : isFail 
                                    ? AppTheme.dangerRose 
                                    : AppTheme.cyberIndigo,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${progress != null ? progress.percent.toStringAsFixed(1) : 0.0}%',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Real-time Metrics Grid
                Row(
                  children: [
                    _buildMetricCard(
                      'OVERWRITE SPEED',
                      '${progress != null ? progress.speedMBps.toStringAsFixed(1) : 0.0} MB/s',
                      Icons.speed,
                      AppTheme.cyberCyan,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      'BYTES WRITTEN',
                      progress != null ? _formatBytes(progress.bytesProcessed) : '0 B',
                      Icons.storage,
                      AppTheme.cyberIndigo,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      'FILES PURGED',
                      progress != null ? numberFormat.format(progress.filesProcessed) : '0',
                      Icons.delete_sweep,
                      AppTheme.successEmerald,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Current File Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF05070C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          progress != null && progress.currentFilePath.isNotEmpty
                              ? progress.currentFilePath
                              : 'Resolving target write blocks...',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Terminal Shell Logs
                Expanded(
                  child: Container(
                    decoration: AppTheme.terminalDecoration(),
                    padding: const EdgeInsets.all(12),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: state.logs.length,
                      itemBuilder: (context, index) {
                        final log = state.logs[index];
                        final isErrorLog = log.contains('[ERROR]') || log.contains('[EXCEPTION]');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: isErrorLog ? AppTheme.dangerRose : const Color(0xFF38BDF8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Footer Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (state.isExecuting)
                      ElevatedButton.icon(
                        onPressed: state.cancelWipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerRose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel Operations'),
                      )
                    else ...[
                      if (isDone)
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => CertificatePreviewDialog(
                                report: state.lastReport!,
                                pdfFile: state.lastReportPdfFile!,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successEmerald,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.workspace_premium, size: 18),
                          label: const Text('View Certification'),
                        ).animate().shimmer(),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close Terminal', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.obsidian,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
