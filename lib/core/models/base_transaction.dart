abstract class BaseTransaction {
  final String id;
  final String accountId;
  final DateTime date;

  BaseTransaction({
    required this.id,
    required this.accountId,
    required this.date,
  });

  String? get category;
  String? get appCategoryId;
}
