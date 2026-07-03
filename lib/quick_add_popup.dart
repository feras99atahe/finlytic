import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/account.dart';
import 'models/transaction.dart' as txm;
import 'services/finance_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';
import 'widgets/item_editor.dart';

/// Runs the home-screen widget's quick-add popup. Invoked from the
/// `quickAddMain` entrypoint in main.dart (the entrypoint must live in the
/// root library so the engine can resolve it).
void runQuickAddPopup(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final type = args.isNotEmpty ? args.first : 'expense';
  runApp(QuickAddApp(type: type));
}

class QuickAddApp extends StatelessWidget {
  final String type;
  const QuickAddApp({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: AppTheme.lightTheme,
      home: QuickAddPopup(type: type),
    );
  }
}

class QuickAddPopup extends StatefulWidget {
  final String type; // income | expense | transfer
  const QuickAddPopup({super.key, required this.type});

  @override
  State<QuickAddPopup> createState() => _QuickAddPopupState();
}

class _QuickAddPopupState extends State<QuickAddPopup> {
  final _svc = FinanceService();
  final _amount = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _accId; // from (expense/transfer) or to (income)
  String? _toId; // transfer destination
  String _category = 'Food';
  List<txm.TxItem> _items = const [];

  bool get _isIncome => widget.type == 'income';
  bool get _isExpense => widget.type == 'expense';
  bool get _isTransfer => widget.type == 'transfer';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _svc.load();
    final accs = _svc.accounts;
    setState(() {
      _accId = accs.isNotEmpty ? accs.first.id : null;
      _toId = accs.length > 1 ? accs[1].id : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _close() => SystemNavigator.pop();

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0 || _accId == null) {
      _toast('Enter an amount.');
      return;
    }
    if (_isTransfer && (_toId == null || _toId == _accId)) {
      _toast('Pick two different accounts.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isIncome) {
        await _svc.addIncome(toAccountId: _accId!, amount: amt, items: _items);
      } else if (_isExpense) {
        await _svc.addExpense(
            fromAccountId: _accId!,
            amount: amt,
            category: _category,
            items: _items);
      } else {
        await _svc.transfer(
            fromAccountId: _accId!, toAccountId: _toId!, amount: amt);
      }
      await WidgetService.updateBalance(_svc.totalBalance);
      _close();
    } catch (e) {
      setState(() => _saving = false);
      _toast(e.toString());
    }
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

  ({String title, Color color}) get _heading {
    if (_isIncome) return (title: 'Quick income', color: AppTheme.green);
    if (_isTransfer) return (title: 'Quick transfer', color: AppTheme.blue);
    return (title: 'Quick expense', color: AppTheme.orange);
  }

  @override
  Widget build(BuildContext context) {
    final h = _heading;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: _close, // tap the scrim to dismiss
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // swallow taps on the card
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: AppTheme.light,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.orange)),
                        )
                      : _card(h),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(({String title, Color color}) h) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: h.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(h.title,
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: _close,
                icon: const Icon(Icons.close_rounded, color: AppTheme.midGray),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.lightGray),
            ),
            child: Row(
              children: [
                Text('\$',
                    style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.midGray)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dark),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lightGray),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account picker
          _label(_isIncome ? 'To account' : _isTransfer ? 'From' : 'Pay from'),
          _accountChips(_svc.accounts, _accId, (id) {
            setState(() {
              _accId = id;
              if (_isTransfer && _toId == id) _toId = null;
            });
          }),

          if (_isTransfer) ...[
            const SizedBox(height: 14),
            _label('To'),
            _accountChips(
              _svc.accounts.where((a) => a.id != _accId).toList(),
              _toId,
              (id) => setState(() => _toId = id),
            ),
          ],

          if (_isExpense) ...[
            const SizedBox(height: 14),
            _label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _svc.categories.map((c) {
                final sel = _category == c;
                final col = AppTheme.colorForCategory(c);
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? col : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: sel ? col : AppTheme.lightGray),
                    ),
                    child: Text(c,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: sel ? AppTheme.light : AppTheme.dark)),
                  ),
                );
              }).toList(),
            ),
          ],

          if (!_isTransfer) ...[
            const SizedBox(height: 18),
            ItemListEditor(
              initial: _items,
              onChanged: (items) => _items = items,
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: h.color),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Save',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(),
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: AppTheme.midGray)),
      );

  Widget _accountChips(
      List<Account> accounts, String? selectedId, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: accounts.map((a) {
        final sel = a.id == selectedId;
        return GestureDetector(
          onTap: () => onTap(a.id),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppTheme.dark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: sel ? AppTheme.dark : AppTheme.lightGray),
            ),
            child: Text(a.name,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppTheme.light : AppTheme.dark)),
          ),
        );
      }).toList(),
    );
  }
}
