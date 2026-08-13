import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/base_transaction.dart';
import '../models/bank_transaction_model.dart';
import '../models/cc_transaction_model.dart';
import '../models/category_mapping_rule.dart';
import '../models/category_group.dart';
import '../services/database_service.dart';

class FinanceRepository extends ChangeNotifier {
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<CategoryGroup> _groups = [];
  List<BaseTransaction> _transactions = [];
  List<CategoryMappingRule> _mappingRules = [];

  final _uuid = const Uuid();

  FinanceRepository() {
    _loadInitialData();
  }

  Future<void> reloadAllData() async {
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _accounts = List.from(DatabaseService.defaultAccounts);

    final savedGroups = await DatabaseService.getAllCategoryGroups();
    if (savedGroups.isEmpty) {
      _groups = List.from(DatabaseService.defaultCategoryGroups);
      for (var group in _groups) {
        await DatabaseService.insertCategoryGroup(group);
      }
    } else {
      _groups = savedGroups;
    }

    final savedCategories = await DatabaseService.getAllCategories();
    if (savedCategories.isEmpty) {
      _categories = List.from(DatabaseService.defaultCategories);
      for (var cat in _categories) {
        await DatabaseService.insertCategory(cat);
      }
    } else {
      _categories = savedCategories;
    }

    _mappingRules = await DatabaseService.getCategoryMappingRules();

    final savedTxs = await DatabaseService.getAllTransactions();
    if (savedTxs.isEmpty) {
      _transactions = List.from(DatabaseService.defaultTransactions);
    } else {
      _transactions = savedTxs;
      // Clean up orphaned categories if they exist (e.g. from previously deleted custom categories that weren't cleared in the db)
      for (int i = 0; i < _transactions.length; i++) {
        if (_transactions[i].appCategoryId != null &&
            getCategoryById(_transactions[i].appCategoryId!) == null) {
          final tx = _transactions[i];
          if (tx is BankTransactionModel) {
            _transactions[i] = tx.copyWithAppCategory(null);
            DatabaseService.updateTransactionAppCategory(tx.id, null, true);
          } else if (tx is CcTransactionModel) {
            _transactions[i] = tx.copyWithAppCategory(null);
            DatabaseService.updateTransactionAppCategory(tx.id, null, false);
          }
        }
      }
    }

    notifyListeners();
  }

  // Getters
  List<Account> get accounts => List.unmodifiable(_accounts);
  List<Category> get categories => List.unmodifiable(_categories);
  List<CategoryGroup> get groups => List.unmodifiable(_groups);
  List<BaseTransaction> get transactions => List.unmodifiable(_transactions);
  List<CategoryMappingRule> get mappingRules =>
      List.unmodifiable(_mappingRules);

  List<BaseTransaction> get uncategorizedTransactions =>
      _transactions.where((t) => t.appCategoryId == null).toList();

  // Financial Calculations
  double get totalNetWorth {
    double totalAssets = 0.0;
    double totalLiabilities = 0.0;

    for (var acc in _accounts) {
      if (acc.isDebt) {
        totalLiabilities += acc.balance;
      } else {
        totalAssets += acc.balance;
      }
    }
    return totalAssets - totalLiabilities;
  }

