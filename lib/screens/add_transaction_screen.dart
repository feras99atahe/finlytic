import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/transaction.dart' as txm;
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/item_editor.dart';

class AddTransactionScreen extends StatefulWidget {
  /// Tab to open on: 0 = Income, 1 = Expense, 2 = Transfer, 3 = Debt.
  /// Used by the home-screen quick-add widget to jump straight to a type.
  final int initialTab;

  const AddTransactionScreen({super.key, this.initialTab = 0});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
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
  final _amount  = TextEditingController();
  final _note    = TextEditingController();
  String? _toId;
  String? _contact;
  bool _opening = false;
  DateTime _date = DateTime.now();
  List<txm.TxItem> _items = const [];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final eligible = svc.accounts.toList();
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
        _ContactPickerField(
          value: _contact,
          onChanged: (v) => setState(() => _contact = v),
        ),
        if (!_opening) ...[
          const SizedBox(height: 20),
          ItemListEditor(
            initial: _items,
            onChanged: (items) => _items = items,
          ),
        ],
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
            contact: _contact,
            note: _note.text,
            date: _date,
            items: _items);
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
  final _amount  = TextEditingController();
  final _note    = TextEditingController();
  String _category = 'Food';
  String? _fromId;
  String? _contact;
  DateTime _date = DateTime.now();
  List<txm.TxItem> _items = const [];
  bool _isRecurring = false;
  bool _isEssential = false;
  int _recurrenceMonths = 0;
  String? _bucket;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final eligible = svc.accounts.toList();
    _fromId ??= eligible.isNotEmpty ? eligible.first.id : null;
    final categories = svc.categories;
    final buckets = svc.budgetSplits;

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
        const SizedBox(height: 20),
        _Label('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...categories.map((c) {
              final selected = _category == c;
              final color = AppTheme.colorForCategory(c);
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
            }),
            AddCategoryChip(
              onAdded: (name) => setState(() => _category = name),
            ),
          ],
        ),
        if (buckets.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Label('Comes out of'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _bucketChip('No bucket', _bucket == null,
                  () => setState(() => _bucket = null)),
              for (final b in buckets)
                _bucketChip('${b.name} · ${b.pct.toStringAsFixed(0)}%',
                    _bucket == b.name, () => setState(() => _bucket = b.name)),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _DateField(
            value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 16),
        _ContactPickerField(
          value: _contact,
          onChanged: (v) => setState(() => _contact = v),
        ),
        const SizedBox(height: 20),
        ItemListEditor(
          initial: _items,
          onChanged: (items) => _items = items,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 20),
        ExpenseAxisFields(
          isRecurring: _isRecurring,
          isEssential: _isEssential,
          recurrenceMonths: _recurrenceMonths,
          onRecurringChanged: (v) => setState(() => _isRecurring = v),
          onEssentialChanged: (v) => setState(() => _isEssential = v),
          onRecurrenceMonthsChanged: (v) =>
              setState(() => _recurrenceMonths = v),
        ),
        const SizedBox(height: 28),
        _SubmitButton(label: 'Record expense', onTap: _submit),
      ],
    );
  }

  Widget _bucketChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.dark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.dark : AppTheme.lightGray),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppTheme.light : AppTheme.dark,
            )),
      ),
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
            contact: _contact,
            note: _note.text,
            date: _date,
            items: _items,
            isRecurring: _isRecurring,
            isEssential: _isEssential,
            recurrenceMonths: _recurrenceMonths,
            budgetBucket: _bucket,
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
  final _note   = TextEditingController();
  String? _fromId;
  String? _toId;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final fromAccounts = svc.accounts.toList();
    final toAccounts = svc.accounts
        .where((a) => a.id != _fromId)
        .toList();

    _fromId ??= fromAccounts.isNotEmpty ? fromAccounts.first.id : null;
    if (_toId == _fromId) _toId = null;
    _toId ??= toAccounts.isNotEmpty ? toAccounts.first.id : null;

    return _FormFrame(
      children: [
        _AmountField(controller: _amount),
        const SizedBox(height: 24),

        _Label('From'),
        _AccountPicker(
          accounts: fromAccounts,
          selectedId: _fromId,
          onChanged: (id) => setState(() {
            _fromId = id;
            if (_toId == id) _toId = null;
          }),
        ),
        const SizedBox(height: 20),

        _Label('To'),
        _AccountPicker(
          accounts: toAccounts,
          selectedId: _toId,
          onChanged: (id) => setState(() => _toId = id),
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
    if (amt == null || amt <= 0 || _fromId == null || _toId == null) return;
    if (_fromId == _toId) {
      _toast(context, 'Source and destination must be different accounts.');
      return;
    }
    try {
      await context.read<FinanceService>().transfer(
            fromAccountId: _fromId!,
            toAccountId: _toId!,
            amount: amt,
            note: _note.text,
            date: _date,
          );
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
  final _note   = TextEditingController();
  // true = I owe (just record, no account deduction)
  // false = I paid / I lent (deduct from an account)
  bool _iOwe = true;
  String? _fromId;
  String? _contact;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final eligible = svc.accounts.toList();
    if (!_iOwe) _fromId ??= eligible.isNotEmpty ? eligible.first.id : null;

    return _FormFrame(
      children: [
        // Mode toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.lightGray),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _ModeChip(
                label: 'I owe',
                subtitle: 'Will pay later',
                icon: Icons.hourglass_bottom_rounded,
                selected: _iOwe,
                onTap: () => setState(() => _iOwe = true),
              ),
              _ModeChip(
                label: 'I paid / lent',
                subtitle: 'Money left my account',
                icon: Icons.payments_outlined,
                selected: !_iOwe,
                onTap: () => setState(() => _iOwe = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _AmountField(controller: _amount),
        const SizedBox(height: 24),
        _Label(_iOwe ? 'Owed to (contact)' : 'Contact'),
        _ContactPickerField(
          value: _contact,
          onChanged: (v) => setState(() => _contact = v),
          hint: 'Select or type contact name *',
        ),
        if (!_iOwe) ...[
          const SizedBox(height: 20),
          _Label('Pay from account'),
          _AccountPicker(
            accounts: eligible,
            selectedId: _fromId,
            onChanged: (id) => setState(() => _fromId = id),
          ),
        ],
        const SizedBox(height: 20),
        _DateField(
            value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 28),
        _SubmitButton(
          label: _iOwe ? 'Record debt (I owe)' : 'Log payment / loan',
          onTap: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0) return;
    if (_contact == null || _contact!.trim().isEmpty) {
      _toast(context, 'Please select or enter a contact name.');
      return;
    }
    if (!_iOwe && _fromId == null) {
      _toast(context, 'Please select which account to pay from.');
      return;
    }
    try {
      await context.read<FinanceService>().addDebtTransaction(
            fromAccountId: _iOwe ? null : _fromId,
            amount: amt,
            contact: _contact!.trim(),
            note: _note.text,
            date: _date,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(context, e.toString());
    }
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.dark : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? AppTheme.light : AppTheme.midGray),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.light : AppTheme.dark,
                  )),
              Text(subtitle,
                  style: GoogleFonts.lora(
                      fontSize: 10,
                      color: selected
                          ? AppTheme.light.withAlpha(180)
                          : AppTheme.midGray)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Contact picker ───────────────────────────
class _ContactPickerField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String hint;

  const _ContactPickerField({
    required this.value,
    required this.onChanged,
    this.hint = 'Add contact (optional)',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final result = await showModalBottomSheet<String?>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _ContactSheet(initial: value),
        );
        if (result != null) {
          onChanged(result.isEmpty ? null : result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGray),
        ),
        child: Row(
          children: [
            Icon(
              value != null
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              color: value != null ? AppTheme.orange : AppTheme.midGray,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? hint,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight:
                      value != null ? FontWeight.w500 : FontWeight.w400,
                  color:
                      value != null ? AppTheme.dark : AppTheme.midGray,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.clear_rounded,
                    size: 18, color: AppTheme.midGray),
              )
            else
              const Icon(Icons.expand_more_rounded,
                  size: 20, color: AppTheme.midGray),
          ],
        ),
      ),
    );
  }
}

class _ContactSheet extends StatefulWidget {
  final String? initial;
  const _ContactSheet({this.initial});

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final contacts = svc.contacts
        .where((c) =>
            _query.isEmpty ||
            c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    final typedNotInList = _query.isNotEmpty &&
        !contacts.any(
            (c) => c.name.toLowerCase() == _query.toLowerCase());

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Search or type a name…',
                hintStyle: GoogleFonts.poppins(color: AppTheme.midGray),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(
                            () { _search.clear(); _query = ''; }),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.light,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.lightGray)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.lightGray)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                // Clear option
                if (widget.initial != null)
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined,
                        color: AppTheme.midGray),
                    title: Text('No contact',
                        style: GoogleFonts.poppins(
                            color: AppTheme.midGray,
                            fontWeight: FontWeight.w500)),
                    onTap: () => Navigator.pop(context, ''),
                  ),

                // Saved contacts
                ...contacts.map((c) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.orange.withAlpha(30),
                        child: Text(
                          c.name[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: AppTheme.orange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(c.name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.dark)),
                      subtitle: c.phone != null
                          ? Text(c.phone!,
                              style: GoogleFonts.lora(
                                  fontSize: 12, color: AppTheme.midGray))
                          : null,
                      selected: c.name == widget.initial,
                      selectedTileColor:
                          AppTheme.orange.withAlpha(15),
                      onTap: () => Navigator.pop(context, c.name),
                    )),

                // Use typed name if not in list
                if (typedNotInList)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.greenTint,
                      child: Icon(Icons.add_rounded,
                          color: AppTheme.green, size: 20),
                    ),
                    title: Text('Use "$_query"',
                        style: GoogleFonts.poppins(
                            color: AppTheme.green,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text('Type a custom name',
                        style: GoogleFonts.lora(
                            fontSize: 12, color: AppTheme.midGray)),
                    onTap: () => Navigator.pop(context, _query),
                  ),

                // Empty state
                if (contacts.isEmpty && !typedNotInList)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No contacts yet. Type a name above.',
                        style: GoogleFonts.lora(
                            fontSize: 13, color: AppTheme.midGray),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────── Shared form widgets ───────────────────────────
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
