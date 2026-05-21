import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('New entry'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: AppTheme.light,
            child: TabBar(
              controller: _tab,
              indicatorColor: AppTheme.orange,
              indicatorWeight: 2,
              labelColor: AppTheme.dark,
              unselectedLabelColor: AppTheme.midGray,
              labelStyle: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Income'),
                Tab(text: 'Expense'),
                Tab(text: 'Transfer'),
                Tab(text: 'Debt'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _IncomeForm(),
          _ExpenseForm(),
          _TransferForm(),
          _DebtForm(),
        ],
      ),
    );
  }
}

// ─────────────────────────── Income ───────────────────────────
class _IncomeForm extends StatefulWidget {
  const _IncomeForm();
  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _toId;
  bool _opening = false;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final eligible = svc.accounts
        .where((a) => a.type != AccountType.wallet)
        .toList();
    _toId ??= eligible.isNotEmpty ? eligible.first.id : null;

    return _FormFrame(
      children: [
        _AmountField(controller: _amount),
        const SizedBox(height: 24),
        _Label('To account'),
        _AccountPicker(
          accounts: eligible,
          selectedId: _toId,
          onChanged: (id) => setState(() => _toId = id),
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _opening,
          activeColor: AppTheme.orange,
          onChanged: (v) => setState(() => _opening = v),
          title: Text('Mark as Opening Balance',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(
            'Use this for the starting balance of your account.',
            style: GoogleFonts.lora(
                fontSize: 12, color: AppTheme.midGray),
          ),
        ),
        const SizedBox(height: 16),
        _DateField(
            value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 28),
        _SubmitButton(
          label: _opening ? 'Set opening balance' : 'Add income',
          onTap: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0 || _toId == null) return;
    try {
      final svc = context.read<FinanceService>();
      if (_opening) {
        await svc.addOpeningBalance(
            accountId: _toId!, amount: amt, date: _date);
      } else {
        await svc.addIncome(
            toAccountId: _toId!,
            amount: amt,
            note: _note.text,
            date: _date);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(context, e.toString());
    }
  }
}

// ─────────────────────────── Expense ───────────────────────────
class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Food';
  String? _fromId;
  DateTime _date = DateTime.now();

  static const _categories = [
    'Food', 'Services', 'Restaurants', 'Personal',
    'Transport', 'Shopping', 'Health', 'Entertain.', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final eligible = svc.accounts
        .where((a) => a.type != AccountType.safe)
        .toList();
    _fromId ??= eligible.isNotEmpty ? eligible.first.id : null;

    return _FormFrame(
      children: [
        _AmountField(controller: _amount),
        const SizedBox(height: 24),
        _Label('Pay from'),
        _AccountPicker(
          accounts: eligible,
          selectedId: _fromId,
          onChanged: (id) => setState(() => _fromId = id),
        ),
        const SizedBox(height: 6),
        Text(
          'Wallet → cash · Bank → card. Safe is for storage only.',
          style: GoogleFonts.lora(
              fontSize: 11,
              color: AppTheme.midGray,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 20),
        _Label('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final selected = _category == c;
            final color = AppTheme.categoryColors[c] ?? AppTheme.midGray;
            return GestureDetector(
              onTap: () => setState(() => _category = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : AppTheme.lightGray,
                  ),
                ),
                child: Text(
                  c,
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
        const SizedBox(height: 20),
        _DateField(
            value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 28),
        _SubmitButton(label: 'Record expense', onTap: _submit),
      ],
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0 || _fromId == null) return;
    try {
      await context.read<FinanceService>().addExpense(
            fromAccountId: _fromId!,
            amount: amt,
            category: _category,
            note: _note.text,
            date: _date,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(context, e.toString());
    }
  }
}

// ─────────────────────────── Transfer ───────────────────────────
class _TransferForm extends StatefulWidget {
  const _TransferForm();
  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final safe = svc.firstOfType(AccountType.safe);
    final wallet = svc.firstOfType(AccountType.wallet);

    return _FormFrame(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.greenTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.green.withOpacity(.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded,
                  color: AppTheme.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.lora(
                        fontSize: 13, color: AppTheme.dark, height: 1.4),
                    children: [
                      const TextSpan(text: 'The only allowed cash flow:\n'),
                      TextSpan(
                        text: 'Safe → Wallet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _AmountField(controller: _amount),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _AccountStatic(
                label: 'FROM',
                name: safe?.name ?? '—',
                color: AppTheme.green,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.east_rounded, color: AppTheme.midGray),
            ),
            Expanded(
              child: _AccountStatic(
                label: 'TO',
                name: wallet?.name ?? '—',
                color: AppTheme.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DateField(
            value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 28),
        _SubmitButton(label: 'Move money', onTap: _submit),
      ],
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0) return;
    try {
      await context.read<FinanceService>().transferSafeToWallet(
          amount: amt, note: _note.text, date: _date);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(context, e.toString());
    }
  }
}

// ─────────────────────────── Debt ───────────────────────────
class _DebtForm extends StatefulWidget {
  const _DebtForm();
  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  final _amount = TextEditingController();
  final _contact = TextEditingController();
  final _note = TextEditingController();
  String? _fromId;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final eligible = svc.accounts
        .where((a) => a.type != AccountType.safe)
        .toList();
    _fromId ??= eligible.isNotEmpty ? eligible.first.id : null;

    return _FormFrame(
      children: [
        _AmountField(controller: _amount),
        const SizedBox(height: 24),
        _Label('Owed to (contact)'),
        TextField(
          controller: _contact,
          decoration: const InputDecoration(
            hintText: 'e.g. Sara, Ahmed, John…',
            prefixIcon: Icon(Icons.person_outline_rounded,
                color: AppTheme.midGray),
          ),
        ),
        const SizedBox(height: 20),
        _Label('Pay from'),
        _AccountPicker(
          accounts: eligible,
          selectedId: _fromId,
          onChanged: (id) => setState(() => _fromId = id),
        ),
        const SizedBox(height: 20),
        _DateField(
            value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 28),
        _SubmitButton(label: 'Log debt payment', onTap: _submit),
      ],
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0 || _fromId == null) return;
    if (_contact.text.trim().isEmpty) {
      _toast(context, 'Please enter the contact name.');
      return;
    }
    try {
      await context.read<FinanceService>().addDebtTransaction(
            fromAccountId: _fromId!,
            amount: amt,
            contact: _contact.text.trim(),
            note: _note.text,
            date: _date,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(context, e.toString());
    }
  }
}

// ─────────────────────────── Shared form bits ───────────────────────────
class _FormFrame extends StatelessWidget {
  final List<Widget> children;
  const _FormFrame({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppTheme.midGray,
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountField({required this.controller});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Row(
        children: [
          Text('\$',
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w400,
                color: AppTheme.midGray,
              )),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
                letterSpacing: -1,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lightGray,
                  letterSpacing: -1,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  const _AccountPicker({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: accounts.map((a) {
        final selected = a.id == selectedId;
        return GestureDetector(
          onTap: () => onChanged(a.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.dark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.dark : AppTheme.lightGray,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  a.type == AccountType.bank
                      ? Icons.credit_card_rounded
                      : a.type == AccountType.safe
                          ? Icons.lock_outline_rounded
                          : Icons.account_balance_wallet_outlined,
                  size: 14,
                  color: selected ? AppTheme.light : AppTheme.dark,
                ),
                const SizedBox(width: 6),
                Text(
                  a.name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.light : AppTheme.dark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AccountStatic extends StatelessWidget {
  final String label, name;
  final Color color;
  const _AccountStatic(
      {required this.label, required this.name, required this.color});

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
          Text(label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: AppTheme.midGray,
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DateField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGray),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined,
                color: AppTheme.midGray, size: 18),
            const SizedBox(width: 10),
            Text(
              DateFormat('EEEE, MMM d, y').format(value),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SubmitButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: GoogleFonts.lora(color: AppTheme.light)),
      backgroundColor: AppTheme.dark,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