  double get totalCashBalance {
    return _accounts
        .where((acc) =>
            acc.type == AccountType.cash || acc.type == AccountType.checking)
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get totalCreditDebt {
    return _accounts
        .where((acc) => acc.isDebt)
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get monthlyIncome {
    final now = DateTime.now();
    double sum = 0.0;
    for (var tx in _transactions) {
      if (tx.date.month == now.month && tx.date.year == now.year) {
        if (tx is BankTransactionModel && tx.income != null) {
          sum += tx.income!;
        }
      }
    }
    return sum;
  }

  double get monthlyExpenses {
    final now = DateTime.now();
    double sum = 0.0;
    for (var tx in _transactions) {
      if (tx.date.month == now.month && tx.date.year == now.year) {
        if (tx is BankTransactionModel && tx.expense != null) {
          sum += tx.expense!;
        } else if (tx is CcTransactionModel && tx.amount != null) {
          sum += tx.amount!;
        }
      }
    }
    return sum;
  }

  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (_) {
      return null;
    }
  }

  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((acc) => acc.id == id);
    } catch (_) {
      return null;
    }
  }

  // We won't support manual adding here yet, or we'll update it later if needed.
  // The user requested to remove the add button anyway in a previous step.

  void addAccount({
    required String name,
    required AccountType type,
    required double initialBalance,
    required String institutionName,
    required Color color,
    required IconData icon,
    String? accountNumberMasked,
  }) {
    final newAccount = Account(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: initialBalance,
      institutionName: institutionName,
      themeColor: color,
      iconData: icon,
      accountNumberMasked: accountNumberMasked,
    );

    _accounts.add(newAccount);
    notifyListeners();
  }

  void addCategory(Category category) {
    _categories.add(category);
    DatabaseService.insertCategory(category);
    notifyListeners();
  }

  void updateCategory(Category updatedCategory) {
    final index = _categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index != -1) {
      _categories[index] = updatedCategory;
      DatabaseService.insertCategory(updatedCategory);
      notifyListeners();
    }
  }

  void addCategoryGroup(CategoryGroup group) {
    _groups.add(group);
    DatabaseService.insertCategoryGroup(group);
    notifyListeners();
  }

  void updateCategoryGroup(CategoryGroup updatedGroup) {
    final index = _groups.indexWhere((g) => g.id == updatedGroup.id);
    if (index != -1) {
      _groups[index] = updatedGroup;
      DatabaseService.insertCategoryGroup(updatedGroup);
      notifyListeners();
    }
  }

  void deleteCategoryGroup(String id) {
    _groups.removeWhere((g) => g.id == id);
    DatabaseService.deleteCategoryGroup(id);

    for (int i = 0; i < _categories.length; i++) {
      if (_categories[i].groupId == id) {
        final cat = _categories[i];
        final updatedCat = Category(
          id: cat.id,
          name: cat.name,
          type: cat.type,
          iconData: cat.iconData,
          color: cat.color,
          monthlyBudgetLimit: cat.monthlyBudgetLimit,
          groupId: null,
        );
        _categories[i] = updatedCat;
        DatabaseService.insertCategory(updatedCat);
      }
    }
    notifyListeners();
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    DatabaseService.deleteCategory(id);

    // Un-map any rules using this category
    _mappingRules.removeWhere((rule) => rule.appCategoryId == id);
    DatabaseService.deleteCategoryMappingRuleByCategoryId(id);

    // Remove from existing transactions
    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i].appCategoryId == id) {
        if (_transactions[i] is BankTransactionModel) {
          _transactions[i] = (_transactions[i] as BankTransactionModel)
              .copyWithAppCategory(null);
          DatabaseService.updateTransactionAppCategory(
              _transactions[i].id, null, true);
        } else if (_transactions[i] is CcTransactionModel) {
          _transactions[i] = (_transactions[i] as CcTransactionModel)
              .copyWithAppCategory(null);
          DatabaseService.updateTransactionAppCategory(
              _transactions[i].id, null, false);
        }
      }
    }
    notifyListeners();
  }

  Future<void> clearAllCategoryMappings() async {
    _mappingRules.clear();
    DatabaseService.deleteAllCategoryMappingRules();

    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i].appCategoryId != null) {
        if (_transactions[i] is BankTransactionModel) {
          _transactions[i] = (_transactions[i] as BankTransactionModel)
              .copyWithAppCategory(null);
          DatabaseService.updateTransactionAppCategory(
              _transactions[i].id, null, true);
        } else if (_transactions[i] is CcTransactionModel) {
          _transactions[i] = (_transactions[i] as CcTransactionModel)
              .copyWithAppCategory(null);
          DatabaseService.updateTransactionAppCategory(
              _transactions[i].id, null, false);
        }
      }
    }
    notifyListeners();
  }

  Future<int> addBulkBankTransactions(
      List<BankTransactionModel> newTransactions) async {
    final mappedTransactions = newTransactions.map((tx) {
      String? mappedId;
      for (var rule in _mappingRules) {
        if (rule.isDescription) {
          if (tx.description.trim().toLowerCase() ==
              rule.rawString.toLowerCase()) {
            mappedId = rule.appCategoryId;
            break;
          }
        } else {
          if (tx.category?.trim().toLowerCase() ==
              rule.rawString.toLowerCase()) {
            mappedId = rule.appCategoryId;
            break;
          }
        }
      }
      if (mappedId != null) {
        return tx.copyWithAppCategory(mappedId);
      }
      return tx;
    }).toList();

    await DatabaseService.insertBankTransactions(mappedTransactions);

    int duplicates = 0;
    for (var tx in mappedTransactions) {
      // Prevent duplicates in memory if the transaction already exists
      if (_transactions.any((t) => t.id == tx.id)) {
        duplicates++;
        continue;
      }

      _transactions.insert(0, tx);

      final accountIndex =
          _accounts.indexWhere((acc) => acc.id == tx.accountId);
      if (accountIndex != -1) {
        final account = _accounts[accountIndex];
        double updatedBalance = tx.balance ??
            account
                .balance; // If file has balance, we can override or just calculate

        if (tx.income != null) updatedBalance += tx.income!;
        if (tx.expense != null) updatedBalance -= tx.expense!;

        // Overwrite if the file provided a balance
        if (tx.balance != null) updatedBalance = tx.balance!;

        _accounts[accountIndex] = account.copyWith(balance: updatedBalance);
      }
    }

    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    return duplicates;
  }

  Future<int> addBulkCcTransactions(
      List<CcTransactionModel> newTransactions) async {
    final mappedTransactions = newTransactions.map((tx) {
      String? mappedId;
      for (var rule in _mappingRules) {
        if (rule.isDescription) {
          if (tx.businessName.trim().toLowerCase() ==
              rule.rawString.toLowerCase()) {
            mappedId = rule.appCategoryId;
            break;
          }
        } else {
          if (tx.category?.trim().toLowerCase() ==
              rule.rawString.toLowerCase()) {
            mappedId = rule.appCategoryId;
            break;
          }
        }
      }
      if (mappedId != null) {
        return tx.copyWithAppCategory(mappedId);
      }
      return tx;
    }).toList();

    await DatabaseService.insertCcTransactions(mappedTransactions);

    int duplicates = 0;
    for (var tx in mappedTransactions) {
      // Prevent duplicates in memory if the transaction already exists
      if (_transactions.any((t) => t.id == tx.id)) {
        duplicates++;
        continue;
      }

      _transactions.insert(0, tx);

      final accountIndex =
          _accounts.indexWhere((acc) => acc.id == tx.accountId);
      if (accountIndex != -1) {
        final account = _accounts[accountIndex];
        double updatedBalance = account.balance;

        if (tx.amount != null) {
          updatedBalance += tx.amount!; // debt increases
        }

        _accounts[accountIndex] = account.copyWith(balance: updatedBalance);
      }
    }

    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    return duplicates;
  }

  Future<void> clearAllTransactions() async {
    await DatabaseService.deleteAllTransactions();
    _transactions.clear();
    notifyListeners();
  }

  Future<void> assignCategoryToUnknown(
      String rawString, bool isDescription, String appCategoryId) async {
    final rule = CategoryMappingRule(
      id: _uuid.v4(),
      rawString: rawString,
      isDescription: isDescription,
      appCategoryId: appCategoryId,
    );

    await DatabaseService.insertCategoryMappingRule(rule);
    _mappingRules.add(rule);

    for (int i = 0; i < _transactions.length; i++) {
      final tx = _transactions[i];
      bool match = false;
      if (isDescription) {
        String desc = '';
        if (tx is BankTransactionModel) desc = tx.description;
        if (tx is CcTransactionModel) desc = tx.businessName;
        if (desc.trim().toLowerCase() == rawString.toLowerCase()) match = true;
      } else {
        if (tx.category?.trim().toLowerCase() == rawString.toLowerCase())
          match = true;
      }

      if (match && tx.appCategoryId == null) {
        if (tx is BankTransactionModel) {
          _transactions[i] = tx.copyWithAppCategory(appCategoryId);
          await DatabaseService.updateTransactionAppCategory(
              tx.id, appCategoryId, true);
        } else if (tx is CcTransactionModel) {
          _transactions[i] = tx.copyWithAppCategory(appCategoryId);
          await DatabaseService.updateTransactionAppCategory(
              tx.id, appCategoryId, false);
        }
      }
    }
    notifyListeners();
  }
}
