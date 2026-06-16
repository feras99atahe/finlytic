import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/goal.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final avg = svc.effectiveMonthlySavings();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOALS',
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
                      const TextSpan(text: 'Save with '),
                      TextSpan(
                          text: 'intent.',
                          style: GoogleFonts.lora(
                            fontSize: 32,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.dark,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CapacityCard(avgSavings: avg, svc: svc),
                const SizedBox(height: 12),
                _EconomicInsightCard(svc: svc),
                const SizedBox(height: 12),
                _AllocationMatrixCard(avgSavings: avg),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                // 0 = risk fund card
                if (i == 0) return _RiskFundCard(avgSavings: avg);
                // 1..goals.length = goal cards
                final goalIdx = i - 1;
                if (goalIdx < svc.goals.length) {
                  return _GoalCard(
                    goal: svc.goals[goalIdx],
                    avgSavings: avg,
                    colorIndex: goalIdx,
                  );
                }
                // last = empty state prompt or add button
                if (svc.goals.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.orangeTint,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.flag_outlined,
                              color: AppTheme.orange, size: 26),
                        ),
                        const SizedBox(height: 14),
                        Text('No goals yet',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Add a goal and the allocation matrix\nwill split your savings automatically.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lora(
                              fontSize: 13,
                              color: AppTheme.midGray,
                              height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _newGoal(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create your first goal'),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _newGoal(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add another goal'),
                  ),
                );
              },
              childCount: svc.goals.length + 2, // risk fund + goals + button
            ),
          ),
        ),
      ],
    );
  }

  void _newGoal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.light,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _NewGoalSheet(),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  final double avgSavings;
  final FinanceService svc;
  const _CapacityCard({required this.avgSavings, required this.svc});

  @override
  Widget build(BuildContext context) {
    final hasSalary = svc.monthlySalary > 0;
    final completedMonths = svc.completedMonthsOfData();
    final hasData = svc.hasEnoughData;

    // Determine data quality state
    final noData = !hasSalary && !hasData;
    final salaryOnlyNoHistory = hasSalary && !hasData;

    final positive = avgSavings > 0;
    final formula = hasSalary
        ? 'S = Salary − Avg. Expenses'
        : 'S = Avg. Income − Expenses';

    String subtitle;
    if (noData) {
      subtitle = 'Add salary or log a full month of transactions.';
    } else if (salaryOnlyNoHistory) {
      subtitle = 'Salary only — no completed month of expenses yet.';
    } else if (hasSalary) {
      subtitle = 'Salary minus avg. expenses over $completedMonths completed ${completedMonths == 1 ? 'month' : 'months'}.';
    } else {
      subtitle = positive
          ? 'Avg. over $completedMonths completed ${completedMonths == 1 ? 'month' : 'months'} · opening balances excluded.'
          : 'Spending exceeds income across $completedMonths ${completedMonths == 1 ? 'month' : 'months'}.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.dark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: noData
                      ? AppTheme.midGray.withOpacity(.2)
                      : (positive ? AppTheme.green : AppTheme.orange)
                          .withOpacity(.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  noData
                      ? Icons.hourglass_empty_rounded
                      : positive
                          ? Icons.savings_outlined
                          : Icons.warning_amber_rounded,
                  color: noData
                      ? AppTheme.midGray
                      : positive
                          ? AppTheme.green
                          : AppTheme.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noData ? 'SAVING CAPACITY · PENDING' : 'SAVING CAPACITY · $formula',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                        color: AppTheme.midGray,
                      )),
                    const SizedBox(height: 4),
                    Text(
                      noData ? 'Not enough data' : '${Money.format(avgSavings)}/mo',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: noData ? AppTheme.midGray : AppTheme.light,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: AppTheme.midGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Data quality indicator
          if (!noData) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasData
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 12,
                    color: hasData ? AppTheme.green : AppTheme.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasData
                        ? '$completedMonths completed ${completedMonths == 1 ? 'month' : 'months'} of data'
                        : 'Waiting for 1 full month of transactions',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: hasData ? AppTheme.green : AppTheme.orange,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EconomicInsightCard extends StatelessWidget {
  final FinanceService svc;
  const _EconomicInsightCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final budget = svc.budgetRule5030();
    final now = DateTime.now();
    final rate = svc.savingsRatePct(now);
    final hasSalary = svc.monthlySalary > 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.orangeTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_graph_rounded,
                    color: AppTheme.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Text('ECONOMIC BASIS',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppTheme.dark,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => _showExplainer(context),
                child: const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.midGray),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasSalary)
            Text(
              'Add your monthly salary in Profile to unlock budget science and smarter goal estimates.',
              style: GoogleFonts.lora(
                fontSize: 12,
                color: AppTheme.midGray,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            )
          else ...[
            Text('50/30/20 Budget Rule',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark)),
            const SizedBox(height: 8),
            _BudgetBar(
              label: 'Needs 50%',
              amount: budget!.needs,
              color: AppTheme.blue,
              fraction: 0.50,
            ),
            const SizedBox(height: 6),
            _BudgetBar(
              label: 'Wants 30%',
              amount: budget.wants,
              color: AppTheme.orange,
              fraction: 0.30,
            ),
            const SizedBox(height: 6),
            _BudgetBar(
              label: 'Savings 20%',
              amount: budget.savings,
              color: AppTheme.green,
              fraction: 0.20,
            ),
            if (rate != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.lightGray),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    rate >= 20
                        ? Icons.check_circle_outline_rounded
                        : Icons.trending_up_rounded,
                    size: 14,
                    color: rate >= 20 ? AppTheme.green : AppTheme.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rate >= 20
                          ? 'This month: ${rate.toStringAsFixed(1)}% savings rate — on target.'
                          : 'This month: ${rate.toStringAsFixed(1)}% savings rate — aim for 20%.',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: rate >= 20 ? AppTheme.green : AppTheme.orange,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showExplainer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.light,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _GoalScienceSheet(),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final double fraction;
  const _BudgetBar(
      {required this.label,
      required this.amount,
      required this.color,
      required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.midGray)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(Money.format(amount),
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.dark)),
      ],
    );
  }
}

