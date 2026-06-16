import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/transaction.dart' as txm;
import '../models/tx_edit_log.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/item_editor.dart';

/// Edit an existing transaction. The transaction *type* can be changed via the
/// type selector; the form then shows only the fields relevant to the chosen
/// type. Saving recalculates account balances and appends an entry to the
/// transaction's edit history.
class EditTransactionScreen extends StatefulWidget {
  final txm.Transaction transaction;
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _note;

  late txm.TxType _type;
  String? _fromId;
  String? _toId;
  String? _category;
  String? _contact;
  late DateTime _date;
  late List<txm.TxItem> _items;
  late bool _debtFromAccount; // debt only: was it paid from an account?

  static const _categories = [
    'Food', 'Services', 'Restaurants', 'Personal',
    'Transport', 'Shopping', 'Health', 'Entertain.', 'Other',
  ];

  static const _selectableTypes = [
    txm.TxType.income,
    txm.TxType.expense,
    txm.TxType.transfer,
    txm.TxType.debt,
    txm.TxType.openingBalance,
  ];

  txm.Transaction get _tx => widget.transaction;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
        text: _tx.amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), ''));
    _note = TextEditingController(text: _tx.note ?? '');
    _type = _tx.type;
    _fromId = _tx.fromAccountId;
    _toId = _tx.toAccountId;
    _category = _tx.category;
    _contact = _tx.contact;
    _date = _tx.date;
    _items = List.of(_tx.items);
    _debtFromAccount = _tx.fromAccountId != null;
  }

  /// Switch the transaction to a new [type], back-filling sensible account
  /// defaults so the form isn't left with empty required pickers.
  void _changeType(txm.TxType t) {
    if (t == _type) return;
    final accounts = context.read<FinanceService>().accounts.toList();
    final firstAcc = accounts.isNotEmpty ? accounts.first.id : null;
    setState(() {
      _type = t;
      switch (t) {
        case txm.TxType.income:
        case txm.TxType.openingBalance:
          _toId ??= _fromId ?? firstAcc;
          break;
        case txm.TxType.expense:
          _fromId ??= _toId ?? firstAcc;
          _category ??= _categories.first;
          break;
        case txm.TxType.debt:
          _fromId ??= _toId ?? firstAcc;
          _debtFromAccount = _fromId != null;
          break;
        case txm.TxType.transfer:
          _fromId ??= firstAcc;
          if (_toId == null || _toId == _fromId) {
            final others = accounts.where((a) => a.id != _fromId).toList();
            _toId = others.isNotEmpty ? others.first.id : null;
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Edit ${_type.label}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Type'),
            _typePicker(),
            const SizedBox(height: 20),
            ..._fieldsForType(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Save changes'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _EditHistory(txId: _tx.id),
          ],
        ),
      ),
    );
  }

  List<Widget> _fieldsForType() {
    final svc = context.watch<FinanceService>();
    final accounts = svc.accounts.toList();

    switch (_type) {
      case txm.TxType.income:
        return [
          _amountField(),
          const SizedBox(height: 24),
          const _Label('To account'),
          _accountPicker(accounts, _toId, (id) => setState(() => _toId = id)),
          const SizedBox(height: 16),
          _dateField(),
          const SizedBox(height: 16),
          _contactField(),
          const SizedBox(height: 20),
          ItemListEditor(
            initial: _items,
            onChanged: (it) => _items = it,
          ),
          const SizedBox(height: 16),
          _noteField(),
        ];

      case txm.TxType.openingBalance:
        return [
          _amountField(),
          const SizedBox(height: 24),
          const _Label('Account'),
          _accountPicker(accounts, _toId, (id) => setState(() => _toId = id)),
          const SizedBox(height: 16),
          _dateField(),
        ];

      case txm.TxType.expense:
        return [
          _amountField(),
          const SizedBox(height: 24),
          const _Label('Pay from'),
          _accountPicker(
              accounts, _fromId, (id) => setState(() => _fromId = id)),
          const SizedBox(height: 20),
          const _Label('Category'),
          _categoryPicker(),
          const SizedBox(height: 20),
          _dateField(),
          const SizedBox(height: 16),
          _contactField(),
          const SizedBox(height: 20),
          ItemListEditor(
            initial: _items,
            onChanged: (it) => _items = it,
          ),
          const SizedBox(height: 16),
          _noteField(),
        ];

      case txm.TxType.transfer:
        final toAccounts =
            accounts.where((a) => a.id != _fromId).toList();
        return [
          _amountField(),
          const SizedBox(height: 24),
          const _Label('From'),
          _accountPicker(accounts, _fromId, (id) => setState(() {
                _fromId = id;
                if (_toId == id) _toId = null;
              })),
          const SizedBox(height: 20),
          const _Label('To'),
          _accountPicker(
              toAccounts, _toId, (id) => setState(() => _toId = id)),
          const SizedBox(height: 20),
          _dateField(),
          const SizedBox(height: 16),
          _noteField(),
        ];

      case txm.TxType.debt:
        return [
          _amountField(),
          const SizedBox(height: 24),
          const _Label('Contact'),
          _contactField(hint: 'Contact name *'),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _debtFromAccount,
            activeColor: AppTheme.orange,
            onChanged: (v) => setState(() {
              _debtFromAccount = v;
              if (v) {
                _fromId ??= accounts.isNotEmpty ? accounts.first.id : null;
              }
            }),
            title: Text('Paid from an account',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Off = just a record (I owe), no balance change.',
              style:
                  GoogleFonts.lora(fontSize: 12, color: AppTheme.midGray),
            ),
          ),
          if (_debtFromAccount) ...[
            const SizedBox(height: 8),
            const _Label('Pay from account'),
            _accountPicker(
                accounts, _fromId, (id) => setState(() => _fromId = id)),
          ],
          const SizedBox(height: 16),
          _dateField(),
          const SizedBox(height: 16),
          _noteField(),
        ];
    }
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0) {
      _toast('Enter a valid amount.');
      return;
    }
    final noteText = _note.text.trim();
    final svc = context.read<FinanceService>();

    try {
      switch (_type) {
        case txm.TxType.income:
          if (_toId == null) return _toast('Pick an account.');
          await svc.updateTransaction(
            _tx.id,
            type: txm.TxType.income,
            amount: amt,
            toAccountId: _toId,
            clearFromAccount: true,
            clearCategory: true,
            date: _date,
            contact: _contact,
            clearContact: _contact == null,
            note: noteText.isEmpty ? null : noteText,
            clearNote: noteText.isEmpty,
            items: _items,
          );
          break;

        case txm.TxType.openingBalance:
          if (_toId == null) return _toast('Pick an account.');
          await svc.updateTransaction(
            _tx.id,
            type: txm.TxType.openingBalance,
            amount: amt,
            toAccountId: _toId,
            clearFromAccount: true,
            clearCategory: true,
            clearContact: true,
            clearNote: true,
            items: const [],
            date: _date,
          );
          break;

        case txm.TxType.expense:
          if (_fromId == null) return _toast('Pick an account.');
          await svc.updateTransaction(
            _tx.id,
            type: txm.TxType.expense,
            amount: amt,
            fromAccountId: _fromId,
            clearToAccount: true,
            category: _category ?? _categories.first,
            date: _date,
            contact: _contact,
            clearContact: _contact == null,
            note: noteText.isEmpty ? null : noteText,
            clearNote: noteText.isEmpty,
            items: _items,
          );
          break;

        case txm.TxType.transfer:
          if (_fromId == null || _toId == null) {
            return _toast('Pick both accounts.');
          }
          if (_fromId == _toId) {
            return _toast('Accounts must be different.');
          }
          await svc.updateTransaction(
            _tx.id,
            type: txm.TxType.transfer,
            amount: amt,
            fromAccountId: _fromId,
            toAccountId: _toId,
            clearCategory: true,
            clearContact: true,
            items: const [],
            date: _date,
            note: noteText.isEmpty ? null : noteText,
            clearNote: noteText.isEmpty,
          );
          break;

        case txm.TxType.debt:
          if (_contact == null || _contact!.trim().isEmpty) {
            return _toast('Enter a contact name.');
          }
          if (_debtFromAccount && _fromId == null) {
            return _toast('Pick an account.');
          }
          await svc.updateTransaction(
            _tx.id,
            type: txm.TxType.debt,
            amount: amt,
            fromAccountId: _debtFromAccount ? _fromId : null,
            clearFromAccount: !_debtFromAccount,
            clearToAccount: true,
            clearCategory: true,
            contact: _contact,
            items: const [],
            date: _date,
            note: noteText.isEmpty ? null : noteText,
            clearNote: noteText.isEmpty,
          );
          break;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(e.toString());
    }
  }

  // ───────────────────── field widgets ─────────────────────

  Widget _typePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectableTypes.map((t) {
        final selected = _type == t;
        return GestureDetector(
          onTap: () => _changeType(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.orange : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppTheme.orange : AppTheme.lightGray),
            ),
            child: Text(t.label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.light : AppTheme.dark,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _amountField() {
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
                  color: AppTheme.midGray)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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

  Widget _accountPicker(
      List<Account> accounts, String? selectedId, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: accounts.map((a) {
        final selected = a.id == selectedId;
        return GestureDetector(
          onTap: () => onTap(a.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.dark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppTheme.dark : AppTheme.lightGray),
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
                Text(a.name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.light : AppTheme.dark,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _categoryPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((c) {
        final selected = _category == c;
        final color = AppTheme.categoryColors[c] ?? AppTheme.midGray;
        return GestureDetector(
          onTap: () => setState(() => _category = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : AppTheme.lightGray),
            ),
            child: Text(c,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.light : AppTheme.dark,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _date = picked);
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
              DateFormat('EEEE, MMM d, y').format(_date),
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

  Widget _noteField() {
    return TextField(
      controller: _note,
      decoration: const InputDecoration(labelText: 'Note (optional)'),
    );
  }

  Widget _contactField({String hint = 'Add contact (optional)'}) {
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
          builder: (_) => _ContactSheet(initial: _contact),
        );
        if (result != null) {
          setState(() => _contact = result.isEmpty ? null : result);
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
              _contact != null
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              color: _contact != null ? AppTheme.orange : AppTheme.midGray,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _contact ?? hint,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight:
                      _contact != null ? FontWeight.w500 : FontWeight.w400,
                  color: _contact != null ? AppTheme.dark : AppTheme.midGray,
                ),
              ),
            ),
            if (_contact != null)
              GestureDetector(
                onTap: () => setState(() => _contact = null),
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.lora(color: AppTheme.light)),
        backgroundColor: AppTheme.dark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ───────────────────── edit history ─────────────────────
class _EditHistory extends StatelessWidget {
  final String txId;
  const _EditHistory({required this.txId});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    return FutureBuilder<List<TxEditLog>>(
      future: svc.editLogsFor(txId),
      builder: (context, snap) {
        final logs = snap.data ?? const <TxEditLog>[];
        if (logs.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.lightGray),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
              leading: const Icon(Icons.history_rounded,
                  color: AppTheme.midGray, size: 20),
              title: Text(
                'Edit history',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark),
              ),
              subtitle: Text(
                '${logs.length} edit${logs.length == 1 ? '' : 's'}',
                style:
                    GoogleFonts.lora(fontSize: 12, color: AppTheme.midGray),
              ),
              children: [
                for (final log in logs) _EditEntry(log: log),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditEntry extends StatelessWidget {
  final TxEditLog log;
  const _EditEntry({required this.log});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMM d, y · h:mm a').format(log.editedAt),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.midGray,
            ),
          ),
          const SizedBox(height: 4),
          for (final c in log.changes)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.lora(fontSize: 12, color: AppTheme.dark),
                  children: [
                    TextSpan(
                      text: '${c.field}: ',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: c.before,
                      style: const TextStyle(
                        color: AppTheme.midGray,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const TextSpan(text: '  →  '),
                    TextSpan(
                      text: c.after,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.green),
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

// ───────────────────── contact sheet ─────────────────────
// A trimmed copy of the picker used on the add screen.
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
        !contacts.any((c) => c.name.toLowerCase() == _query.toLowerCase());

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                        onPressed: () =>
                            setState(() { _search.clear(); _query = ''; }),
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
                      selectedTileColor: AppTheme.orange.withAlpha(15),
                      onTap: () => Navigator.pop(context, c.name),
                    )),
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
                    onTap: () => Navigator.pop(context, _query),
                  ),
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
