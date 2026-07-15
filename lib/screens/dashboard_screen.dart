import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/transaction.dart' as txm;
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import 'reconcile_screen.dart';

/// A consolidated financial dashboard: headline KPIs, this-month flow,
/// recurring vs variable split, category breakdown, accounts, and a shortcut
/// to bank reconciliation.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);

    final income = svc.incomeForMonth(month);
    final expense = svc.expensesForMonth(month);
    final saved = svc.savingsForMonth(month);

    double recurring = 0, variable = 0;
    for (final t in svc.transactions) {
      if (t.type != txm.TxType.expense) continue;
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.isRecurring) {
        recurring += t.amount;
      } else {
        variable += t.amount;
      }
    }
    final recTotal = recurring + variable;

    final cats = svc.categoryBreakdown(month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catMax = cats.isEmpty ? 0.0 : cats.first.value;

    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(
        title: Text('Dashboard',
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
            Text(DateFormat('MMMM y').format(now).toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: AppTheme.orange)),
            const SizedBox(height: 12),

            // KPI row
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'NET WORTH',
                    value: Money.compact(svc.totalBalance),
                    color: AppTheme.dark,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'SAVINGS / MO',
                    value: Money.compact(svc.effectiveMonthlySavings()),
                    color: AppTheme.green,
                    icon: Icons.savings_outlined,
                    sub: 'recurring-based',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MetricCard(
              label: 'FIXED SHARE OF SPEND',
              value: recTotal > 0
                  ? '${(recurring / recTotal * 100).round()}%'
                  : '—',
              color: AppTheme.blue,
              icon: Icons.repeat_rounded,
              sub: recTotal > 0
                  ? '${Money.compact(recurring)} fixed of ${Money.compact(recTotal)}'
                  : 'no expenses yet this month',
            ),
            const SizedBox(height: 24),

            // This month flow
            _sectionLabel('THIS MONTH'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  _flowStat('Income', income, AppTheme.green),
                  _divider(),
                  _flowStat('Spent', expense, AppTheme.orange),
                  _divider(),
                  _flowStat('Saved', saved,
                      saved >= 0 ? AppTheme.green : AppTheme.orange),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recurring vs variable
            _sectionLabel('RECURRING VS VARIABLE'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: recTotal <= 0
                  ? Text('No expenses recorded this month.',
                      style: GoogleFonts.lora(
                          fontSize: 13, color: AppTheme.midGray))
                  : Column(
                      children: [
                        _splitBar(recurring, variable),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _legend('Recurring', recurring, AppTheme.blue),
                            const SizedBox(width: 20),
                            _legend('Variable', variable, AppTheme.orange),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Category breakdown
            _sectionLabel('WHERE IT GOES'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: cats.isEmpty
                  ? Text('No spending yet this month.',
                      style: GoogleFonts.lora(
                          fontSize: 13, color: AppTheme.midGray))
                  : Column(
                      children: [
                        for (final e in cats.take(6))
                          _categoryRow(e.key, e.value, catMax),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Accounts
            _sectionLabel('ACCOUNTS'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  for (final a in svc.accounts) _accountRow(a),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reconcile shortcut
            _sectionLabel('BANK RECONCILIATION'),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ReconcileScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded,
                        color: AppTheme.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Compare with your bank',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text('Import a statement CSV and match it to your ledger.',
                              style: GoogleFonts.lora(
                                  fontSize: 12, color: AppTheme.midGray)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.midGray),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGray),
      );

  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppTheme.midGray));

  Widget _flowStat(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(Money.compact(value),
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: AppTheme.midGray)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 32, color: AppTheme.lightGray);

  Widget _splitBar(double recurring, double variable) {
    final total = recurring + variable;
    final recFlex = (recurring / total * 1000).round().clamp(1, 1000);
    final varFlex = (variable / total * 1000).round().clamp(1, 1000);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            flex: recFlex,
            child: Container(height: 16, color: AppTheme.blue),
          ),
          Expanded(
            flex: varFlex,
            child: Container(height: 16, color: AppTheme.orange),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text('$label ${Money.compact(value)}',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _categoryRow(String category, double value, double max) {
    final color = AppTheme.colorForCategory(category);
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(category,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text(Money.format(value),
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              backgroundColor: AppTheme.lightGray,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(Account a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            a.type == AccountType.bank
                ? Icons.credit_card_rounded
                : a.type == AccountType.safe
                    ? Icons.lock_outline_rounded
                    : Icons.account_balance_wallet_outlined,
            size: 18,
            color: AppTheme.midGray,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(a.name,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(Money.format(a.balance),
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
