import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();
    final banks   = svc.accounts.where((a) => a.type == AccountType.bank).toList();
    final safes   = svc.accounts.where((a) => a.type == AccountType.safe).toList();
    final wallets = svc.accounts.where((a) => a.type == AccountType.wallet).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add account',
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (banks.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.credit_card_rounded,
              label: 'Bank Accounts',
              color: AppTheme.blue,
            ),
            ...banks.map((a) => _AccountCard(account: a)),
            const SizedBox(height: 16),
          ],
          if (safes.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.lock_outline_rounded,
              label: 'Safe / Savings',
              color: AppTheme.green,
            ),
            ...safes.map((a) => _AccountCard(account: a)),
            const SizedBox(height: 16),
          ],
          if (wallets.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallets',
              color: AppTheme.orange,
            ),
            ...wallets.map((a) => _AccountCard(account: a)),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Account',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AccountFormSheet(),
    );
  }
}

// ─────────────────────────── Section header ───────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppTheme.midGray,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Account card ───────────────────────────
class _AccountCard extends StatelessWidget {
  final Account account;
  const _AccountCard({required this.account});

  Color get _accentColor {
    switch (account.type) {
      case AccountType.bank:   return AppTheme.blue;
      case AccountType.safe:   return AppTheme.green;
      case AccountType.wallet: return AppTheme.orange;
    }
  }

  IconData get _icon {
    switch (account.type) {
      case AccountType.bank:   return Icons.credit_card_rounded;
      case AccountType.safe:   return Icons.lock_outline_rounded;
      case AccountType.wallet: return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _accentColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon, color: _accentColor, size: 20),
        ),
        title: Text(
          account.name,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: AppTheme.dark),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (account.bankName != null && account.bankName!.isNotEmpty)
              Text(account.bankName!,
                  style: GoogleFonts.lora(
                      fontSize: 12, color: AppTheme.midGray)),
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    account.currency,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                  ),
                ),
                if (account.notes != null && account.notes!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        account.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lora(
                            fontSize: 11, color: AppTheme.midGray),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Money.format(account.balance),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: account.balance >= 0 ? AppTheme.dark : AppTheme.orange,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionIcon(
                  icon: Icons.edit_outlined,
                  color: AppTheme.midGray,
                  onTap: () => _showEditSheet(context, account),
                ),
                const SizedBox(width: 4),
                _ActionIcon(
                  icon: Icons.delete_outline_rounded,
                  color: AppTheme.orange,
                  onTap: () => _confirmDelete(context, account),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccountFormSheet(existing: account),
    );
  }

  void _confirmDelete(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${account.name}"?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'All transactions linked to this account will also be deleted. This cannot be undone.',
          style: GoogleFonts.lora(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<FinanceService>().deleteAccount(account.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.orange),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ─────────────────────────── Add / Edit form sheet ───────────────────────────
class _AccountFormSheet extends StatefulWidget {
  final Account? existing;
  const _AccountFormSheet({this.existing});

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  late TextEditingController _name;
  late TextEditingController _bankName;
  late TextEditingController _notes;
  late TextEditingController _currency;
  late TextEditingController _initialBalance;
  late AccountType _type;

  static const _currencies = [
    'LYD', 'USD', 'EUR', 'GBP', 'SAR', 'AED', 'EGP', 'JOD', 'KWD', 'QAR',
    'TRY', 'INR', 'PKR', 'CAD', 'AUD', 'JPY', 'CNY', 'CHF', 'SEK', 'NOK', 'DKK',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name           = TextEditingController(text: e?.name ?? '');
    _bankName       = TextEditingController(text: e?.bankName ?? '');
    _notes          = TextEditingController(text: e?.notes ?? '');
    _currency       = TextEditingController(text: e?.currency ?? 'LYD');
    _initialBalance = TextEditingController();
    _type           = e?.type ?? AccountType.bank;
  }

  @override
  void dispose() {
    _name.dispose();
    _bankName.dispose();
    _notes.dispose();
    _currency.dispose();
    _initialBalance.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            Text(
              _isEdit ? 'Edit Account' : 'New Account',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.dark),
            ),
            const SizedBox(height: 20),

            // Account type — only when creating
            if (!_isEdit) ...[
              _Label('Account type'),
              Row(
                children: AccountType.values.map((t) {
                  final sel = t == _type;
                  IconData ico;
                  switch (t) {
                    case AccountType.bank:   ico = Icons.credit_card_rounded; break;
                    case AccountType.safe:   ico = Icons.lock_outline_rounded; break;
                    case AccountType.wallet: ico = Icons.account_balance_wallet_outlined; break;
                  }
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.dark : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppTheme.dark : AppTheme.lightGray,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(ico,
                                size: 20,
                                color: sel ? AppTheme.light : AppTheme.dark),
                            const SizedBox(height: 4),
                            Text(t.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? AppTheme.light : AppTheme.dark,
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Account name
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Account name *'),
            ),
            const SizedBox(height: 16),

            // Bank name (optional)
            TextField(
              controller: _bankName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _type == AccountType.safe
                    ? 'Savings name / label (optional)'
                    : 'Bank name (optional)',
              ),
            ),
            const SizedBox(height: 16),

            // Currency
            _Label('Currency'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currencies.map((c) {
                final sel = _currency.text.toUpperCase() == c;
                return GestureDetector(
                  onTap: () => setState(() => _currency.text = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.dark : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? AppTheme.dark : AppTheme.lightGray,
                      ),
                    ),
                    child: Text(
                      c,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? AppTheme.light : AppTheme.dark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Account number, branch, etc.',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Initial balance — only when creating
            if (!_isEdit) ...[
              TextField(
                controller: _initialBalance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Initial balance (optional)',
                  hintText: '0.00',
                  prefixText: '${_currency.text.isEmpty ? 'LYD' : _currency.text}  ',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sets the opening balance for this account.',
                style: GoogleFonts.lora(fontSize: 11, color: AppTheme.midGray),
              ),
            ],
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_isEdit ? 'Save changes' : 'Create account'),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account name is required.',
              style: GoogleFonts.lora(color: AppTheme.light)),
          backgroundColor: AppTheme.dark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final svc = context.read<FinanceService>();
    final currency = _currency.text.trim().isEmpty ? 'USD' : _currency.text.trim().toUpperCase();
    final bankName = _bankName.text.trim().isEmpty ? null : _bankName.text.trim();
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();

    final initialBalance =
        double.tryParse(_initialBalance.text.trim()) ?? 0.0;

    if (_isEdit) {
      await svc.updateAccount(
        widget.existing!.id,
        name: name,
        currency: currency,
        bankName: bankName,
        notes: notes,
        clearBankName: bankName == null,
        clearNotes: notes == null,
      );
    } else {
      await svc.addAccount(
        name: name,
        type: _type,
        initialBalance: initialBalance,
        currency: currency,
        bankName: bankName,
        notes: notes,
      );
    }
    if (mounted) Navigator.pop(context);
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
