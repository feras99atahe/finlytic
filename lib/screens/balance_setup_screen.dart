import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class BalanceSetupScreen extends StatefulWidget {
  const BalanceSetupScreen({super.key});

  @override
  State<BalanceSetupScreen> createState() => _BalanceSetupScreenState();
}

class _BalanceSetupScreenState extends State<BalanceSetupScreen> {
  final Map<String, TextEditingController> _controllers = {};
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.orange,
              onPrimary: AppTheme.light,
              surface: AppTheme.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveBalances() async {
    final svc = context.read<FinanceService>();
    bool hasValues = false;

    for (var entry in _controllers.entries) {
      final amount = double.tryParse(entry.value.text) ?? 0;
      if (amount > 0) {
        hasValues = true;
        await svc.addOpeningBalance(
          accountId: entry.key,
          amount: amount,
          date: _selectedDate,
        );
      }
    }

    if (!hasValues) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter at least one balance',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            backgroundColor: AppTheme.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening balances saved successfully',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FinanceService>();

    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(
        title: Text('Balance Setup',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.dark,
            )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Set Opening Balances',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the starting balance for each account. This will be recorded as an opening balance transaction.',
              style: GoogleFonts.lora(
                fontSize: 14,
                color: AppTheme.midGray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Date Selector
            Text(
              'OPENING DATE',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppTheme.midGray,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightGray),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.orange),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dark,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: AppTheme.midGray),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Account Balances
            Text(
              'ACCOUNT BALANCES',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppTheme.midGray,
              ),
            ),
            const SizedBox(height: 16),

            ...svc.accounts.map((account) {
              if (!_controllers.containsKey(account.id)) {
                _controllers[account.id] = TextEditingController();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _AccountBalanceField(
                  account: account,
                  controller: _controllers[account.id]!,
                ),
              );
            }),

            const SizedBox(height: 24),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.blueTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppTheme.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Opening balances are one-time entries that set your starting point. You can leave any account at zero if it starts empty.',
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        color: AppTheme.dark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveBalances,
                child: const Text('Save Opening Balances'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountBalanceField extends StatelessWidget {
  final Account account;
  final TextEditingController controller;

  const _AccountBalanceField({
    required this.account,
    required this.controller,
  });

  IconData _getAccountIcon() {
    switch (account.type) {
      case AccountType.bank:
        return Icons.account_balance_rounded;
      case AccountType.safe:
        return Icons.savings_rounded;
      case AccountType.wallet:
        return Icons.wallet_rounded;
    }
  }

  Color _getAccountColor() {
    switch (account.type) {
      case AccountType.bank:
        return AppTheme.blue;
      case AccountType.safe:
        return AppTheme.green;
      case AccountType.wallet:
        return AppTheme.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getAccountColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getAccountIcon(),
                    color: _getAccountColor(), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.dark,
                    ),
                  ),
                  Text(
                    account.type.name.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppTheme.midGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Opening Balance',
              prefixText: '\$ ',
              hintText: '0.00',
            ),
          ),
        ],
      ),
    );
  }
}
