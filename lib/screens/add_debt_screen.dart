import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _contactCtrl     = TextEditingController();
  final _amountCtrl      = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  DebtDirection _direction = DebtDirection.iOwe;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _contactCtrl.dispose();
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await context.read<FinanceService>().addDebt(
            direction: _direction,
            amount: double.parse(_amountCtrl.text.trim()),
            contact: _contactCtrl.text.trim(),
            description: _descriptionCtrl.text.trim().isEmpty
                ? null
                : _descriptionCtrl.text.trim(),
            dueDate: _dueDate,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(
        title: Text('Add Debt',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Direction toggle ─────────────────────────────────────────
              _sectionLabel('DIRECTION'),
              const SizedBox(height: 10),
              Row(
                children: DebtDirection.values.map((dir) {
                  final selected = _direction == dir;
                  final color = dir == DebtDirection.iOwe
                      ? AppTheme.orange
                      : AppTheme.green;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _direction = dir),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(
                            right: dir == DebtDirection.iOwe ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? color : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: selected ? color : AppTheme.lightGray,
                              width: selected ? 1.5 : 1),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              dir == DebtDirection.iOwe
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: selected ? AppTheme.light : color,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dir == DebtDirection.iOwe
                                  ? 'I Owe'
                                  : 'Owes Me',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? AppTheme.light : color,
                              ),
                            ),
                            Text(
                              dir == DebtDirection.iOwe
                                  ? 'I borrowed money'
                                  : 'They borrowed money',
                              style: GoogleFonts.lora(
                                fontSize: 10,
                                color: selected
                                    ? AppTheme.light.withAlpha(200)
                                    : AppTheme.midGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Contact ──────────────────────────────────────────────────
              _sectionLabel('PERSON'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
              ),
              const SizedBox(height: 16),

              // ── Amount ───────────────────────────────────────────────────
              _sectionLabel('AMOUNT'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount.';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a valid amount.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Description ──────────────────────────────────────────────
              _sectionLabel('DESCRIPTION (OPTIONAL)'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What is this for?',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // ── Due date ─────────────────────────────────────────────────
              _sectionLabel('DUE DATE (OPTIONAL)'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.lightGray),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded,
                          color: AppTheme.midGray, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _dueDate != null
                            ? fmt.format(_dueDate!)
                            : 'Pick a due date',
                        style: GoogleFonts.lora(
                          fontSize: 14,
                          color: _dueDate != null
                              ? AppTheme.dark
                              : AppTheme.midGray,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: const Icon(Icons.close_rounded,
                              color: AppTheme.midGray, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Save ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.light))
                      : const Text('Add Debt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppTheme.midGray,
        ),
      );
}
