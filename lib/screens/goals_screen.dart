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
    final avg = svc.avgMonthlySavings;

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
                _CapacityCard(avgSavings: avg),
              ],
            ),
          ),
        ),
        if (svc.goals.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.orangeTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.flag_outlined,
                        color: AppTheme.orange, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text('No goals yet',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Set a target — short, medium, or long term —\nand watch your savings line up against it.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      fontSize: 14,
                      color: AppTheme.midGray,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _newGoal(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create your first goal'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i == svc.goals.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlinedButton.icon(
                        onPressed: () => _newGoal(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add another goal'),
                      ),
                    );
                  }
                  return _GoalCard(
                    goal: svc.goals[i],
                    avgSavings: avg,
                  );
                },
                childCount: svc.goals.length + 1,
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
  const _CapacityCard({required this.avgSavings});

  @override
  Widget build(BuildContext context) {
    final positive = avgSavings >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.dark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: (positive ? AppTheme.green : AppTheme.orange)
                  .withOpacity(.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              positive
                  ? Icons.savings_outlined
                  : Icons.warning_amber_rounded,
              color: positive ? AppTheme.green : AppTheme.orange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SAVING CAPACITY · S = I − E',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.3,
                      color: AppTheme.midGray,
                    )),
                const SizedBox(height: 4),
                Text(
                  '${Money.format(avgSavings)}/mo',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.light,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  positive
                      ? 'Avg. surplus across active months.'
                      : 'You are spending more than you earn.',
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
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final double avgSavings;
  const _GoalCard({required this.goal, required this.avgSavings});

  @override
  Widget build(BuildContext context) {
    final months = goal.estimatedMonthsLeft(avgSavings);
    final eta = months == null
        ? 'Stalled — increase savings'
        : months == 0
            ? 'Within this month'
            : '$months ${months == 1 ? 'month' : 'months'} left';

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
                  color: AppTheme.orangeTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(goal.term.label.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: AppTheme.orange,
                    )),
              ),
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

class _NewGoalSheet extends StatefulWidget {
  const _NewGoalSheet();
  @override
  State<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends State<_NewGoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  GoalTerm _term = GoalTerm.shortTerm;

  @override
  Widget build(BuildContext context) {
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
          Text('Define what you’re saving for.',
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
          Text('TIME HORIZON',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: AppTheme.midGray,
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: GoalTerm.values.map((t) {
              final selected = _term == t;
              return GestureDetector(
                onTap: () => setState(() => _term = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.dark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            selected ? AppTheme.dark : AppTheme.lightGray),
                  ),
                  child: Text(
                    '${t.label} · ${(t.defaultAllocationPct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.light : AppTheme.dark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final t = double.tryParse(_target.text);
                if (_name.text.trim().isEmpty || t == null || t <= 0) return;
                await context.read<FinanceService>().addGoal(
                      name: _name.text.trim(),
                      targetAmount: t,
                      term: _term,
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
