import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/debt.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DEBTS',
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
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                  children: [
                    const TextSpan(text: 'Track what '),
                    TextSpan(
                      text: 'you owe.',
                      style: GoogleFonts.lora(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.dark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary row
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'I OWE',
                      amount: svc.totalIOwe,
                      color: AppTheme.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'OWES ME',
                      amount: svc.totalOwesMe,
                      color: AppTheme.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── Tabs ─────────────────────────────────────────────────────────────
        TabBar(
          controller: _tab,
          labelStyle: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: AppTheme.dark,
          unselectedLabelColor: AppTheme.midGray,
          indicatorColor: AppTheme.orange,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'I Owe (${svc.iOweDebts.length})'),
            Tab(text: 'Owes Me (${svc.owesMeDebts.length})'),
          ],
        ),

        // ── Lists ────────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _DebtList(
                debts: svc.iOweDebts,
                direction: DebtDirection.iOwe,
                emptyMessage: 'No debts you owe.',
              ),
              _DebtList(
                debts: svc.owesMeDebts,
                direction: DebtDirection.owesMe,
                emptyMessage: 'Nobody owes you anything.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppTheme.midGray)),
          const SizedBox(height: 6),
          Text(Money.compact(amount),
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }
}

// ── Debt list ─────────────────────────────────────────────────────────────────
class _DebtList extends StatelessWidget {
  final List<Debt> debts;
  final DebtDirection direction;
  final String emptyMessage;

  const _DebtList({
    required this.debts,
    required this.direction,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.orangeTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.handshake_outlined,
                  color: AppTheme.orange),
            ),
            const SizedBox(height: 14),
            Text(emptyMessage,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark)),
            const SizedBox(height: 4),
            Text('Tap + to add a new debt.',
                style: GoogleFonts.lora(
                    fontSize: 13, color: AppTheme.midGray)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: debts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _DebtCard(debt: debts[i]),
    );
  }
}

// ── Debt card ─────────────────────────────────────────────────────────────────
class _DebtCard extends StatelessWidget {
  final Debt debt;
  const _DebtCard({required this.debt});

  Future<void> _settle(BuildContext context) async {
    final svc = context.read<FinanceService>();
    final accounts = svc.accounts
        .where((a) => debt.direction == DebtDirection.iOwe
            ? a.type != AccountType.safe
            : a.type != AccountType.wallet)
        .toList();

    String? selectedId = accounts.isNotEmpty ? accounts.first.id : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Settle debt with ${debt.contact}?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                debt.direction == DebtDirection.iOwe
                    ? 'This will record an expense and mark the debt as paid.'
                    : 'This will record income and mark the debt as received.',
                style: GoogleFonts.lora(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              Text('Account:',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.midGray)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name}  (${Money.compact(a.balance)})',
                              style: GoogleFonts.poppins(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setStateDialog(() => selectedId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Settle')),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedId == null) return;

    try {
      await svc.settleDebt(debt.id, selectedId!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Debt settled with ${debt.contact}!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete this debt?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
            'The debt record will be removed without any transaction.',
            style: GoogleFonts.lora(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<FinanceService>().deleteDebt(debt.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwe = debt.direction == DebtDirection.iOwe;
    final accentColor = isOwe ? AppTheme.orange : AppTheme.green;
    final fmt = DateFormat('MMM d, yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      debt.contact.isNotEmpty
                          ? debt.contact[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: accentColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(debt.contact,
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.dark)),
                          ),
                          Text(Money.format(debt.amount),
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor)),
                        ],
                      ),
                      if (debt.description != null) ...[
                        const SizedBox(height: 3),
                        Text(debt.description!,
                            style: GoogleFonts.lora(
                                fontSize: 12,
                                color: AppTheme.midGray,
                                height: 1.4)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11, color: AppTheme.midGray),
                          const SizedBox(width: 4),
                          Text('Added ${fmt.format(debt.createdAt)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: AppTheme.midGray)),
                          if (debt.dueDate != null) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.access_time_rounded,
                                size: 11,
                                color: debt.isOverdue
                                    ? AppTheme.orange
                                    : AppTheme.midGray),
                            const SizedBox(width: 4),
                            Text(
                              'Due ${fmt.format(debt.dueDate!)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: debt.isOverdue
                                      ? AppTheme.orange
                                      : AppTheme.midGray,
                                  fontWeight: debt.isOverdue
                                      ? FontWeight.w600
                                      : FontWeight.w400),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action row
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.lightGray)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _settle(context),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: const Text('Settle'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.green,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: AppTheme.lightGray),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.midGray,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
