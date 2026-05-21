enum AccountType { bank, safe, wallet }

extension AccountTypeX on AccountType {
  String get label {
    switch (this) {
      case AccountType.bank:   return 'Bank';
      case AccountType.safe:   return 'Safe';
      case AccountType.wallet: return 'Wallet';
    }
  }

  String get description {
    switch (this) {
      case AccountType.bank:   return 'Card payments & direct income';
      case AccountType.safe:   return 'Cash storage';
      case AccountType.wallet: return 'Pocket money (from Safe only)';
    }
  }

  static AccountType fromString(String s) =>
      AccountType.values.firstWhere((e) => e.name == s, orElse: () => AccountType.bank);
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.createdAt,
  });

  Account copyWith({String? name, double? balance}) => Account(
        id: id,
        name: name ?? this.name,
        type: type,
        balance: balance ?? this.balance,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'balance': balance,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        type: AccountTypeX.fromString(m['type'] as String),
        balance: (m['balance'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}
