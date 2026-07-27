import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

class PdfReportService {
  Future<File> generateReport(WipeReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.indigo900, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TRUSTWIPE DATA SANITIZATION CERTIFICATE',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Official Secure Erase Verification Document',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#10B981'),
                      ),
                      child: pw.Text(
                        'VERIFIED SUCCESS',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 15),

                // Main Info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Certificate ID', report.certificateId),
                          _buildDetailRow('Sanitization Date', _formatDateTime(report.endTime)),
                          _buildDetailRow('Sanitization Standard', report.algorithm.name),
                          _buildDetailRow('Target Storage Type', report.target.type.name.toUpperCase()),
                          _buildDetailRow('Target Path', report.target.path),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Align(
                        alignment: pw.Alignment.topRight,
                        child: pw.Container(
                          width: 100,
                          height: 100,
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: 'TrustWipe Certificate: ${report.certificateId}\nVerification Hash: ${report.verificationHash}\nStandard: ${report.algorithm.standardCode}\nWiped: ${report.bytesWiped} bytes',
                            drawText: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 25),
                pw.Text(
                  'SANITIZATION METRICS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 8),
                
                // Table of Metrics
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Total Data Overwritten', '${(report.bytesWiped / (1024 * 1024)).toStringAsFixed(2)} MB (${report.bytesWiped} bytes)'),
                    _buildTableRow('Files Permanently Shredded', report.filesWipedCount.toString()),
                    _buildTableRow('Sanitization Passes Done', '${report.algorithm.passes} Pass(es)'),
                    _buildTableRow('Execution Duration', '${(report.endTime.difference(report.startTime).inMilliseconds / 1000).toStringAsFixed(2)} seconds'),
                  ],
                ),

                pw.SizedBox(height: 25),
                
                // Security / Hash Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CRYPTOGRAPHIC INTEGRITY SIGNATURE',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        report.verificationHash,
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontSize: 9,
                          color: PdfColors.red900,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'This signature verifies that the selected data target was completely overwritten and overwritten blocks were verified to prevent any mathematical file reconstruction. Re-mounting or deep scanning this device will find no structural trace of original records.',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 10),

                // Footer legal info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TrustWipe Sanitization Suite v1.0.0',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                    pw.Text(
                      'Verification Conformance: ${report.algorithm.standardCode}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Save PDF automatically to default folder: Documents/TrustWipe_Reports
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final targetFolder = Directory(p.join(documentsDir.path, 'TrustWipe_Reports'));
      if (!targetFolder.existsSync()) {
        targetFolder.createSync(recursive: true);
      }
      final file = File(p.join(targetFolder.path, 'TrustWipe_Cert_${report.certificateId}.pdf'));
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      debugPrint('Failed to save PDF automatically: $e');
      // Fallback: save to temp directory
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, 'TrustWipe_Cert_${report.certificateId}.pdf'));
      await file.writeAsBytes(await pdf.save());
      return file;
    }
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} UTC';
  }
}
