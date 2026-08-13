import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/base_transaction.dart';
import '../models/bank_transaction_model.dart';
import '../models/cc_transaction_model.dart';
import '../models/category_mapping_rule.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finance_app.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS transactions');
          await db.execute('DROP TABLE IF EXISTS bank_transactions');
          await db.execute('DROP TABLE IF EXISTS cc_transactions');
          await _createTables(db);
        } else if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE bank_transactions ADD COLUMN appCategoryId TEXT');
          await db.execute(
              'ALTER TABLE cc_transactions ADD COLUMN appCategoryId TEXT');
          await db.execute('''
            CREATE TABLE category_mapping_rules (
              id TEXT PRIMARY KEY,
              rawString TEXT NOT NULL,
              isDescription INTEGER NOT NULL,
              appCategoryId TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE bank_transactions (
        id TEXT PRIMARY KEY,
        accountId TEXT,
        date TEXT,
        description TEXT,
        category TEXT,
        appCategoryId TEXT,
        income REAL,
        expense REAL,
        balance REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE cc_transactions (
        id TEXT PRIMARY KEY,
        accountId TEXT,
        date TEXT,
        dateOfPayment TEXT,
        businessName TEXT,
        category TEXT,
        appCategoryId TEXT,
        cardDigits TEXT,
        amount REAL,
        paymentMethod TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE category_mapping_rules (
        id TEXT PRIMARY KEY,
        rawString TEXT NOT NULL,
        isDescription INTEGER NOT NULL,
        appCategoryId TEXT NOT NULL
      )
    ''');
  }

  static Future<void> insertBankTransactions(
      List<BankTransactionModel> txs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var tx in txs) {
      batch.insert(
        'bank_transactions',
        {
          'id': tx.id,
          'accountId': tx.accountId,
          'date': tx.date.toIso8601String(),
          'description': tx.description,
          'category': tx.category,
          'appCategoryId': tx.appCategoryId,
          'income': tx.income,
          'expense': tx.expense,
          'balance': tx.balance,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> insertCcTransactions(List<CcTransactionModel> txs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var tx in txs) {
      batch.insert(
        'cc_transactions',
        {
          'id': tx.id,
          'accountId': tx.accountId,
          'date': tx.date.toIso8601String(),
          'dateOfPayment': tx.dateOfPayment?.toIso8601String(),
          'businessName': tx.businessName,
          'category': tx.category,
          'appCategoryId': tx.appCategoryId,
          'cardDigits': tx.cardDigits,
          'amount': tx.amount,
          'paymentMethod': tx.paymentMethod,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<BaseTransaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> bankMaps =
        await db.query('bank_transactions');
    final List<Map<String, dynamic>> ccMaps = await db.query('cc_transactions');

    List<BaseTransaction> allTransactions = [];

    allTransactions
        .addAll(bankMaps.map((map) => BankTransactionModel.fromJson(map)));

    allTransactions
        .addAll(ccMaps.map((map) => CcTransactionModel.fromJson(map)));

    // Sort descending by date
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    return allTransactions;
  }

  static Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.execute('DELETE FROM bank_transactions');
    await db.execute('DELETE FROM cc_transactions');
  }

  static Future<List<CategoryMappingRule>> getCategoryMappingRules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('category_mapping_rules');
    return List.generate(maps.length, (i) {
      return CategoryMappingRule.fromMap(maps[i]);
    });
  }

  static Future<void> insertCategoryMappingRule(
      CategoryMappingRule rule) async {
    final db = await database;
    await db.insert(
      'category_mapping_rules',
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateTransactionAppCategory(
      String txId, String appCategoryId, bool isBank) async {
    final db = await database;
    final table = isBank ? 'bank_transactions' : 'cc_transactions';
    await db.update(
      table,
      {'appCategoryId': appCategoryId},
      where: 'id = ?',
      whereArgs: [txId],
    );
  }

  // Keep these defaults to prevent breaking the rest of the app for now
  static List<Category> get defaultCategories {
    return [
      Category(
        id: 'cat_groceries',
        name: 'Groceries',
        type: CategoryType.expense,
        iconData: Icons.shopping_cart,
        color: const Color(0xFF10B981),
        monthlyBudgetLimit: 600.0,
      ),
      Category(
        id: 'cat_dining',
        name: 'Dining & Cafes',
        type: CategoryType.expense,
        iconData: Icons.restaurant,
        color: const Color(0xFFF59E0B),
        monthlyBudgetLimit: 350.0,
      ),
      Category(
        id: 'cat_bills',
        name: 'Bills & Utilities',
        type: CategoryType.expense,
        iconData: Icons.bolt,
        color: const Color(0xFFEF4444),
        monthlyBudgetLimit: 500.0,
      ),
      Category(
        id: 'cat_transport',
        name: 'Transport & Gas',
        type: CategoryType.expense,
        iconData: Icons.directions_car,
        color: const Color(0xFF3B82F6),
        monthlyBudgetLimit: 250.0,
      ),
      Category(
        id: 'cat_shopping',
        name: 'Shopping & Tech',
        type: CategoryType.expense,
        iconData: Icons.devices,
        color: const Color(0xFF8B5CF6),
        monthlyBudgetLimit: 400.0,
      ),
      Category(
        id: 'cat_salary',
        name: 'Salary & Income',
        type: CategoryType.income,
        iconData: Icons.attach_money,
        color: const Color(0xFF10B981),
      ),
      Category(
        id: 'cat_freelance',
        name: 'Freelance & Side Gig',
        type: CategoryType.income,
        iconData: Icons.work,
        color: const Color(0xFF06B6D4),
      ),
      Category(
        id: 'cat_uncategorized',
        name: 'Uncategorized',
        type: CategoryType.expense,
        iconData: Icons.help_outline,
        color: Colors.grey,
      ),
    ];
  }

  static List<Account> get defaultAccounts {
    return [
      Account(
        id: 'acc_checking',
        name: 'Primary Checking',
        type: AccountType.checking,
        balance: 4250.80,
        currency: '\$',
        accountNumberMasked: '•••• 4821',
        institutionName: 'Chase Bank',
        themeColor: const Color(0xFF3B82F6),
        iconData: Icons.account_balance,
      ),
      Account(
        id: 'acc_credit',
        name: 'Sapphire Preferred',
        type: AccountType.creditCard,
        balance: 840.50,
        currency: '\$',
        accountNumberMasked: '•••• 9104',
        institutionName: 'Chase Card',
        themeColor: const Color(0xFF8B5CF6),
        iconData: Icons.credit_card,
      ),
      Account(
        id: 'acc_cash',
        name: 'Cash Wallet',
        type: AccountType.cash,
        balance: 185.00,
        currency: '\$',
        institutionName: 'Physical Cash',
        themeColor: const Color(0xFF10B981),
        iconData: Icons.payments,
      ),
      Account(
        id: 'acc_savings',
        name: 'High Yield Savings',
        type: AccountType.savings,
        balance: 12500.00,
        currency: '\$',
        accountNumberMasked: '•••• 1120',
        institutionName: 'Marcus Savings',
        themeColor: const Color(0xFF06B6D4),
        iconData: Icons.savings,
      ),
    ];
  }

  static List<BaseTransaction> get defaultTransactions {
    return []; // Start empty so we can see imported ones
  }
}
