import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class CertificatePreviewDialog extends StatelessWidget {
  final WipeReport report;
  final File pdfFile;

  const CertificatePreviewDialog({
    super.key,
    required this.report,
    required this.pdfFile,
  });

  void _openPdf() {
    if (Platform.isWindows) {
      Process.run('explorer.exe', [pdfFile.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeFormat = NumberFormat('#,##0');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTheme.successEmerald, width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 580,
        height: 650,
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DATA SANITIZATION REPORT',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.successEmerald,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'TrustWipe Digital Integrity Record',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successEmerald.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.successEmerald, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: AppTheme.successEmerald, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'SECURED',
                        style: TextStyle(
                          color: AppTheme.successEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 16),

            // Certificate Details Box (Simulated Certificate)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.obsidian,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo / Certificate Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Certificate ID: ${report.certificateId}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Standard: ${report.algorithm.name}',
                                style: const TextStyle(
                                  color: AppTheme.cyberCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          // QR Code Container
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: QrImageView(
                              data: 'TrustWipe Certificate: ${report.certificateId}\nVerification Hash: ${report.verificationHash}',
                              version: QrVersions.auto,
                              size: 70.0,
                              gapless: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'SANITIZATION STATEMENT',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This document certifies that all storage segments associated with the target target below were successfully purged and overwritten. Standard read validation operations was completed with zero raw signatures detected.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[400],
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 20),

                      _buildCertificateRow('TARGET PATH', report.target.path),
                      _buildCertificateRow('TARGET TYPE', report.target.type.name.toUpperCase()),
                      _buildCertificateRow('ALGORITHM TYPE', report.algorithm.standardCode),
                      _buildCertificateRow('TOTAL BYTES OVERWRITTEN', '${sizeFormat.format(report.bytesWiped)} bytes'),
                      _buildCertificateRow('SHREDDED FILES COUNT', report.filesWipedCount.toString()),
                      _buildCertificateRow('START TIME', dateFormat.format(report.startTime.toLocal())),
                      _buildCertificateRow('COMPLETION TIME', dateFormat.format(report.endTime.toLocal())),
                      
                      const SizedBox(height: 20),
                      
                      // Cryptographic Signature Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'VERIFICATION SIGNATURE HASH (SHA-256)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.dangerRose,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              report.verificationHash,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _openPdf,
                  icon: const Icon(Icons.picture_as_pdf, color: AppTheme.cyberCyan),
                  label: const Text('Open PDF Certificate', style: TextStyle(color: AppTheme.cyberCyan)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successEmerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          const Divider(color: Color(0x1F94A3B8), height: 1),
        ],
      ),
    );
  }
}
