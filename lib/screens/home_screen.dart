import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/account_card.dart';
import '../widgets/common.dart';
import '../widgets/transaction_tile.dart';
import 'edit_transaction_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAllTransactions;
  const HomeScreen({super.key, required this.onSeeAllTransactions});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final now = DateTime.now();
    final income  = svc.incomeForMonth(now);
    final expense = svc.expensesForMonth(now);
    final savings = svc.savingsForMonth(now);
    final delta   = svc.spendingDeltaPct(now);

    final recent = svc.transactions.take(5).toList();

    return RefreshIndicator(
      color: AppTheme.orange,
      onRefresh: () => svc.load(),
      child: CustomScrollView(
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(now).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: AppTheme.midGray,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('LIVE',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                            color: AppTheme.dark,
                          )),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Editorial display headline
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dark,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                      children: [
                        const TextSpan(text: 'Your money,\n'),
                        TextSpan(
                          text: 'in motion. ',
                          style: GoogleFonts.lora(
                            fontSize: 38,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.dark,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Net worth strip
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.dark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'NET WORTH',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.6,
                                color: AppTheme.midGray,
                              ),
                            ),
                            const Spacer(),
                            _DeltaPill(deltaPct: delta),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          Money.format(svc.totalBalance),
                          style: GoogleFonts.poppins(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.light,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _DarkMetric(
                                label: 'INCOME',
                                value: Money.compact(income),
                                color: AppTheme.green,
                              ),
                            ),
                            Container(
                              width: 1, height: 32,
                              color: AppTheme.midGray.withOpacity(.3),
                            ),
                            Expanded(
                              child: _DarkMetric(
                                label: 'SPEND',
                                value: Money.compact(expense),
                                color: AppTheme.orange,
                              ),
                            ),
                            Container(
                              width: 1, height: 32,
                              color: AppTheme.midGray.withOpacity(.3),
                            ),
                            Expanded(
                              child: _DarkMetric(
                                label: 'SAVED',
                                value: Money.compact(savings),
                                color: savings >= 0
                                    ? AppTheme.green
                                    : AppTheme.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Accounts section
          const SliverToBoxAdapter(
            child: SectionHeader(
              eyebrow: 'wallets',
              title: 'Where it lives',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: svc.accounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                  width: 200,
                  child: AccountCard(account: svc.accounts[i]),
                ),
              ),
            ),
          ),

          // Recent transactions
          SliverToBoxAdapter(
            child: SectionHeader(
              eyebrow: 'activity',
              title: 'Recent moves',
              action: recent.length >= 5 ? 'See all' : null,
              onAction: onSeeAllTransactions,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: recent.isEmpty
                ? SliverToBoxAdapter(child: _EmptyTx())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final t = recent[i];
                        return TransactionTile(
                          tx: t,
                          fromAccountName:
                              svc.accountById(t.fromAccountId)?.name,
                          toAccountName:
                              svc.accountById(t.toAccountId)?.name,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditTransactionScreen(transaction: t),
                            ),
                          ),
                        );
                      },
                      childCount: recent.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double deltaPct;
  const _DeltaPill({required this.deltaPct});

  @override
  Widget build(BuildContext context) {
    final isUp = deltaPct >= 0;
    final color = isUp ? AppTheme.orange : AppTheme.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${deltaPct.abs().toStringAsFixed(0)}% vs last',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DarkMetric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
              color: AppTheme.midGray,
            )),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.3,
            )),
      ],
    );
  }
}

class _EmptyTx extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppTheme.orangeTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppTheme.orange),
          ),
          const SizedBox(height: 14),
          Text('No transactions yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap the orange button to log your\nfirst income or expense.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 13,
              color: AppTheme.midGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
