import 'base_transaction.dart';

class BankTransactionModel extends BaseTransaction {
  final String description;
  final String? category;
  @override
  final String? appCategoryId;
  final double? income;
  final double? expense;
  final double? balance;

  BankTransactionModel({
    required super.id,
    required super.accountId,
    required super.date,
    required this.description,
    this.category,
    this.appCategoryId,
    this.income,
    this.expense,
    this.balance,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'date': date.toIso8601String(),
      'description': description,
      'category': category,
      'appCategoryId': appCategoryId,
      'income': income,
      'expense': expense,
      'balance': balance,
    };
  }

  factory BankTransactionModel.fromJson(Map<String, dynamic> json) {
    return BankTransactionModel(
      id: json['id'],
      accountId: json['accountId'],
      date: DateTime.parse(json['date']),
      description: json['description'],
      category: json['category'],
      appCategoryId: json['appCategoryId'],
      income:
          json['income'] != null ? (json['income'] as num).toDouble() : null,
      expense:
          json['expense'] != null ? (json['expense'] as num).toDouble() : null,
      balance:
          json['balance'] != null ? (json['balance'] as num).toDouble() : null,
    );
  }

  BankTransactionModel copyWithAppCategory(String? newAppCategoryId) {
    return BankTransactionModel(
      id: id,
      accountId: accountId,
      date: date,
      description: description,
      category: category,
      appCategoryId: newAppCategoryId,
      income: income,
      expense: expense,
      balance: balance,
    );
  }
}
