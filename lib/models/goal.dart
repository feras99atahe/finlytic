enum GoalTerm { shortTerm, mediumTerm, longTerm }

extension GoalTermX on GoalTerm {
  String get label {
    switch (this) {
      case GoalTerm.shortTerm:  return 'Short-term';
      case GoalTerm.mediumTerm: return 'Medium-term';
      case GoalTerm.longTerm:   return 'Long-term';
    }
  }

  /// Recommended % of monthly savings to allocate.
  double get defaultAllocationPct {
    switch (this) {
      case GoalTerm.shortTerm:  return 1.0;  // 100% — finish fast
      case GoalTerm.mediumTerm: return 0.5;
      case GoalTerm.longTerm:   return 0.25;
    }
  }

  static GoalTerm fromString(String s) =>
      GoalTerm.values.firstWhere((e) => e.name == s, orElse: () => GoalTerm.shortTerm);
}

class Goal {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final GoalTerm term;
  final double allocationPct;   // % of monthly savings allocated
  final DateTime createdAt;
  final DateTime? targetDate;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.term,
    required this.allocationPct,
    required this.createdAt,
    this.targetDate,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  /// Estimated months to complete based on a monthly savings figure.
  /// Returns null when monthly savings is non-positive (goal stalled).
  int? estimatedMonthsLeft(double avgMonthlySavings) {
    if (avgMonthlySavings <= 0) return null;
    final allocated = avgMonthlySavings * allocationPct;
    if (allocated <= 0) return null;
    return (remaining / allocated).ceil();
  }

  Goal copyWith({
    String? name,
    double? targetAmount,
    double? savedAmount,
    GoalTerm? term,
    double? allocationPct,
    DateTime? targetDate,
  }) =>
      Goal(
        id: id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        term: term ?? this.term,
        allocationPct: allocationPct ?? this.allocationPct,
        createdAt: createdAt,
        targetDate: targetDate ?? this.targetDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'term': term.name,
        'allocationPct': allocationPct,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'targetDate': targetDate?.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as String,
        name: m['name'] as String,
        targetAmount: (m['targetAmount'] as num).toDouble(),
        savedAmount: (m['savedAmount'] as num).toDouble(),
        term: GoalTermX.fromString(m['term'] as String),
        allocationPct: (m['allocationPct'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        targetDate: m['targetDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['targetDate'] as int),
      );
}
