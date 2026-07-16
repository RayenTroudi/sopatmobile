/// Lightweight project entry from GET /api/mobile/projects.
class Project {
  final String id;
  final String reference;
  final String name;
  final String currency;
  final double? approvedBudget;
  final double spent;
  final double? percentSpent;

  const Project({
    required this.id,
    required this.reference,
    required this.name,
    required this.currency,
    required this.approvedBudget,
    required this.spent,
    required this.percentSpent,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        reference: json['reference'] as String? ?? '',
        name: json['name'] as String? ?? '',
        currency: json['currency'] as String? ?? 'TND',
        approvedBudget: (json['approvedBudget'] as num?)?.toDouble(),
        spent: (json['spent'] as num?)?.toDouble() ?? 0,
        percentSpent: (json['percentSpent'] as num?)?.toDouble(),
      );

  String get label => '$reference — $name';
}

/// Budget snapshot returned after creating an expense.
class BudgetInfo {
  final double? approvedBudget;
  final double spent;
  final double? percentSpent;

  const BudgetInfo({
    required this.approvedBudget,
    required this.spent,
    required this.percentSpent,
  });

  factory BudgetInfo.fromJson(Map<String, dynamic> json) => BudgetInfo(
        approvedBudget: (json['approvedBudget'] as num?)?.toDouble(),
        spent: (json['spent'] as num?)?.toDouble() ?? 0,
        percentSpent: (json['percentSpent'] as num?)?.toDouble(),
      );
}

/// Result of POST /api/mobile/expenses.
class ExpenseCreated {
  final String id;
  final String reference;
  final BudgetInfo? budget;

  const ExpenseCreated({
    required this.id,
    required this.reference,
    required this.budget,
  });

  factory ExpenseCreated.fromJson(Map<String, dynamic> json) => ExpenseCreated(
        id: json['id'] as String,
        reference: json['reference'] as String,
        budget: json['budget'] == null
            ? null
            : BudgetInfo.fromJson(json['budget'] as Map<String, dynamic>),
      );
}
