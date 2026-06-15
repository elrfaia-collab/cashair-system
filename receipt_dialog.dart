import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';

class ReceiptDialog extends StatelessWidget {
  final int invoiceId;
  final String invoiceNumber;
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> items;
  final String cashierName;

  const ReceiptDialog({
    super.key,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.invoice,
    required this.items,
    required this.cashierName,
  });

  Future<Uint8List> _buildPdf(Map<String, String> settings) async {
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    final shopName = settings['shop_name'] ?? 'المتجر';
    final shopPhone = settings['shop_phone'] ?? '';
    final shopAddress = settings['shop_address'] ?? '';
    final footer = settings['receipt_footer'] ?? 'شكراً لزيارتكم';
    final currency = settings['currency'] ?? 'ج.م';
    final isReturn = invoice['type'] == 'return';

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          if (shopAddress.isNotEmpty) pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 10)),
          if (shopPhone.isNotEmpty) pw.Text('هاتف: $shopPhone', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('فاتورة: $invoiceNumber', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
          ]),
          if (isReturn) pw.Text('*** مرتجع ***', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('الكاشير: $cashierName', style: const pw.TextStyle(fontSize: 10)),
          if ((invoice['customer_name'] ?? '').isNotEmpty)
            pw.Text('العميل: ${invoice['customer_name']}', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
          // Items
          ...items.map((item) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item['product_name'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('${item['quantity']} × ${fmt.format(item['unit_price'])} $currency',
                  style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${fmt.format(item['total'])} $currency', style: const pw.TextStyle(fontSize: 10)),
              ]),
              pw.SizedBox(height: 4),
            ],
          )),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('المجموع:', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('${fmt.format(invoice['subtotal'])} $currency', style: const pw.TextStyle(fontSize: 11)),
          ]),
          if ((invoice['discount'] as num) > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('خصم:', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('${fmt.format(invoice['discount'])} $currency', style: const pw.TextStyle(fontSize: 11)),
            ]),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('الإجمالي:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text('${fmt.format(invoice['total'])} $currency', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ]),
          if (!isReturn) ...[
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('المدفوع:', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('${fmt.format(invoice['paid_amount'])} $currency', style: const pw.TextStyle(fontSize: 11)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('الباقي:', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('${fmt.format(invoice['change_amount'])} $currency', style: const pw.TextStyle(fontSize: 11)),
            ]),
          ],
          pw.Divider(),
          pw.Text(footer, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 10),
        ],
      ),
    ));
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final isReturn = invoice['type'] == 'return';

    return AlertDialog(
      title: Row(children: [
        Icon(isReturn ? Icons.assignment_return : Icons.check_circle, color: isReturn ? AppTheme.warningColor : AppTheme.secondaryColor),
        const SizedBox(width: 8),
        Text(isReturn ? 'تم تسجيل المرتجع' : 'تمت عملية البيع بنجاح',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _row('رقم الفاتورة', invoiceNumber),
                  _row('التاريخ', DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())),
                  _row('الكاشير', cashierName),
                  if ((invoice['customer_name'] ?? '').isNotEmpty)
                    _row('العميل', invoice['customer_name']),
                  const Divider(),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${item['product_name']} × ${item['quantity']}',
                          style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        Text('${fmt.format(item['total'])} ج.م', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )),
                  const Divider(),
                  _row('الإجمالي', '${fmt.format(invoice['total'])} ج.م', bold: true),
                  if (!isReturn) ...[
                    _row('المدفوع', '${fmt.format(invoice['paid_amount'])} ج.م'),
                    _row('الباقي', '${fmt.format(invoice['change_amount'])} ج.م', color: AppTheme.secondaryColor),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          label: const Text('إغلاق'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final settings = await DatabaseHelper.instance.getSettings();
            final pdfBytes = await _buildPdf(settings);
            await Printing.layoutPdf(onLayout: (_) => pdfBytes);
          },
          icon: const Icon(Icons.print),
          label: const Text('طباعة الإيصال'),
        ),
      ],
    );
  }

  Widget _row(String label, dynamic value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value.toString(),
            style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
