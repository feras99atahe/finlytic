import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart' as txm;
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/transaction_tile.dart';
import 'edit_transaction_screen.dart';

enum _PaymentFilter { all, cash, card }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  _PaymentFilter _payment = _PaymentFilter.all;
  String? _category;
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final categories = svc.categories;
    final list = svc.filtered(
      from: _range?.start,
      to: _range?.end,
      category: _category,
      cashOnly: _payment == _PaymentFilter.cash,
      cardOnly: _payment == _PaymentFilter.card,
    );

    final total = list.fold(0.0, (s, t) {
      if (t.type == txm.TxType.expense || t.type == txm.TxType.debt) {
        return s + t.amount;
      }
      return s;
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LEDGER',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: AppTheme.orange,
                    )),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.dark,
                      letterSpacing: -1,
                    ),
                    children: [
                      const TextSpan(text: 'Every '),
                      TextSpan(
                          text: 'penny',
                          style: GoogleFonts.lora(
                            fontSize: 32,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.dark,
                          )),
                      const TextSpan(text: ', accounted for.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.lightGray),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FILTERED SPEND',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: AppTheme.midGray,
                                )),
                            const SizedBox(height: 4),
                            Text(Money.format(total),
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.dark,
                                  letterSpacing: -0.5,
                                )),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGray,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${list.length} entries',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.dark,
                            )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filters
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterRowLabel('Payment'),
                Wrap(spacing: 8, children: [
                  _Pill(
                    label: 'All',
                    selected: _payment == _PaymentFilter.all,
                    onTap: () =>
                        setState(() => _payment = _PaymentFilter.all),
                  ),
                  _Pill(
                    label: 'Cash',
                    icon: Icons.account_balance_wallet_outlined,
                    selected: _payment == _PaymentFilter.cash,
                    onTap: () =>
                        setState(() => _payment = _PaymentFilter.cash),
                  ),
                  _Pill(
                    label: 'Card',
                    icon: Icons.credit_card_rounded,
                    selected: _payment == _PaymentFilter.card,
                    onTap: () =>
                        setState(() => _payment = _PaymentFilter.card),
                  ),
                ]),
                const SizedBox(height: 16),
                _filterRowLabel('Category'),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Pill(
                        label: 'All',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      const SizedBox(width: 8),
                      ...categories.expand((c) => [
                            _Pill(
                              label: c,
                              selected: _category == c,
                              dot: AppTheme.colorForCategory(c),
                              onTap: () => setState(() => _category = c),
                            ),
                            const SizedBox(width: 8),
                          ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _filterRowLabel('Date range'),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickRange,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.lightGray),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_outlined,
                                  size: 16, color: AppTheme.midGray),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _range == null
                                      ? 'Any time'
                                      : '${DateFormat('MMM d').format(_range!.start)} – ${DateFormat('MMM d, y').format(_range!.end)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.dark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_range != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() => _range = null),
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.midGray),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48, color: AppTheme.midGray.withOpacity(.5)),
                    const SizedBox(height: 12),
                    Text('No matching transactions',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.midGray,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final t = list[i];
                  final svc = context.read<FinanceService>();
                  return TransactionTile(
                    tx: t,
                    fromAccountName: svc.accountById(t.fromAccountId)?.name,
                    toAccountName: svc.accountById(t.toAccountId)?.name,
                    onDelete: () => _confirmDelete(t.id),
                    onTap: () => _openEdit(t),
                  );
                },
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _filterRowLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppTheme.midGray,
            )),
      );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _openEdit(txm.Transaction t) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditTransactionScreen(transaction: t),
    ));
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          'Account balances will be reversed.',
          style: GoogleFonts.lora(color: AppTheme.dark),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await context.read<FinanceService>().deleteTransaction(id);
    }
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? dot;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    this.icon,
    this.dot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.dark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppTheme.dark : AppTheme.lightGray),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? AppTheme.light : AppTheme.dark),
              const SizedBox(width: 6),
            ],
            if (dot != null) ...[
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.light : AppTheme.dark,
                )),
          ],
        ),
      ),
    );
  }
}
