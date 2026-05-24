class Contact {
  final String id;
  final String name;
  final String? phone;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}
