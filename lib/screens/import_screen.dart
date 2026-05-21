import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../services/csv_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<CsvRow>? _rows;
  bool _picking = false;
  bool _importing = false;
  bool _sharingTemplate = false;
  String? _fileName;

  List<CsvRow> get _validRows =>
      _rows?.where((r) => r.isValid).toList() ?? [];
  List<CsvRow> get _errorRows =>
      _rows?.where((r) => !r.isValid).toList() ?? [];

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: false,
        withReadStream: false,
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final content = await File(path).readAsString();
      final rows = CsvService.parse(content);

      setState(() {
        _rows = rows;
        _fileName = result.files.single.name;
      });
    } catch (e) {
      _snack('Could not read file: $e', error: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() => _sharingTemplate = true);
    try {
      await CsvService.shareTemplate();
    } catch (e) {
      if (mounted) _snack('Could not share template: $e', error: true);
    } finally {
      if (mounted) setState(() => _sharingTemplate = false);
    }
  }

  Future<void> _import() async {
    final valid = _validRows;
    if (valid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Import ${valid.length} transactions?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          _errorRows.isEmpty
              ? 'All rows are valid and will be imported.'
              : '${valid.length} valid rows will be imported. ${_errorRows.length} invalid rows will be skipped.',
          style: GoogleFonts.lora(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importing = true);
    final svc = context.read<FinanceService>();
    int success = 0;
    final errors = <String>[];

    for (final row in valid) {
      try {
        switch (row.rawType) {
          case 'income':
            final acc = svc.firstOfType(row.account) ??
                svc.accounts.first;
            await svc.addIncome(
              toAccountId: acc.id,
              amount: row.amount,
              note: row.note,
              date: row.date,
            );
            break;

          case 'expense':
            final acc = svc.firstOfType(row.account) ??
                svc.accounts.first;
            await svc.addExpense(
              fromAccountId: acc.id,
              amount: row.amount,
              category: row.category ?? 'Other',
              note: row.note,
              date: row.date,
            );
            break;

          case 'debt':
            final acc = svc.firstOfType(row.account) ??
                svc.accounts.first;
            await svc.addDebtTransaction(
              fromAccountId: acc.id,
              amount: row.amount,
              contact: row.contact ?? '',
              note: row.note,
              date: row.date,
            );
            break;

          case 'transfer':
            await svc.transferSafeToWallet(
              amount: row.amount,
              note: row.note,
              date: row.date,
            );
            break;

          case 'debt_record':
            await svc.addDebt(
              direction: row.debtDirection ?? DebtDirection.iOwe,
              amount: row.amount,
              contact: row.contact ?? '',
              description: row.note,
              dueDate: row.dueDate,
            );
            break;
        }
        success++;
      } catch (e) {
        errors.add('Row ${row.rowNumber}: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _importing = false;
      _rows = null;
      _fileName = null;
    });

    if (errors.isEmpty) {
      _snack('Imported $success transactions successfully!');
    } else {
      _snack('Imported $success transactions. ${errors.length} failed.', error: true);
    }
  }

  Future<void> _editRow(int index) async {
    final updated = await showModalBottomSheet<CsvRow>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditRowSheet(row: _rows![index]),
    );
    if (updated != null && mounted) {
      setState(() => _rows![index] = updated);
    }
  }

  void _deleteRow(int index) {
    setState(() => _rows!.removeAt(index));
    if (_rows!.isEmpty) setState(() { _rows = null; _fileName = null; });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      backgroundColor: error ? AppTheme.orange : AppTheme.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(
        title: Text('Import CSV',
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
            // ── Step 1: Template ───────────────────────────────────────────
            _StepCard(
              step: '1',
              title: 'Get the template',
              subtitle: 'Download and fill in the CSV template with your data.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ColumnGuide(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _sharingTemplate ? null : _downloadTemplate,
                      icon: _sharingTemplate
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.dark))
                          : const Icon(Icons.download_rounded),
                      label: const Text('Download Template'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Step 2: Pick file ──────────────────────────────────────────
            _StepCard(
              step: '2',
              title: 'Select your CSV file',
              subtitle: 'Supports .csv and .txt files.',
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _picking ? null : _pickFile,
                  icon: _picking
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.light))
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(_fileName != null
                      ? _fileName!
                      : 'Choose File'),
                ),
              ),
            ),

            // ── Step 3: Preview & Import ───────────────────────────────────
            if (_rows != null) ...[
              const SizedBox(height: 16),
              _StepCard(
                step: '3',
                title: 'Preview & import',
                subtitle:
                    '${_validRows.length} valid · ${_errorRows.length} invalid',
                child: Column(
                  children: [
                    // Summary chips
                    Row(
                      children: [
                        _StatusChip(
                          label: '${_validRows.length} ready',
                          color: AppTheme.green,
                        ),
                        if (_errorRows.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: '${_errorRows.length} skipped',
                            color: AppTheme.orange,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Row list
                    ...(_rows!.asMap().entries.map((e) => _RowTile(
                          row: e.value,
                          onEdit: () => _editRow(e.key),
                          onDelete: () => _deleteRow(e.key),
                        ))),

                    const SizedBox(height: 16),

                    // Import button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_importing || _validRows.isEmpty)
                            ? null
                            : _import,
                        icon: _importing
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.light))
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(_importing
                            ? 'Importing…'
                            : 'Import ${_validRows.length} Transactions'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Column guide widget ───────────────────────────────────────────────────────
class _ColumnGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('type', 'income · expense · debt · transfer · debt_record'),
      ('amount', 'positive number  e.g. 120.50'),
      ('date', 'YYYY-MM-DD  e.g. 2026-01-15'),
      ('account', 'Bank · Safe · Wallet  (empty for debt_record)'),
      ('category', 'Food · Transport · Shopping … (expense/debt)'),
      ('note', 'optional description'),
      ('contact', 'person name (debt & debt_record)'),
      ('direction', 'iOwe · owesMe  (debt_record only)'),
      ('due_date', 'YYYY-MM-DD  optional (debt_record only)'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lightGray.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CSV columns',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.midGray)),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(r.$1,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.dark)),
                    ),
                    Expanded(
                      child: Text(r.$2,
                          style: GoogleFonts.lora(
                              fontSize: 11, color: AppTheme.midGray)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Row preview tile ──────────────────────────────────────────────────────────
class _RowTile extends StatelessWidget {
  final CsvRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RowTile({required this.row, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = row.isValid ? AppTheme.green : AppTheme.orange;
    final fmt = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              row.isValid ? Icons.check_rounded : Icons.error_outline_rounded,
              size: 16, color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: row.isValid
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TypeBadge(row.rawType),
                          const SizedBox(width: 6),
                          Text(
                            '\$${row.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.dark),
                          ),
                          const Spacer(),
                          Text(
                            fmt.format(row.date),
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppTheme.midGray),
                          ),
                        ],
                      ),
                      if (row.category != null || row.note != null)
                        Text(
                          [row.category, row.note].whereType<String>().join(' · '),
                          style: GoogleFonts.lora(
                              fontSize: 11, color: AppTheme.midGray),
                        ),
                    ],
                  )
                : Text(
                    'Row ${row.rowNumber}: ${row.error}',
                    style: GoogleFonts.lora(
                        fontSize: 12, color: AppTheme.orange, height: 1.4),
                  ),
          ),
          // Action buttons
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppTheme.midGray,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onEdit,
            tooltip: 'Edit row',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppTheme.orange,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onDelete,
            tooltip: 'Delete row',
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  Color get _color {
    switch (type) {
      case 'income':
        return AppTheme.green;
      case 'expense':
        return AppTheme.orange;
      case 'debt':
        return const Color(0xFFA84B33);
      case 'transfer':
        return AppTheme.blue;
      default:
        return AppTheme.midGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _color,
            letterSpacing: 0.3),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

// ── Edit row bottom sheet ─────────────────────────────────────────────────────
class _EditRowSheet extends StatefulWidget {
  final CsvRow row;
  const _EditRowSheet({required this.row});

  @override
  State<_EditRowSheet> createState() => _EditRowSheetState();
}

class _EditRowSheetState extends State<_EditRowSheet> {
  late String _type;
  late TextEditingController _amountCtrl;
  late DateTime _date;
  late String _account;
  late String _category;
  late TextEditingController _noteCtrl;
  late TextEditingController _contactCtrl;
  late String _direction;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _type     = r.rawType.isEmpty ? 'income' : r.rawType;
    _amountCtrl  = TextEditingController(text: r.amount > 0 ? r.amount.toStringAsFixed(2) : '');
    _date     = r.rawType == 'debt_record' ? DateTime.now() : r.date;
    _account  = r.isDebtRecord ? 'bank' : r.account.name;
    _category = r.category ?? '';
    _noteCtrl    = TextEditingController(text: r.note ?? '');
    _contactCtrl = TextEditingController(text: r.contact ?? '');
    _direction = r.debtDirection == DebtDirection.owesMe ? 'owesMe' : 'iOwe';
    _dueDate  = r.dueDate;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  bool get _showAccount   => _type != 'debt_record';
  bool get _showCategory  => _type == 'expense' || _type == 'debt';
  bool get _showContact   => _type == 'debt' || _type == 'debt_record';
  bool get _showDirection => _type == 'debt_record';

  Future<void> _pickDate({bool isDueDate = false}) async {
    final initial = isDueDate ? (_dueDate ?? DateTime.now()) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isDueDate) { _dueDate = picked; } else { _date = picked; }
    });
  }

  void _save() {
    final fmt = DateFormat('yyyy-MM-dd');
    final result = CsvService.validateRow(
      rowNumber: widget.row.rowNumber,
      type: _type,
      amountStr: _amountCtrl.text,
      dateStr: _showAccount ? fmt.format(_date) : '',
      account: _account,
      category: _category,
      note: _noteCtrl.text,
      contact: _contactCtrl.text,
      direction: _direction,
      dueDateStr: _dueDate != null ? fmt.format(_dueDate!) : '',
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Edit Row ${widget.row.rowNumber}',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: AppTheme.dark)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),

            _FieldLabel('Type'),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _dec(),
              items: ['income', 'expense', 'debt', 'transfer', 'debt_record']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.poppins(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() { _type = v!; _category = ''; }),
            ),
            const SizedBox(height: 12),

            _FieldLabel('Amount'),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: _dec(hint: 'e.g. 120.50'),
            ),
            const SizedBox(height: 12),

            if (_showAccount) ...[
              _FieldLabel('Date'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: _dec(),
                  child: Row(
                    children: [
                      Expanded(child: Text(fmt.format(_date),
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.dark))),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.midGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _FieldLabel('Account'),
              DropdownButtonFormField<String>(
                value: _account,
                decoration: _dec(),
                items: ['bank', 'safe', 'wallet']
                    .map((a) => DropdownMenuItem(
                        value: a,
                        child: Text('${a[0].toUpperCase()}${a.substring(1)}',
                            style: GoogleFonts.poppins(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _account = v!),
              ),
              const SizedBox(height: 12),
            ],

            if (_showCategory) ...[
              _FieldLabel('Category'),
              DropdownButtonFormField<String>(
                value: _category.isEmpty ? null : _category,
                decoration: _dec(hint: 'Select category'),
                items: CsvService.categories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: GoogleFonts.poppins(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? ''),
              ),
              const SizedBox(height: 12),
            ],

            _FieldLabel('Note (optional)'),
            TextFormField(
              controller: _noteCtrl,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: _dec(hint: 'Optional description'),
            ),
            const SizedBox(height: 12),

            if (_showContact) ...[
              _FieldLabel('Contact'),
              TextFormField(
                controller: _contactCtrl,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: _dec(hint: 'Person name'),
              ),
              const SizedBox(height: 12),
            ],

            if (_showDirection) ...[
              _FieldLabel('Direction'),
              DropdownButtonFormField<String>(
                value: _direction,
                decoration: _dec(),
                items: ['iOwe', 'owesMe']
                    .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d, style: GoogleFonts.poppins(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _direction = v!),
              ),
              const SizedBox(height: 12),

              _FieldLabel('Due Date (optional)'),
              InkWell(
                onTap: () => _pickDate(isDueDate: true),
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: _dec(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dueDate != null ? fmt.format(_dueDate!) : 'Not set',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _dueDate != null ? AppTheme.dark : AppTheme.midGray),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.midGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.midGray),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.orange, width: 1.5),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppTheme.midGray, letterSpacing: 0.3)),
      );
}

// ── Step card ─────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                  color: AppTheme.orange,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(step,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.light)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.dark)),
                    Text(subtitle,
                        style: GoogleFonts.lora(
                            fontSize: 12, color: AppTheme.midGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
