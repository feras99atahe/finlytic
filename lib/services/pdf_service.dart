import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/account.dart';
import '../models/transaction.dart' as txm;
import '../utils/money.dart';

/// Builds and shares a PDF of the ledger for a given date range.
class PdfService {
  static final _dateFmt = DateFormat('MMM d, y');
  static final _rowDateFmt = DateFormat('yyyy-MM-dd');

  /// Renders the [transactions] (already filtered to [from]..[to]) into a PDF
  /// and opens the share sheet.
  static Future<void> exportLedger({
    required List<txm.Transaction> transactions,
    required List<Account> accounts,
    required DateTime from,
    required DateTime to,
  }) async {
    final accById = {for (final a in accounts) a.id: a};
    final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));

    double income = 0, expense = 0;
    for (final t in sorted) {
      switch (t.type) {
        case txm.TxType.income:
        case txm.TxType.openingBalance:
          income += t.amount;
          break;
        case txm.TxType.expense:
        case txm.TxType.debt:
          expense += t.amount;
          break;
        case txm.TxType.transfer:
          break;
      }
    }
    final net = income - expense;

    String accName(txm.Transaction t) =>
        accById[t.fromAccountId ?? t.toAccountId]?.name ?? '—';

    final doc = pw.Document();
    final headerStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('Finlytic ledger',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600)),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}  ·  generated ${_dateFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (ctx) => [
          // Title
          pw.Text('Finlytic — Ledger',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('${_dateFmt.format(from)}  —  ${_dateFmt.format(to)}',
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),

          // Summary band
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryCell('Income', Money.format(income), PdfColors.green800),
              _summaryCell('Expense', Money.format(expense), PdfColors.red800),
              _summaryCell('Net', Money.format(net),
                  net >= 0 ? PdfColors.green800 : PdfColors.red800),
              _summaryCell('Entries', '${sorted.length}', PdfColors.grey800),
            ],
          ),
          pw.SizedBox(height: 16),

          if (sorted.isEmpty)
            pw.Text('No transactions in this range.',
                style: const pw.TextStyle(color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey800),
              headerStyle: headerStyle,
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {3: pw.Alignment.centerRight},
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300)),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.6),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.8),
              },
              headers: ['Date', 'Type', 'Category', 'Amount', 'Account'],
              data: [
                for (final t in sorted)
                  [
                    _rowDateFmt.format(t.date),
                    t.type.label,
                    t.category ?? (t.contact ?? '—'),
                    Money.format(t.amount),
                    accName(t),
                  ],
              ],
            ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/finlytic_ledger_$stamp.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Finlytic ledger ${_dateFmt.format(from)} – ${_dateFmt.format(to)}',
    );
  }

  static pw.Widget _summaryCell(String label, String value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }
}
