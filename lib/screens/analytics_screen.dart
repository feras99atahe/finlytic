import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late DateTime _month;
  String? _contactFilter;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Future<void> _pickContact(BuildContext context, FinanceService svc) async {
    final names = svc.allContactNames.toList()..sort();
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ContactFilterSheet(
        names: names,
        selected: _contactFilter,
        onPick: (name) {
          setState(() => _contactFilter = name);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final income    = svc.incomeForMonth(_month, contact: _contactFilter);
    final expense   = svc.expensesForMonth(_month, contact: _contactFilter);
    final savings   = svc.savingsForMonth(_month, contact: _contactFilter);
    final delta     = svc.spendingDeltaPct(_month, contact: _contactFilter);
    final breakdown = svc.categoryBreakdown(_month, contact: _contactFilter);
    final cashCard  = svc.cashVsCard(_month, contact: _contactFilter);

    final prevMonth = DateTime(_month.year, _month.month - 1);
    final prevExpense = svc.expensesForMonth(prevMonth);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ANALYTICS',
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
                      const TextSpan(text: 'Patterns, '),
                      TextSpan(
                          text: 'leaks,',
                          style: GoogleFonts.lora(
                            fontSize: 32,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.dark,
                          )),
                      const TextSpan(text: ' wins.'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _MonthSelector(
                  month: _month,
                  onPrev: () => _shift(-1),
                  onNext: () => _shift(1),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _pickContact(context, svc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _contactFilter != null
                          ? AppTheme.orange.withAlpha(20)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _contactFilter != null
                            ? AppTheme.orange
                            : AppTheme.lightGray,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _contactFilter != null
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                          size: 16,
                          color: _contactFilter != null
                              ? AppTheme.orange
                              : AppTheme.midGray,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _contactFilter ?? 'All contacts',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: _contactFilter != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _contactFilter != null
                                  ? AppTheme.orange
                                  : AppTheme.midGray,
                            ),
                          ),
                        ),
                        if (_contactFilter != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _contactFilter = null),
                            child: const Icon(Icons.clear_rounded,
                                size: 16, color: AppTheme.orange),
                          )
                        else
                          const Icon(Icons.expand_more_rounded,
                              size: 16, color: AppTheme.midGray),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bar chart: income vs expense
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Income vs Expense',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      _SwatchLabel(color: AppTheme.green, label: 'Income'),
                      const SizedBox(width: 10),
                      _SwatchLabel(color: AppTheme.orange, label: 'Spend'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: [income, expense, 100.0]
                                .reduce((a, b) => a > b ? a : b) *
                            1.25,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppTheme.lightGray,
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (v, _) {
                                final lbls = ['Income', 'Spend'];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    lbls[v.toInt()],
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.midGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          _bar(0, income, AppTheme.green),
                          _bar(1, expense, AppTheme.orange),
                        ],
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: AppTheme.dark,
                            getTooltipItem: (g, _, __, ___) =>
                                BarTooltipItem(
                                    Money.format(g.barRods.first.toY),
                                    GoogleFonts.poppins(
                                      color: AppTheme.light,
                                      fontWeight: FontWeight.w600,
                                    )),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SavingsBanner(
                      savings: savings, deltaPct: delta, prev: prevExpense),
                ],
              ),
            ),
          ),
        ),

        // Cash vs Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SplitCard(
                    label: 'CASH',
                    value: cashCard.cash,
                    total: cashCard.cash + cashCard.card,
                    color: AppTheme.orange,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SplitCard(
                    label: 'CARD',
                    value: cashCard.card,
                    total: cashCard.cash + cashCard.card,
                    color: AppTheme.blue,
                    icon: Icons.credit_card_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Category breakdown
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Where the money went',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Compared to last month — leak detector.',
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        color: AppTheme.midGray,
                        fontStyle: FontStyle.italic,
                      )),
                  const SizedBox(height: 16),
                  if (breakdown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No expenses this month.',
                            style: GoogleFonts.lora(
                                fontSize: 13, color: AppTheme.midGray)),
                      ),
                    )
                  else ...[
                    ..._sortedEntries(breakdown).map((e) {
                      final color = AppTheme.categoryColors[e.key] ??
                          AppTheme.midGray;
                      final pct = expense > 0 ? e.value / expense : 0.0;
                      final dlt = svc.categoryDelta(e.key, _month, contact: _contactFilter);
                      return _CategoryRow(
                        name: e.key,
                        amount: e.value,
                        pct: pct,
                        color: color,
                        delta: dlt,
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  BarChartGroupData _bar(int x, double y, Color c) => BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: y,
            color: c,
            width: 36,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
              bottom: Radius.circular(2),
            ),
          ),
        ],
      );

  List<MapEntry<String, double>> _sortedEntries(Map<String, double> m) {
    final list = m.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext;
  const _MonthSelector(
      {required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
            color: AppTheme.dark,
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM y').format(month),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dark,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
            color: AppTheme.dark,
          ),
        ],
      ),
    );
  }
}

