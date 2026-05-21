import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as txm;
import '../theme/app_theme.dart';
import '../utils/money.dart';

class TransactionTile extends StatelessWidget {
  final txm.Transaction tx;
  final String? fromAccountName;
  final String? toAccountName;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.tx,
    this.fromAccountName,
    this.toAccountName,
    this.onDelete,
  });

  IconData get _icon {
    switch (tx.type) {
      case txm.TxType.income:         return Icons.arrow_downward_rounded;
      case txm.TxType.openingBalance: return Icons.flag_outlined;
      case txm.TxType.expense:        return Icons.arrow_upward_rounded;
      case txm.TxType.debt:           return Icons.handshake_outlined;
      case txm.TxType.transfer:       return Icons.swap_horiz_rounded;
    }
  }

  Color get _color {
    switch (tx.type) {
      case txm.TxType.income:
      case txm.TxType.openingBalance:
        return AppTheme.green;
      case txm.TxType.expense:
      case txm.TxType.debt:
        return AppTheme.orange;
      case txm.TxType.transfer:
        return AppTheme.blue;
    }
  }

  Color get _tint {
    switch (tx.type) {
      case txm.TxType.income:
      case txm.TxType.openingBalance:
        return AppTheme.greenTint;
      case txm.TxType.expense:
      case txm.TxType.debt:
        return AppTheme.orangeTint;
      case txm.TxType.transfer:
        return AppTheme.blueTint;
    }
  }

  String get _signed {
    switch (tx.type) {
      case txm.TxType.income:
      case txm.TxType.openingBalance:
        return '+${Money.format(tx.amount)}';
      case txm.TxType.expense:
      case txm.TxType.debt:
        return '−${Money.format(tx.amount)}';
      case txm.TxType.transfer:
        return Money.format(tx.amount);
    }
  }

  String get _title {
    if (tx.type == txm.TxType.transfer) {
      return '${fromAccountName ?? 'From'} → ${toAccountName ?? 'To'}';
    }
    if (tx.type == txm.TxType.debt) {
      return 'Debt · ${tx.contact ?? 'Unknown'}';
    }
    if (tx.type == txm.TxType.openingBalance) {
      return 'Opening · ${toAccountName ?? ''}';
    }
    if (tx.type == txm.TxType.income) {
      return 'Income · ${toAccountName ?? ''}';
    }
    return tx.category ?? 'Expense';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM d').format(tx.date)}'
                  '${tx.note != null && tx.note!.isNotEmpty ? ' · ${tx.note}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lora(
                      fontSize: 12, color: AppTheme.midGray),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _signed,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: AppTheme.midGray),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
