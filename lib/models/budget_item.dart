
class BudgetItem {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;

  BudgetItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: json['amount'] as double,
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
    );
  }
}