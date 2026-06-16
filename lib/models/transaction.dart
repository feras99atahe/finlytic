import 'dart:convert';

enum TxType { income, expense, transfer, debt, openingBalance }

/// A single optional line item on a transaction (receipt-style breakdown).
/// Items are independent of [Transaction.amount] — purely informational.
class TxItem {
  final String name;
  final double price;

  const TxItem({required this.name, required this.price});

  Map<String, dynamic> toMap() => {'name': name, 'price': price};

  factory TxItem.fromMap(Map<String, dynamic> m) => TxItem(
        name: (m['name'] ?? '') as String,
        price: (m['price'] as num?)?.toDouble() ?? 0,
      );
}

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
  final List<TxItem> items;       // optional receipt-style breakdown

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
    this.items = const [],
  });

  /// Used to flag the source of cash flow (Cash vs Card) for filtering.
  bool get isCard {
    // Bank-related accounts power "card" transactions.
    return false; // resolved by the service layer using account type
  }

  /// Returns a copy with selected fields replaced. Nullable fields can be
  /// explicitly cleared with the matching `clear*` flag (since passing `null`
  /// is indistinguishable from "leave unchanged").
  Transaction copyWith({
    TxType? type,
    double? amount,
    String? fromAccountId,
    String? toAccountId,
    String? category,
    String? contact,
    String? note,
    DateTime? date,
    List<TxItem>? items,
    bool clearFromAccount = false,
    bool clearToAccount = false,
    bool clearCategory = false,
    bool clearContact = false,
    bool clearNote = false,
  }) =>
      Transaction(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        fromAccountId:
            clearFromAccount ? null : (fromAccountId ?? this.fromAccountId),
        toAccountId: clearToAccount ? null : (toAccountId ?? this.toAccountId),
        category: clearCategory ? null : (category ?? this.category),
        contact: clearContact ? null : (contact ?? this.contact),
        note: clearNote ? null : (note ?? this.note),
        date: date ?? this.date,
        items: items ?? this.items,
      );

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
        'items': items.isEmpty
            ? null
            : jsonEncode(items.map((e) => e.toMap()).toList()),
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
        items: _decodeItems(m['items']),
      );

  static List<TxItem> _decodeItems(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(TxItem.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }
}
