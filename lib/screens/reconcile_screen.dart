import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart' as txm;
import '../services/finance_service.dart';
import '../services/reconcile_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

/// Compares the in-app ledger against a bank statement CSV and shows what
/// matches, what differs, and what's missing on either side.
class ReconcileScreen extends StatefulWidget {
  const ReconcileScreen({super.key});

  @override
  State<ReconcileScreen> createState() => _ReconcileScreenState();
}

class _ReconcileScreenState extends State<ReconcileScreen> {
  bool _loading = false;
  String? _fileName;
  ReconcileReport? _report;

  Future<void> _pickAndReconcile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withReadStream: false,
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _loading = false);
        return;
      }
      final content = await File(result.files.single.path!).readAsString();
      final entries = ReconcileService.parseBankCsv(content);
      if (entries.isEmpty) {
        _snack('No usable rows found. Check the file has date + amount columns.');
        setState(() => _loading = false);
        return;
      }
      final svc = context.read<FinanceService>();
      final report = ReconcileService.reconcile(
        transactions: svc.transactions.toList(),
        bankEntries: entries,
      );
      setState(() {
        _fileName = result.files.single.name;
        _report = report;
      });
    } catch (e) {
      _snack('Could not read file: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      backgroundColor: AppTheme.dark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(
        title: Text('Reconcile with bank',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _introCard(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _pickAndReconcile,
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.light))
                    : const Icon(Icons.upload_file_rounded),
                label: Text(r == null ? 'Import bank CSV' : 'Import another file'),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text('Loaded: $_fileName',
                  style:
                      GoogleFonts.lora(fontSize: 12, color: AppTheme.midGray)),
            ],
            if (r != null) ...[
              const SizedBox(height: 24),
              _summary(r),
              const SizedBox(height: 20),
              if (r.mismatched.isNotEmpty)
                _MatchSection(
                  title: 'Amount differs',
                  color: AppTheme.orange,
                  icon: Icons.error_outline_rounded,
                  children: [
                    for (final m in r.mismatched) _mismatchTile(m),
                  ],
                ),
              if (r.bankOnly.isNotEmpty)
                _MatchSection(
                  title: 'On statement, missing from app',
                  color: AppTheme.blue,
                  icon: Icons.south_west_rounded,
                  children: [for (final b in r.bankOnly) _bankTile(b)],
                ),
              if (r.appOnly.isNotEmpty)
                _MatchSection(
                  title: 'In app, not on statement',
                  color: AppTheme.midGray,
                  icon: Icons.north_east_rounded,
                  children: [for (final t in r.appOnly) _appTile(t)],
                ),
              _MatchSection(
                title: 'Matched',
                color: AppTheme.green,
                icon: Icons.check_circle_outline_rounded,
                initiallyExpanded: false,
                children: [for (final m in r.matched) _matchedTile(m)],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, color: AppTheme.orange),
              const SizedBox(width: 8),
              Text('How it works',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Export a statement (CSV) from your bank app and import it here. '
            'Finlytic matches each line to your recorded transactions by amount '
            'and date, then shows what agrees, what differs, and what is missing '
            'on either side. Nothing is changed — this is a read-only check.',
            style: GoogleFonts.lora(
                fontSize: 13, color: AppTheme.dark, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _summary(ReconcileReport r) {
    return Column(
      children: [
        Row(
          children: [
            _stat('Matched', '${r.matched.length}', AppTheme.green),
            const SizedBox(width: 10),
            _stat('Differs', '${r.mismatched.length}', AppTheme.orange),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _stat('Bank only', '${r.bankOnly.length}', AppTheme.blue),
            const SizedBox(width: 10),
            _stat('App only', '${r.appOnly.length}', AppTheme.midGray),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: r.isClean ? AppTheme.greenTint : AppTheme.orangeTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                  r.isClean
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  color: r.isClean ? AppTheme.green : AppTheme.orange,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.isClean
                      ? 'Everything reconciles. App and statement agree.'
                      : 'Statement total ${Money.format(r.bankTotal)} vs app ${Money.format(r.appTotal)}.',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: r.isClean ? AppTheme.green : AppTheme.orange),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppTheme.midGray)),
          ],
        ),
      ),
    );
  }

  static final _df = DateFormat('MMM d');

  Widget _matchedTile(ReconcileMatch m) => _line(
        left: m.bank.description.isEmpty ? 'Bank line' : m.bank.description,
        sub: m.bank.date == null ? '' : _df.format(m.bank.date!),
        right: Money.format(m.app.amount),
        rightColor: AppTheme.green,
      );

  Widget _mismatchTile(ReconcileMatch m) => _line(
        left: m.bank.description.isEmpty ? 'Bank line' : m.bank.description,
        sub: 'app ${Money.format(m.app.amount)} · bank ${Money.format(m.bank.amount)}',
        right: 'Δ ${Money.format(m.delta)}',
        rightColor: AppTheme.orange,
      );

  Widget _bankTile(BankEntry b) => _line(
        left: b.description.isEmpty ? 'Bank line' : b.description,
        sub: b.date == null ? 'no date' : _df.format(b.date!),
        right: Money.format(b.amount),
        rightColor: AppTheme.blue,
      );

  Widget _appTile(txm.Transaction t) => _line(
        left: t.category ?? t.contact ?? t.type.label,
        sub: _df.format(t.date),
        right: Money.format(t.amount),
        rightColor: AppTheme.midGray,
      );

  Widget _line({
    required String left,
    required String sub,
    required String right,
    required Color rightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: GoogleFonts.lora(
                          fontSize: 11, color: AppTheme.midGray)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(right,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: rightColor)),
        ],
      ),
    );
  }
}

class _MatchSection extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _MatchSection({
    required this.title,
    required this.color,
    required this.icon,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          leading: Icon(icon, color: color),
          title: Text('$title  ·  ${children.length}',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          children: children,
        ),
      ),
    );
  }
}