class _GoalScienceSheet extends StatelessWidget {
  const _GoalScienceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('How goal time is calculated',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.dark)),
          const SizedBox(height: 16),
          _scienceBlock(
            icon: Icons.calculate_outlined,
            title: 'The formula',
            body:
                'Months left = ⌈ Remaining ÷ (S × Allocation%) ⌉\n\n'
                'Where S is your saving capacity per month, and Allocation% is how much of S goes to this goal.',
          ),
          const SizedBox(height: 14),
          _scienceBlock(
            icon: Icons.payments_outlined,
            title: 'Saving capacity (S)',
            body:
                'When you set a salary: S = Salary − Avg. monthly expenses.\n'
                'Without salary: S = Avg. monthly (income − expenses) from your transaction history.',
          ),
          const SizedBox(height: 14),
          _scienceBlock(
            icon: Icons.timeline_rounded,
            title: 'Goal term & allocation',
            body:
                'Short-term (≤1 yr) → 100% of S. Finish fast, aggressive saving.\n'
                'Medium-term (1–3 yr) → 50% of S. Balanced, room for other goals.\n'
                'Long-term (3+ yr) → 25% of S. Patient, low monthly pressure.',
          ),
          const SizedBox(height: 14),
          _scienceBlock(
            icon: Icons.auto_graph_rounded,
            title: '50/30/20 Rule (Elizabeth Warren)',
            body:
                'A widely-used personal finance framework:\n'
                '• 50% of income → Needs (rent, food, bills)\n'
                '• 30% of income → Wants (dining, hobbies)\n'
                '• 20% of income → Savings & goals\n\n'
                'Hitting 20% savings rate is the economic benchmark for healthy finances.',
          ),
        ],
      ),
    );
  }

  Widget _scienceBlock({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: AppTheme.orangeTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.orange, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.dark)),
              const SizedBox(height: 4),
              Text(body,
                  style: GoogleFonts.lora(
                      fontSize: 12, color: AppTheme.midGray, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final double avgSavings;
  final int colorIndex;
  const _GoalCard({required this.goal, required this.avgSavings, this.colorIndex = 0});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final months = goal.estimatedMonthsLeft(avgSavings);
    final noData = avgSavings <= 0 && !svc.hasEnoughData && svc.monthlySalary <= 0;
    final eta = noData
        ? 'Add salary or complete 1 month of data'
        : months == null
            ? 'Stalled — increase savings or allocation'
            : months == 0
                ? 'Within this month'
                : '$months ${months == 1 ? 'month' : 'months'} left';

    // Derive live term from current savings capacity, not the stored one.
    final liveTerm = months != null && months > 0
        ? GoalTermX.fromMonths(months)
        : (avgSavings > 0
            ? GoalTermX.autoFrom(goal.remaining, avgSavings)
            : goal.term);

    final termColor = liveTerm == GoalTerm.shortTerm
        ? AppTheme.green
        : liveTerm == GoalTerm.mediumTerm
            ? AppTheme.blue
            : AppTheme.orange;
    final termTint = liveTerm == GoalTerm.shortTerm
        ? AppTheme.greenTint
        : liveTerm == GoalTerm.mediumTerm
            ? AppTheme.blueTint
            : AppTheme.orangeTint;

    final progress = goal.progress;

    return Container(
      margin: const EdgeInsets.only(top: 12),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: termTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(liveTerm.label.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: termColor,
                    )),
              ),
              const SizedBox(width: 6),
              Text(liveTerm.range,
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: AppTheme.midGray,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.midGray),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(goal.name,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dark)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: Money.format(goal.savedAmount),
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.dark),
                ),
                TextSpan(
                  text: ' / ${Money.format(goal.targetAmount)}',
                  style: GoogleFonts.lora(
                      fontSize: 14, color: AppTheme.midGray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                months == null
                    ? Icons.error_outline_rounded
                    : Icons.schedule_rounded,
                size: 14,
                color: months == null ? AppTheme.orange : AppTheme.midGray,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(eta,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: months == null
                          ? AppTheme.orange
                          : AppTheme.dark,
                    )),
              ),
              Text('${(goal.allocationPct * 100).toStringAsFixed(0)}% of S',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.midGray,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _contribute(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Contribute'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dark,
                    side: const BorderSide(color: AppTheme.lightGray),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _contribute(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Contribute to ${goal.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '\$ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true) {
      final amt = double.tryParse(controller.text);
      if (amt != null && amt > 0) {
        await context.read<FinanceService>().contributeToGoal(goal.id, amt);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text('${goal.name} will be removed.',
            style: GoogleFonts.lora()),
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
      await context.read<FinanceService>().deleteGoal(goal.id);
    }
  }
}

// ──────────────────────────────────────────────────────────
// ALLOCATION MATRIX
// ──────────────────────────────────────────────────────────

const _kGoalPalette = [
  Color(0xFF6A9BCC),
  Color(0xFF788C5D),
  Color(0xFFD9A557),
  Color(0xFF8B6BA8),
  Color(0xFFC18558),
  Color(0xFF4F7AA8),
];

class _AllocationMatrixCard extends StatelessWidget {
  final double avgSavings;
  const _AllocationMatrixCard({required this.avgSavings});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final goals = svc.goals;
    final riskPct = svc.riskFundAllocationPct;
    final totalPct = svc.totalAllocatedPct;
    final overAllocated = totalPct > 1.001;
    final freePct = overAllocated ? 0.0 : 1.0 - totalPct;
    final canAdd = !overAllocated;

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
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.orangeTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.donut_small_rounded,
                    color: AppTheme.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Text('ALLOCATION MATRIX',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppTheme.dark,
                  )),
              const Spacer(),
              if (overAllocated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Over ${((totalPct - 1) * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.orange)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Stacked allocation bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  if (riskPct > 0)
                    Expanded(
                      flex: (riskPct * 1000).round(),
                      child: Container(color: AppTheme.orange),
                    ),
                  ...goals.asMap().entries.map((e) {
                    if (e.value.allocationPct <= 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: (e.value.allocationPct * 1000).round(),
                      child: Container(
                          color: _kGoalPalette[e.key % _kGoalPalette.length]),
                    );
                  }),
                  if (freePct > 0.001)
                    Expanded(
                      flex: (freePct * 1000).round(),
                      child: Container(color: AppTheme.lightGray),
                    ),
                  if (overAllocated)
                    Expanded(
                      flex: ((totalPct - 1) * 1000).round().clamp(1, 1000),
                      child: Container(color: AppTheme.orange.withOpacity(0.3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Risk fund row
          _AllocationRow(
            dot: AppTheme.orange,
            label: 'Emergency Fund',
            pct: riskPct,
            onMinus: riskPct >= 0.05
                ? () => context
                    .read<FinanceService>()
                    .setRiskFundAllocation(riskPct - 0.05)
                : null,
            onPlus: canAdd
                ? () => context
                    .read<FinanceService>()
                    .setRiskFundAllocation(riskPct + 0.05)
                : null,
          ),

          if (goals.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppTheme.lightGray),
            ),
            ...goals.asMap().entries.map((e) {
              final g = e.value;
              final color = _kGoalPalette[e.key % _kGoalPalette.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AllocationRow(
                  dot: color,
                  label: g.name,
                  pct: g.allocationPct,
                  onMinus: g.allocationPct >= 0.05
                      ? () => context
                          .read<FinanceService>()
                          .updateGoalAllocationPct(g.id, g.allocationPct - 0.05)
                      : null,
                  onPlus: canAdd
                      ? () => context
                          .read<FinanceService>()
                          .updateGoalAllocationPct(g.id, g.allocationPct + 0.05)
                      : null,
                ),
              );
            }),
          ],

          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Divider(height: 1, color: AppTheme.lightGray),
          ),

          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.midGray),
                    children: [
                      TextSpan(
                        text: '${(totalPct * 100).clamp(0, 200).toStringAsFixed(0)}% allocated',
                        style: const TextStyle(
                            color: AppTheme.dark, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: overAllocated
                            ? ' · reduce allocations'
                            : '  ·  ${(freePct * 100).toStringAsFixed(0)}% free  ·  ${Money.format(avgSavings * freePct)}/mo unassigned',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  final Color dot;
  final String label;
  final double pct;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const _AllocationRow({
    required this.dot,
    required this.label,
    required this.pct,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.dark)),
        ),
        const SizedBox(width: 8),
        _StepBtn(
          icon: Icons.remove_rounded,
          active: onMinus != null,
          dark: false,
          onTap: onMinus,
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark),
          ),
        ),
        const SizedBox(width: 6),
        _StepBtn(
          icon: Icons.add_rounded,
          active: onPlus != null,
          dark: true,
          onTap: onPlus,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool dark;
  final VoidCallback? onTap;
  const _StepBtn(
      {required this.icon,
      required this.active,
      required this.dark,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: active
              ? (dark ? AppTheme.dark : AppTheme.lightGray)
              : AppTheme.lightGray.withOpacity(0.5),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon,
            size: 14,
            color: active
                ? (dark ? AppTheme.light : AppTheme.dark)
                : AppTheme.midGray),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// RISK FUND CARD
// ──────────────────────────────────────────────────────────

class _RiskFundCard extends StatelessWidget {
  final double avgSavings;
  const _RiskFundCard({required this.avgSavings});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final target = svc.riskFundTarget;
    final saved = svc.riskFundSavedAmount;
    final hasTarget = target > 0;
    final progress =
        hasTarget ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final funded = hasTarget && saved >= target;
    final allocated = avgSavings * svc.riskFundAllocationPct;
    final monthsLeft =
        (!funded && allocated > 0 && hasTarget)
            ? ((target - saved) / allocated).ceil()
            : null;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: funded ? AppTheme.greenTint : AppTheme.orangeTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: funded
                ? AppTheme.green.withOpacity(0.35)
                : AppTheme.orange.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: funded
                      ? AppTheme.green.withOpacity(0.2)
                      : AppTheme.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  funded
                      ? Icons.shield_rounded
                      : Icons.security_rounded,
                  color: funded ? AppTheme.green : AppTheme.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EMERGENCY FUND',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: funded ? AppTheme.green : AppTheme.orange,
                      )),
                  Text(
                    funded ? 'Fully funded — protected.' : '3 months of expenses',
                    style: GoogleFonts.lora(
                        fontSize: 12,
                        color: funded ? AppTheme.green : AppTheme.orange,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const Spacer(),
              if (funded)
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.green, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                Money.format(saved),
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                    letterSpacing: -0.5),
              ),
              Text(
                hasTarget ? ' / ${Money.format(target)}' : ' saved',
                style: GoogleFonts.lora(
                    fontSize: 13, color: AppTheme.midGray),
              ),
            ],
          ),
          if (hasTarget) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color:
                          funded ? AppTheme.green : AppTheme.orange,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'Log monthly expenses to auto-calculate your 3-month target.',
              style: GoogleFonts.lora(
                  fontSize: 11,
                  color: AppTheme.midGray,
                  fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                monthsLeft == null
                    ? (funded ? Icons.check_rounded : Icons.pause_circle_outline_rounded)
                    : Icons.schedule_rounded,
                size: 13,
                color: AppTheme.midGray,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  funded
                      ? 'Your safety net is in place.'
                      : monthsLeft != null
                          ? '$monthsLeft ${monthsLeft == 1 ? 'month' : 'months'} to fund at ${(svc.riskFundAllocationPct * 100).toStringAsFixed(0)}% allocation'
                          : 'Stalled — raise allocation or reduce expenses',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.midGray),
                ),
              ),
            ],
          ),
          if (!funded) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _contribute(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Contribute'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange,
                  side: const BorderSide(color: AppTheme.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _contribute(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add to Emergency Fund'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '\$ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final amt = double.tryParse(controller.text);
      if (amt != null && amt > 0) {
        await context.read<FinanceService>().contributeToRiskFund(amt);
      }
    }
    controller.dispose();
  }
}

