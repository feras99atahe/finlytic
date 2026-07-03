import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/finance_service.dart';
import '../theme/app_theme.dart';

/// Prompts for a new expense category name. Returns the trimmed name, or null
/// if cancelled or left blank. Persisting is the caller's responsibility.
Future<String?> showAddCategoryDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('New category',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Category name'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Add'),
        ),
      ],
    ),
  ).then((v) {
    ctrl.dispose();
    return (v == null || v.isEmpty) ? null : v;
  });
}

/// Outlined "+ Add" chip for category pickers. Prompts for a name, persists it
/// via [FinanceService.addCategory], then reports it through [onAdded] so the
/// caller can select it.
class AddCategoryChip extends StatelessWidget {
  final ValueChanged<String> onAdded;
  const AddCategoryChip({super.key, required this.onAdded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final name = await showAddCategoryDialog(context);
        if (name == null || !context.mounted) return;
        await context.read<FinanceService>().addCategory(name);
        onAdded(name);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 14, color: AppTheme.orange),
            const SizedBox(width: 4),
            Text('Add',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.orange,
                )),
          ],
        ),
      ),
    );
  }
}

/// Two-axis expense classification (change spec §1–3): Recurring/Variable and
/// Essential/Secondary, plus an optional record-only recurrence cadence tucked
/// behind "Advanced options". Values are parent-controlled.
class ExpenseAxisFields extends StatefulWidget {
  final bool isRecurring;
  final bool isEssential;
  final int recurrenceMonths;
  final ValueChanged<bool> onRecurringChanged;
  final ValueChanged<bool> onEssentialChanged;
  final ValueChanged<int> onRecurrenceMonthsChanged;

  const ExpenseAxisFields({
    super.key,
    required this.isRecurring,
    required this.isEssential,
    required this.recurrenceMonths,
    required this.onRecurringChanged,
    required this.onEssentialChanged,
    required this.onRecurrenceMonthsChanged,
  });

  @override
  State<ExpenseAxisFields> createState() => _ExpenseAxisFieldsState();
}

class _ExpenseAxisFieldsState extends State<ExpenseAxisFields> {
  bool _advanced = false;

  TextStyle get _title =>
      GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500);
  TextStyle get _sub =>
      GoogleFonts.lora(fontSize: 12, color: AppTheme.midGray);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: widget.isRecurring,
            activeThumbColor: AppTheme.orange,
            onChanged: widget.onRecurringChanged,
            title: Text('Recurring (fixed monthly)', style: _title),
            subtitle: Text(
              'Repeats at the same value each month. Only these count toward savings capacity.',
              style: _sub,
            ),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            value: widget.isEssential,
            activeThumbColor: AppTheme.orange,
            onChanged: widget.onEssentialChanged,
            title: Text('Essential', style: _title),
            subtitle: Text('Necessary for living. Analysis only — never affects a calculation.',
                style: _sub),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            onTap: () => setState(() => _advanced = !_advanced),
            title: Text('Advanced options',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: Icon(
                _advanced ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppTheme.midGray),
          ),
          if (_advanced)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Repeats every (months)',
                        style: GoogleFonts.lora(
                            fontSize: 13, color: AppTheme.dark)),
                  ),
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onTap: widget.recurrenceMonths > 0
                        ? () => widget.onRecurrenceMonthsChanged(
                            widget.recurrenceMonths - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      widget.recurrenceMonths == 0
                          ? '—'
                          : '${widget.recurrenceMonths}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onTap: widget.recurrenceMonths < 24
                        ? () => widget.onRecurrenceMonthsChanged(
                            widget.recurrenceMonths + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.orangeTint : AppTheme.lightGray,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? AppTheme.orange : AppTheme.midGray),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? sub;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppTheme.midGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.dark,
              letterSpacing: -0.3,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: GoogleFonts.lora(
                    fontSize: 11, color: AppTheme.midGray)),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? eyebrow;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.eyebrow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: AppTheme.orange,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}
