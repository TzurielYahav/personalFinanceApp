import 'package:flutter/material.dart';

enum AccountType {
  checking,
  savings,
  creditCard,
  cash,
  investment,
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final String currency;
  final String? accountNumberMasked;
  final String institutionName;
  final Color themeColor;
  final IconData iconData;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = '\$',
    this.accountNumberMasked,
    required this.institutionName,
    required this.themeColor,
    required this.iconData,
  });

  bool get isDebt => type == AccountType.creditCard;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    String? currency,
    String? accountNumberMasked,
    String? institutionName,
    Color? themeColor,
    IconData? iconData,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
      institutionName: institutionName ?? this.institutionName,
      themeColor: themeColor ?? this.themeColor,
      iconData: iconData ?? this.iconData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'balance': balance,
      'currency': currency,
      'accountNumberMasked': accountNumberMasked,
      'institutionName': institutionName,
      'themeColor': themeColor.value,
      'iconCode': iconData.codePoint,
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      type: AccountType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AccountType.checking,
      ),
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] ?? '\$',
      accountNumberMasked: json['accountNumberMasked'],
      institutionName: json['institutionName'] ?? '',
      themeColor: Color(json['themeColor'] as int),
      iconData: _getIconFromCode(json['iconCode'] as int?),
    );
  }

  static IconData _getIconFromCode(int? code) {
    if (code == null) return Icons.account_balance;
    return _iconMap[code] ?? Icons.account_balance;
  }

  static final Map<int, IconData> _iconMap = {
    Icons.account_balance.codePoint: Icons.account_balance,
    Icons.credit_card.codePoint: Icons.credit_card,
    Icons.payments.codePoint: Icons.payments,
    Icons.savings.codePoint: Icons.savings,
    Icons.account_balance_wallet.codePoint: Icons.account_balance_wallet,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.wallet.codePoint: Icons.wallet,
  };
}