// ──────────────────────────────────────────────────────────

class _NewGoalSheet extends StatefulWidget {
  const _NewGoalSheet();
  @override
  State<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends State<_NewGoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();

  @override
  void initState() {
    super.initState();
    _target.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final savings = svc.effectiveMonthlySavings();
    final targetAmt = double.tryParse(_target.text.replaceAll(',', ''));

    // Live-compute term and months from the entered amount
    GoalTerm? autoTerm;
    int? baseMonths;
    if (targetAmt != null && targetAmt > 0 && savings > 0) {
      baseMonths = (targetAmt / savings).ceil();
      autoTerm = GoalTermX.fromMonths(baseMonths);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 24, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('New goal',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Enter an amount — the term is calculated from your income.',
              style: GoogleFonts.lora(
                  fontSize: 13,
                  color: AppTheme.midGray,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Goal name',
              hintText: 'e.g. New laptop, Trip to Italy',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target amount',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 16),

          // Auto-classification panel
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: autoTerm != null
                ? _TermClassificationPanel(
                    key: ValueKey(autoTerm),
                    term: autoTerm,
                    baseMonths: baseMonths!,
                    savings: savings,
                    targetAmt: targetAmt!,
                  )
                : savings <= 0
                    ? _NoSalaryHint()
                    : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final t = double.tryParse(_target.text.replaceAll(',', ''));
                if (_name.text.trim().isEmpty || t == null || t <= 0) return;
                await context.read<FinanceService>().addGoal(
                      name: _name.text.trim(),
                      targetAmount: t,
                    );
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Create goal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermClassificationPanel extends StatelessWidget {
  final GoalTerm term;
  final int baseMonths;
  final double savings;
  final double targetAmt;

  const _TermClassificationPanel({
    super.key,
    required this.term,
    required this.baseMonths,
    required this.savings,
    required this.targetAmt,
  });

  Color get _termColor {
    switch (term) {
      case GoalTerm.shortTerm:  return AppTheme.green;
      case GoalTerm.mediumTerm: return AppTheme.blue;
      case GoalTerm.longTerm:   return AppTheme.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alloc = term.defaultAllocationPct;
    final allocatedSavings = savings * alloc;
    final monthsAtAlloc = allocatedSavings > 0
        ? (targetAmt / allocatedSavings).ceil()
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _termColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _termColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _termColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  term.label.toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                term.range,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _termColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row(Icons.timeline_rounded,
              '$baseMonths months at 100% savings allocation'),
          const SizedBox(height: 5),
          _row(Icons.pie_chart_outline_rounded,
              '${(alloc * 100).toStringAsFixed(0)}% allocation recommended → '
              '${monthsAtAlloc != null ? '$monthsAtAlloc months' : '—'} at that rate'),
          const SizedBox(height: 5),
          _row(Icons.auto_fix_high_rounded,
              'Classification based on \$${Money.format(savings)}/mo saving capacity'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: _termColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.dark,
                    height: 1.4)),
          ),
        ],
      );
}

class _NoSalaryHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.orangeTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppTheme.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Add your salary in Profile to get an automatic goal classification.',
              style: GoogleFonts.lora(
                  fontSize: 12,
                  color: AppTheme.orange,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
