enum DebtDirection { iOwe, owesMe }

extension DebtDirectionX on DebtDirection {
  String get label {
    switch (this) {
      case DebtDirection.iOwe:   return 'I Owe';
      case DebtDirection.owesMe: return 'Owes Me';
    }
  }

  static DebtDirection fromString(String s) =>
      DebtDirection.values.firstWhere((e) => e.name == s,
          orElse: () => DebtDirection.iOwe);
}

class Debt {
  final String id;
  final DebtDirection direction;
  final double amount;
  final String contact;
  final String? description;
  final DateTime createdAt;
  final DateTime? dueDate;

  Debt({
    required this.id,
    required this.direction,
    required this.amount,
    required this.contact,
    this.description,
    required this.createdAt,
    this.dueDate,
  });

  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now());

  Debt copyWith({
    double? amount,
    String? contact,
    String? description,
    DateTime? dueDate,
  }) =>
      Debt(
        id: id,
        direction: direction,
        amount: amount ?? this.amount,
        contact: contact ?? this.contact,
        description: description ?? this.description,
        createdAt: createdAt,
        dueDate: dueDate ?? this.dueDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'direction': direction.name,
        'amount': amount,
        'contact': contact,
        'description': description,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'dueDate': dueDate?.millisecondsSinceEpoch,
      };

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
        id: m['id'] as String,
        direction: DebtDirectionX.fromString(m['direction'] as String),
        amount: (m['amount'] as num).toDouble(),
        contact: m['contact'] as String,
        description: m['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        dueDate: m['dueDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['dueDate'] as int),
      );
}
