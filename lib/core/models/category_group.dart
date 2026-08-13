import 'package:flutter/material.dart';
import 'category.dart';

class CategoryGroup {
  final String id;
  final String name;
  final CategoryType type;
  final IconData iconData;
  final Color color;

  CategoryGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.iconData,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'iconCode': iconData.codePoint,
      'color': color.value,
    };
  }

  factory CategoryGroup.fromJson(Map<String, dynamic> json) {
    return CategoryGroup(
      id: json['id'],
      name: json['name'],
      type: CategoryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CategoryType.expense,
      ),
      iconData: Category.getIconFromCode(json['iconCode'] as int?),
      color: Color(json['color'] as int),
    );
  }
}
