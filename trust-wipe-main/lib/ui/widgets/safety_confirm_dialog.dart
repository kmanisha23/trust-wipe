import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class SafetyConfirmDialog extends StatefulWidget {
  final WipeTarget target;
  final WipeAlgorithm algorithm;

  const SafetyConfirmDialog({
    super.key,
    required this.target,
    required this.algorithm,
  });

  @override
  State<SafetyConfirmDialog> createState() => _SafetyConfirmDialogState();
}

class _SafetyConfirmDialogState extends State<SafetyConfirmDialog> {
  final _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTheme.dangerRose, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning Icon & Header
              Row(
                children: [
                  const Icon(Icons.gpp_bad, color: AppTheme.dangerRose, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    'CRITICAL WARNING',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.dangerRose,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Warning Content
              Text(
                'You are initiating a permanent destructive operation. This cannot be undone. Data will be completely unrecoverable.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 16),

              // Target Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x0AEF4444),
                  border: Border.all(color: AppTheme.dangerRose.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetaItem('Sanitization Target', widget.target.path),
                    _buildMetaItem('Target Type', widget.target.type.name.toUpperCase()),
                    _buildMetaItem('Total Size', widget.target.type == WipeTargetType.drive 
                        ? '${widget.target.sizeGB} GB' 
                        : widget.target.extraInfo ?? 'Unknown size'),
                    _buildMetaItem('Wipe Method', widget.algorithm.name),
                    _buildMetaItem('Conforming Code', widget.algorithm.standardCode),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Confirm Instruction
              Text(
                'To verify this destruction command, please type "CONFIRM" below:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 10),

              // Text Field
              TextField(
                controller: _controller,
                onChanged: (text) {
                  setState(() {
                    _canConfirm = text.trim() == 'CONFIRM';
                  });
                },
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type CONFIRM',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                  filled: true,
                  fillColor: const Color(0xFF05070C),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.dangerRose),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerRose,
                      disabledBackgroundColor: AppTheme.dangerRose.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_forever, size: 18),
                        SizedBox(width: 8),
                        Text('Confirm Wipe'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: context.mounted ? CrossAxisAlignment.start : CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
