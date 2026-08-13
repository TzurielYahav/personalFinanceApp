class CategoryMappingRule {
  final String id;
  final String rawString;
  final bool isDescription;
  final String appCategoryId;

  CategoryMappingRule({
    required this.id,
    required this.rawString,
    required this.isDescription,
    required this.appCategoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawString': rawString,
      'isDescription': isDescription ? 1 : 0,
      'appCategoryId': appCategoryId,
    };
  }

  factory CategoryMappingRule.fromMap(Map<String, dynamic> map) {
    return CategoryMappingRule(
      id: map['id'],
      rawString: map['rawString'],
      isDescription: map['isDescription'] == 1,
      appCategoryId: map['appCategoryId'],
    );
  }
}
