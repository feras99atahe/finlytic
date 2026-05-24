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
    switch (tx.type) {
      case txm.TxType.transfer:
        return 'Transfer';
      case txm.TxType.debt:
        return tx.category ?? 'Debt';
      case txm.TxType.openingBalance:
        return 'Opening Balance';
      case txm.TxType.income:
        return 'Income';
      case txm.TxType.expense:
        return tx.category ?? 'Expense';
    }
  }

  /// Returns the "from → to" flow label shown below the title.
  String get _flowLabel {
    switch (tx.type) {
      case txm.TxType.income:
      case txm.TxType.openingBalance:
        return '→ ${toAccountName ?? '—'}';
      case txm.TxType.expense:
        final parts = <String>[];
        if (fromAccountName != null) parts.add(fromAccountName!);
        if (tx.contact != null && tx.contact!.isNotEmpty) {
          parts.add(tx.contact!);
        }
        return parts.isNotEmpty ? '${parts.first} →' : '—';
      case txm.TxType.debt:
        final from = fromAccountName ?? '—';
        final to = tx.contact ?? '—';
        return '$from → $to';
      case txm.TxType.transfer:
        final from = fromAccountName ?? '—';
        final to = toAccountName ?? '—';
        return '$from → $to';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(tx.date);
    final hasNote = tx.note != null && tx.note!.isNotEmpty;

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
                // Title row
                Text(
                  _title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 3),
                // Flow: from → to
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _flowLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _color,
                        ),
                      ),
                    ),
                    if (tx.contact != null &&
                        tx.contact!.isNotEmpty &&
                        tx.type == txm.TxType.income) ...[
                      const SizedBox(width: 5),
                      Text(
                        'from ${tx.contact}',
                        style: GoogleFonts.lora(
                            fontSize: 11, color: AppTheme.midGray),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // Date · note
                Text(
                  hasNote ? '$dateStr · ${tx.note}' : dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lora(
                      fontSize: 11, color: AppTheme.midGray),
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
