import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/account.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;
  const AccountCard({super.key, required this.account, this.onTap});

  IconData get _icon {
    switch (account.type) {
      case AccountType.bank:   return Icons.credit_card_rounded;
      case AccountType.safe:   return Icons.lock_outline_rounded;
      case AccountType.wallet: return Icons.account_balance_wallet_outlined;
    }
  }

  Color get _accent {
    switch (account.type) {
      case AccountType.bank:   return AppTheme.blue;
      case AccountType.safe:   return AppTheme.green;
      case AccountType.wallet: return AppTheme.orange;
    }
  }

  Color get _tint {
    switch (account.type) {
      case AccountType.bank:   return AppTheme.blueTint;
      case AccountType.safe:   return AppTheme.greenTint;
      case AccountType.wallet: return AppTheme.orangeTint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
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
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: _accent, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    account.type.label.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppTheme.dark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(account.name,
                style: GoogleFonts.lora(
                  fontSize: 13,
                  color: AppTheme.midGray,
                  fontStyle: FontStyle.italic,
                )),
            const SizedBox(height: 4),
            Text(
              Money.format(account.balance),
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
