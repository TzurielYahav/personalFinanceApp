import 'base_transaction.dart';

class CcTransactionModel extends BaseTransaction {
  final DateTime? dateOfPayment;
  final String businessName;
  final String? category;
  @override
  final String? appCategoryId;
  final String? cardDigits;
  final double? amount;
  final String? paymentMethod;

  CcTransactionModel({
    required super.id,
    required super.accountId,
    required super.date,
    this.dateOfPayment,
    required this.businessName,
    this.category,
    this.appCategoryId,
    this.cardDigits,
    this.amount,
    this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'date': date.toIso8601String(),
      'dateOfPayment': dateOfPayment?.toIso8601String(),
      'businessName': businessName,
      'category': category,
      'appCategoryId': appCategoryId,
      'cardDigits': cardDigits,
      'amount': amount,
      'paymentMethod': paymentMethod,
    };
  }

  factory CcTransactionModel.fromJson(Map<String, dynamic> json) {
    return CcTransactionModel(
      id: json['id'],
      accountId: json['accountId'],
      date: DateTime.parse(json['date']),
      dateOfPayment: json['dateOfPayment'] != null
          ? DateTime.parse(json['dateOfPayment'])
          : null,
      businessName: json['businessName'],
      category: json['category'],
      appCategoryId: json['appCategoryId'],
      cardDigits: json['cardDigits'],
      amount:
          json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      paymentMethod: json['paymentMethod'],
    );
  }

  CcTransactionModel copyWithAppCategory(String? newAppCategoryId) {
    return CcTransactionModel(
      id: id,
      accountId: accountId,
      date: date,
      dateOfPayment: dateOfPayment,
      businessName: businessName,
      category: category,
      appCategoryId: newAppCategoryId,
      cardDigits: cardDigits,
      amount: amount,
      paymentMethod: paymentMethod,
    );
  }
}
