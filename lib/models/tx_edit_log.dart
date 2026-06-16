import 'dart:convert';

/// A single before→after change to one field of a transaction.
class TxFieldChange {
  final String field;
  final String before;
  final String after;

  const TxFieldChange({
    required this.field,
    required this.before,
    required this.after,
  });

  Map<String, dynamic> toMap() =>
      {'field': field, 'before': before, 'after': after};

  factory TxFieldChange.fromMap(Map<String, dynamic> m) => TxFieldChange(
        field: (m['field'] ?? '') as String,
        before: (m['before'] ?? '') as String,
        after: (m['after'] ?? '') as String,
      );
}

/// An audit-log entry recording one edit to a [Transaction].
/// Each save that actually changes a field appends one of these.
class TxEditLog {
  final String id;
  final String txId;
  final DateTime editedAt;
  final List<TxFieldChange> changes;

  const TxEditLog({
    required this.id,
    required this.txId,
    required this.editedAt,
    required this.changes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'txId': txId,
        'editedAt': editedAt.millisecondsSinceEpoch,
        'changes': jsonEncode(changes.map((c) => c.toMap()).toList()),
      };

  factory TxEditLog.fromMap(Map<String, dynamic> m) => TxEditLog(
        id: m['id'] as String,
        txId: m['txId'] as String,
        editedAt: DateTime.fromMillisecondsSinceEpoch(m['editedAt'] as int),
        changes: _decodeChanges(m['changes']),
      );

  static List<TxFieldChange> _decodeChanges(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(TxFieldChange.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }
}
