import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database/database.dart';
import '../utils/date_format_helper.dart';

class ContractPdfService {
  static Future<void> sharePdf({
    required Contract contract,
    required Customer customer,
    required BusinessProfile business,
  }) async {
    final bytes = await buildPdf(contract: contract, customer: customer, business: business);
    final name = _safe(contract.title);
    try {
      await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
    } catch (_) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf', name: '$name.pdf')],
          subject: contract.title,
        ),
      );
    }
  }

  static Future<void> previewPdf({
    required Contract contract,
    required Customer customer,
    required BusinessProfile business,
  }) async {
    final bytes = await buildPdf(contract: contract, customer: customer, business: business);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<Uint8List> buildPdf({
    required Contract contract,
    required Customer customer,
    required BusinessProfile business,
  }) async {
    final accent = PdfColor.fromInt(0xFF0D9488);
    final doc = pw.Document();
    final paragraphs = contract.content
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0F172A),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        business.businessName.isNotEmpty ? business.businessName : 'CLIVORA',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                      ),
                      if (business.businessEmail.isNotEmpty)
                        pw.Text(business.businessEmail, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
                    ],
                  ),
                  pw.Text('CONTRACT', style: pw.TextStyle(color: accent, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated with CLIVORA', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (context) => [
          pw.Text(contract.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F172A))),
          pw.SizedBox(height: 8),
          pw.Text('Status: ${contract.status.toUpperCase()} · Updated ${formatDisplayDate(contract.updatedAt)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Service Provider', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text(business.ownerName.isNotEmpty ? business.ownerName : business.businessName, style: const pw.TextStyle(fontSize: 10)),
                      if (business.businessEmail.isNotEmpty) pw.Text(business.businessEmail, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Client', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text(customer.contactPerson, style: const pw.TextStyle(fontSize: 10)),
                      if (customer.company.isNotEmpty) pw.Text(customer.company, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Agreement Terms', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 8),
          if (paragraphs.isEmpty)
            pw.Text(contract.content.isEmpty ? 'No terms provided.' : contract.content, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2))
          else
            ...paragraphs.map(
              (p) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(p, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
              ),
            ),
          pw.SizedBox(height: 28),
          pw.Row(
            children: [
              pw.Expanded(child: _signBlock('Provider signature')),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _signBlock('Client signature')),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _signBlock(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 40, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)))),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    );
  }

  static String _safe(String name) => name.replaceAll(RegExp(r'[^\w\-.]+'), '_');
}