class _SwatchLabel extends StatelessWidget {
  final Color color;
  final String label;
  const _SwatchLabel({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.midGray,
            )),
      ],
    );
  }
}

class _SavingsBanner extends StatelessWidget {
  final double savings, prev, deltaPct;
  const _SavingsBanner(
      {required this.savings, required this.deltaPct, required this.prev});

  @override
  Widget build(BuildContext context) {
    final positive = savings >= 0;
    final spendUp = deltaPct > 0;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: positive ? AppTheme.greenTint : AppTheme.orangeTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            positive ? Icons.celebration_outlined : Icons.warning_amber_rounded,
            color: positive ? AppTheme.green : AppTheme.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.lora(
                    fontSize: 13, color: AppTheme.dark, height: 1.4),
                children: [
                  TextSpan(
                    text: 'Saved ${Money.format(savings)} this month. ',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppTheme.dark),
                  ),
                  if (prev > 0)
                    TextSpan(
                      text: 'Spending is ${spendUp ? 'up' : 'down'} '
                          '${deltaPct.abs().toStringAsFixed(1)}% vs last month.',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  final String label;
  final double value, total;
  final Color color;
  final IconData icon;
  const _SplitCard({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                    color: AppTheme.midGray,
                  )),
              const Spacer(),
              Text('$pct%',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Text(Money.format(value),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: total > 0 ? value / total : 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
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

// ── Contact filter bottom sheet ───────────────────────────────────────────────
class _ContactFilterSheet extends StatelessWidget {
  final List<String> names;
  final String? selected;
  final ValueChanged<String?> onPick;

  const _ContactFilterSheet({
    required this.names,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.lightGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Filter by contact',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppTheme.dark)),
        ),
        ListTile(
          leading: const Icon(Icons.people_outline_rounded,
              color: AppTheme.midGray),
          title: Text('All contacts',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500, color: AppTheme.dark)),
          selected: selected == null,
          selectedTileColor: AppTheme.orange.withAlpha(15),
          onTap: () => onPick(null),
        ),
        if (names.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No contacts with transactions yet.',
                  style: GoogleFonts.lora(
                      fontSize: 13, color: AppTheme.midGray)),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView(
              shrinkWrap: true,
              children: names
                  .map((name) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.orange.withAlpha(25),
                          child: Text(
                            name[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                                color: AppTheme.orange,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(name,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.dark)),
                        selected: name == selected,
                        selectedTileColor: AppTheme.orange.withAlpha(15),
                        onTap: () => onPick(name),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final double amount, pct, delta;
  final Color color;
  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.pct,
    required this.color,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.dark,
                    )),
              ),
              if (delta != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: up
                        ? AppTheme.orangeTint
                        : AppTheme.greenTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${up ? '+' : ''}${Money.compact(delta)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: up ? AppTheme.orange : AppTheme.green,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(Money.format(amount),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
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
