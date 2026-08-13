import 'package:flutter/material.dart';

enum CategoryType {
  expense,
  income,
}

class Category {
  final String id;
  final String name;
  final CategoryType type;
  final IconData iconData;
  final Color color;
  final double? monthlyBudgetLimit;
  final String? groupId;
  final bool isExcludedFromAnalytics;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.iconData,
    required this.color,
    this.monthlyBudgetLimit,
    this.groupId,
    this.isExcludedFromAnalytics = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'iconCode': iconData.codePoint,
      'color': color.value,
      'monthlyBudgetLimit': monthlyBudgetLimit,
      'groupId': groupId,
      'isExcludedFromAnalytics': isExcludedFromAnalytics ? 1 : 0,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      type: CategoryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CategoryType.expense,
      ),
      iconData: getIconFromCode(json['iconCode'] as int?),
      color: Color(json['color'] as int),
      monthlyBudgetLimit: json['monthlyBudgetLimit'] != null
          ? (json['monthlyBudgetLimit'] as num).toDouble()
          : null,
      groupId: json['groupId'],
      isExcludedFromAnalytics: json['isExcludedFromAnalytics'] == 1,
    );
  }

  static IconData getIconFromCode(int? code) {
    if (code == null) return Icons.category;
    return _iconMap[code] ?? Icons.category;
  }

  static final Map<int, IconData> _iconMap = {
    Icons.shopping_cart.codePoint: Icons.shopping_cart,
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.bolt.codePoint: Icons.bolt,
    Icons.directions_car.codePoint: Icons.directions_car,
    Icons.devices.codePoint: Icons.devices,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.work.codePoint: Icons.work,
    Icons.category.codePoint: Icons.category,
    Icons.receipt.codePoint: Icons.receipt,
    Icons.movie.codePoint: Icons.movie,
    Icons.fitness_center.codePoint: Icons.fitness_center,
    Icons.medical_services.codePoint: Icons.medical_services,
    Icons.flight.codePoint: Icons.flight,
    Icons.school.codePoint: Icons.school,
    Icons.home.codePoint: Icons.home,
  };
}
