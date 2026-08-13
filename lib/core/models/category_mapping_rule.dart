class CategoryMappingRule {
  final String id;
  final String rawString;
  final bool isDescription;
  final String appCategoryId;
  final bool? isExpense;

  CategoryMappingRule({
    required this.id,
    required this.rawString,
    required this.isDescription,
    required this.appCategoryId,
    this.isExpense,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawString': rawString,
      'isDescription': isDescription ? 1 : 0,
      'appCategoryId': appCategoryId,
      'isExpense': isExpense == null ? null : (isExpense! ? 1 : 0),
    };
  }

  factory CategoryMappingRule.fromMap(Map<String, dynamic> map) {
    return CategoryMappingRule(
      id: map['id'],
      rawString: map['rawString'],
      isDescription: map['isDescription'] == 1,
      appCategoryId: map['appCategoryId'],
      isExpense: map['isExpense'] == null ? null : (map['isExpense'] == 1),
    );
  }
}
