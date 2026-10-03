import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/database.dart';
import '../../data/models/invoice_line_item.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_format_helper.dart';

class InvoicePdfService {
  static Future<void> sharePdf({
    required Invoice invoice,
    required Customer customer,
    required BusinessProfile business,
    required InvoiceBranding branding,
    Project? project,
    String documentLabel = 'INVOICE',
  }) async {
    final bytes = await buildPdf(
      invoice: invoice,
      customer: customer,
      business: business,
      branding: branding,
      project: project,
      documentLabel: documentLabel,
    );
    final safeName = _safeFilename(invoice.invoiceNumber);
    try {
      await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
    } catch (_) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$safeName.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf', name: '$safeName.pdf')],
          subject: '$documentLabel ${invoice.invoiceNumber}',
        ),
      );
    }
  }

  static Future<void> previewPdf({
    required Invoice invoice,
    required Customer customer,
    required BusinessProfile business,
    required InvoiceBranding branding,
    Project? project,
    String documentLabel = 'INVOICE',
  }) async {
    final bytes = await buildPdf(
      invoice: invoice,
      customer: customer,
      business: business,
      branding: branding,
      project: project,
      documentLabel: documentLabel,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<Uint8List> buildPdf({
    required Invoice invoice,
    required Customer customer,
    required BusinessProfile business,
    required InvoiceBranding branding,
    Project? project,
    String documentLabel = 'INVOICE',
  }) async {
    final accent = _hexToPdfColor(branding.accentColor);
    final items = parseLineItems(invoice.lineItems);
    pw.ImageProvider? logoImage;
    if (branding.showLogo && business.logoPath != null && business.logoPath!.isNotEmpty) {
      final file = File(business.logoPath!);
      if (file.existsSync()) {
        logoImage = pw.MemoryImage(await file.readAsBytes());
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final ntn = prefs.getString('branding_ntn')?.trim() ?? '';
    final paymentInstructions = prefs.getString('branding_payment_instructions')?.trim() ?? '';

    final doc = pw.Document();
    final template = branding.templateStyle;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _header(business, logoImage, accent, template, documentLabel),
              pw.SizedBox(height: 24),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _billTo(customer)),
                  pw.SizedBox(width: 24),
                  pw.Expanded(child: _invoiceMeta(invoice, project, documentLabel)),
                ],
              ),
              pw.SizedBox(height: 24),
              _lineItemsTable(items, invoice, accent, template),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: _totals(invoice, accent),
              ),
              pw.Spacer(),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(documentLabel == 'QUOTE' ? 'Quote notes' : 'Payment & notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accent)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      documentLabel == 'QUOTE'
                          ? 'This quote is valid until the date shown. Reference ${invoice.invoiceNumber} when accepting.'
                          : 'Please pay by the due date. Reference invoice ${invoice.invoiceNumber} with your transfer.',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                    if (paymentInstructions.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(paymentInstructions, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                    if (ntn.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('NTN: $ntn', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                    if (business.businessAddress.isNotEmpty)
                      pw.Text(business.businessAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (business.businessCity.isNotEmpty || business.businessCountry.isNotEmpty)
                      pw.Text(
                        [business.businessCity, business.businessPostalCode, business.businessCountry]
                            .where((s) => s.isNotEmpty)
                            .join(', '),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Thank you for your business · Powered by CLIVORA',
                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static String _safeFilename(String name) {
    return name.replaceAll(RegExp(r'[^\w\-.]+'), '_').replaceAll(RegExp(r'_+'), '_');
  }

  static pw.Widget _header(
    BusinessProfile business,
    pw.ImageProvider? logo,
    PdfColor accent,
    String template,
    String documentLabel,
  ) {
    if (template == 'bold') {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: double.infinity, height: 10, color: accent),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Container(
                  width: 56,
                  height: 56,
                  margin: const pw.EdgeInsets.only(right: 14),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      business.businessName.isNotEmpty ? business.businessName : 'CLIVORA',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: accent),
                    ),
                    if (business.businessEmail.isNotEmpty)
                      pw.Text(business.businessEmail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (business.businessPhone.isNotEmpty)
                      pw.Text(business.businessPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.Text(
                documentLabel,
                style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: accent),
              ),
            ],
          ),
        ],
      );
    }

    final bg = _templateHeaderBg(template);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: template == 'minimal' ? pw.Border.all(color: PdfColors.grey300) : null,
      ),
      child: pw.Row(
        children: [
          if (logo != null)
            pw.Container(
              width: 48,
              height: 48,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  business.businessName.isNotEmpty ? business.businessName : 'CLIVORA',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent),
                ),
                if (business.businessEmail.isNotEmpty)
                  pw.Text(business.businessEmail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                if (business.businessPhone.isNotEmpty)
                  pw.Text(business.businessPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.Text(documentLabel, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: accent)),
        ],
      ),
    );
  }

  static pw.Widget _billTo(Customer customer) {
    final emails = parseStringList(customer.emails);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.Text(customer.contactPerson, style: const pw.TextStyle(fontSize: 11)),
        if (customer.company.isNotEmpty) pw.Text(customer.company, style: const pw.TextStyle(fontSize: 10)),
        if (emails.isNotEmpty) pw.Text(emails.first, style: const pw.TextStyle(fontSize: 10)),
        if (customer.address.isNotEmpty) pw.Text(customer.address, style: const pw.TextStyle(fontSize: 10)),
        if (customer.city.isNotEmpty)
          pw.Text('${customer.city}${customer.postalCode.isNotEmpty ? ', ${customer.postalCode}' : ''}', style: const pw.TextStyle(fontSize: 10)),
        if (customer.country.isNotEmpty) pw.Text(customer.country, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _invoiceMeta(Invoice invoice, Project? project, [String documentLabel = 'INVOICE']) {
    final numLabel = documentLabel == 'QUOTE' ? 'Quote #' : 'Invoice #';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _metaRow(numLabel, invoice.invoiceNumber),
        _metaRow('Issue Date', formatDisplayDate(invoice.issueDate)),
        if (invoice.dueDate != null) _metaRow('Due Date', formatDisplayDate(invoice.dueDate!)),
        _metaRow('Status', invoice.status.toUpperCase()),
        if (project != null) _metaRow('Project', project.name),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _lineItemsTable(
    List<InvoiceLineItem> items,
    Invoice invoice,
    PdfColor accent,
    String template,
  ) {
    final headerBg = _templateTableHeader(template, accent);
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _cell('Description', bold: true),
            _cell('Qty', bold: true, align: pw.TextAlign.center),
            _cell('Rate', bold: true, align: pw.TextAlign.right),
            _cell('Amount', bold: true, align: pw.TextAlign.right),
          ],
        ),
        ...items.map((item) {
          final lineTotal = item.quantity * item.unitPrice;
          return pw.TableRow(
            children: [
              _cell(item.description),
              _cell('${item.quantity}', align: pw.TextAlign.center),
              _cell(formatCurrency(item.unitPrice, symbol: currencySymbol(invoice.currency)), align: pw.TextAlign.right),
              _cell(formatCurrency(lineTotal, symbol: currencySymbol(invoice.currency)), align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _totals(Invoice invoice, PdfColor accent) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        children: [
          _totalRow('Subtotal', formatCurrency(invoice.subtotal, symbol: currencySymbol(invoice.currency))),
          if (invoice.taxRate > 0)
            _totalRow('Tax (${invoice.taxRate}%)', formatCurrency(invoice.subtotal * invoice.taxRate / 100, symbol: currencySymbol(invoice.currency))),
          if (invoice.discount > 0)
            _totalRow('Discount', '-${formatCurrency(invoice.discount, symbol: currencySymbol(invoice.currency))}'),
          pw.Divider(color: accent),
          _totalRow('Total', formatCurrency(invoice.total, symbol: currencySymbol(invoice.currency)), bold: true, color: accent),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  static PdfColor _hexToPdfColor(String hex) {
    final value = hex.replaceAll('#', '');
    final intVal = int.parse(value.length == 6 ? 'FF$value' : value, radix: 16);
    return PdfColor.fromInt(intVal);
  }

  static PdfColor _templateHeaderBg(String template) {
    switch (template) {
      case 'modern':
        return PdfColor.fromInt(0xFFEFF6FF);
      case 'minimal':
        return PdfColors.white;
      case 'bold':
        return PdfColors.white;
      default:
        return PdfColor.fromInt(0xFFF3F4F6);
    }
  }

  static PdfColor _templateTableHeader(String template, PdfColor accent) {
    switch (template) {
      case 'modern':
        return PdfColor(accent.red, accent.green, accent.blue, 0.15);
      case 'minimal':
        return PdfColors.grey100;
      case 'bold':
        return PdfColor(accent.red, accent.green, accent.blue, 0.22);
      default:
        return PdfColor.fromInt(0xFFE5E7EB);
    }
  }
}
