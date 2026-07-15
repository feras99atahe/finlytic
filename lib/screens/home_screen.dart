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
                  // Monthly balance — the single headline number.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.dark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTHLY BALANCE',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.6,
                            color: AppTheme.midGray,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          Money.format(svc.monthlyBalance),
                          style: GoogleFonts.poppins(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.light,
                            letterSpacing: -1.4,
                          ),
                        ),
                        if (svc.monthlyBalance <= 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Set it in Menu → Profile → Monthly balance.',
                            style: GoogleFonts.lora(
                                fontSize: 12, color: AppTheme.midGray),
                          ),
                        ],
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
