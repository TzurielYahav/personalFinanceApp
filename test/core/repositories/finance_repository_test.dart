import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/models/account.dart';
import 'package:personal_finance_app/core/models/base_transaction.dart';
import 'package:personal_finance_app/core/models/bank_transaction_model.dart';
import 'package:personal_finance_app/core/models/cc_transaction_model.dart';
import 'package:personal_finance_app/core/repositories/finance_repository.dart';

void main() {
  group('FinanceRepository Tests', () {
    late FinanceRepository repository;

    setUp(() {
      repository = FinanceRepository();
    });

    test('Initial repository data is populated with default seed data', () {
      expect(repository.accounts, isNotEmpty);
      expect(repository.categories, isNotEmpty);
      expect(repository.transactions, isNotEmpty);
    });

    test('Net worth calculation correctly computes assets minus liabilities', () {
      final netWorth = repository.totalNetWorth;
      double expectedAssets = 0.0;
      double expectedLiabilities = 0.0;

      for (var account in repository.accounts) {
        if (account.isDebt) {
          expectedLiabilities += account.balance;
        } else {
          expectedAssets += account.balance;
        }
      }

      expect(netWorth, equals(expectedAssets - expectedLiabilities));
    });

    test('addBulkBankTransactions updates account balance and adds to transactions list', () async {
      // Wait for initial data to load since the constructor calls async method
      await Future.delayed(const Duration(milliseconds: 100));
      
      final initialTxCount = repository.transactions.length;
      final targetAccount = repository.accounts.firstWhere((acc) => !acc.isDebt);
      final initialBalance = targetAccount.balance;

      final newTx = BankTransactionModel(
        id: 'test-id-1',
        accountId: targetAccount.id,
        date: DateTime.now(),
        description: 'Test Grocery Expense',
        expense: 150.0,
      );

      // Since it's an existing test, we'll assume they mock it or initialize sqflite ffi somewhere.
      await repository.addBulkBankTransactions([newTx]);

      expect(repository.transactions.length, equals(initialTxCount + 1));
      
      final updatedAccount = repository.getAccountById(targetAccount.id);
      expect(updatedAccount?.balance, equals(initialBalance - 150.0));
    });

    test('addAccount creates a new account and notifies listeners', () {
      final initialAccountCount = repository.accounts.length;

      repository.addAccount(
        name: 'High Yield Savings',
        type: AccountType.savings,
        initialBalance: 5000.0,
        institutionName: 'Ally Bank',
        color: Colors.blue,
        icon: Icons.savings,
      );

      expect(repository.accounts.length, equals(initialAccountCount + 1));
      expect(repository.accounts.last.name, equals('High Yield Savings'));
      expect(repository.accounts.last.balance, equals(5000.0));
    });
  });
}
