enum TxType { income, expense, transfer, debt, openingBalance }

extension TxTypeX on TxType {
  String get label {
    switch (this) {
      case TxType.income:        return 'Income';
      case TxType.expense:       return 'Expense';
      case TxType.transfer:      return 'Transfer';
      case TxType.debt:          return 'Debt';
      case TxType.openingBalance:return 'Opening Balance';
    }
  }

  static TxType fromString(String s) =>
      TxType.values.firstWhere((e) => e.name == s, orElse: () => TxType.expense);
}

class Transaction {
  final String id;
  final TxType type;
  final double amount;
  final String? fromAccountId;   // null for income
  final String? toAccountId;     // null for expense
  final String? category;        // expense/debt category
  final String? contact;         // for debt
  final String? note;
  final DateTime date;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.category,
    this.contact,
    this.note,
    required this.date,
  });

  /// Used to flag the source of cash flow (Cash vs Card) for filtering.
  bool get isCard {
    // Bank-related accounts power "card" transactions.
    return false; // resolved by the service layer using account type
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'category': category,
        'contact': contact,
        'note': note,
        'date': date.millisecondsSinceEpoch,
      };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as String,
        type: TxTypeX.fromString(m['type'] as String),
        amount: (m['amount'] as num).toDouble(),
        fromAccountId: m['fromAccountId'] as String?,
        toAccountId: m['toAccountId'] as String?,
        category: m['category'] as String?,
        contact: m['contact'] as String?,
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}
