import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/models/bank_transaction_model.dart';
import '../../core/models/cc_transaction_model.dart';
import '../../core/models/base_transaction.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_theme.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../core/services/database_service.dart';
import '../../core/services/file_import_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _searchQuery = '';
  String _filterType = 'ALL'; // ALL, BANK, CREDIT_CARD

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
            'This will permanently delete all imported transactions. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<FinanceRepository>(context, listen: false)
                  .clearAllTransactions();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All transactions deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final dbPath = await DatabaseService.getDatabaseFilePath();
      
      final String? selectedDirectory = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Database',
        fileName: 'finance_app_backup.db',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite'],
      );

      if (selectedDirectory != null) {
        await File(dbPath).copy(selectedDirectory);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Database exported successfully:\n$selectedDirectory')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export database: $e')),
        );
      }
    }
  }

  Future<void> _importDatabase(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Database',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite'],
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        
        if (!context.mounted) return;
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Overwrite Database?'),
            content: const Text(
                'This will replace all your current data with the imported database. This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await DatabaseService.replaceDatabase(sourcePath);
                    if (context.mounted) {
                      await Provider.of<FinanceRepository>(context, listen: false).reloadAllData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Database imported successfully.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to import database: $e')),
                      );
                    }
                  }
                },
                child: const Text('Import', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import database: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<FinanceRepository>(context);
    final currencyFormatter =
        NumberFormat.currency(symbol: '₪', decimalDigits: 2);

    final uniqueCards = repo.transactions
        .whereType<CcTransactionModel>()
        .map((tx) => tx.cardDigits)
        .where((digits) => digits != null && digits.isNotEmpty)
        .toSet()
        .toList();

    final filteredTransactions = repo.transactions.where((tx) {
      String desc = '';
      if (tx is BankTransactionModel) desc = tx.description.toLowerCase();
      if (tx is CcTransactionModel) desc = tx.businessName.toLowerCase();

      final matchesQuery =
          _searchQuery.isEmpty || desc.contains(_searchQuery.toLowerCase());

      if (_filterType == 'BANK') {
        return matchesQuery && tx is BankTransactionModel;
      }

      if (_filterType.startsWith('CC_')) {
        final digits = _filterType.substring(3);
        return matchesQuery &&
            tx is CcTransactionModel &&
            tx.cardDigits == digits;
      }

      return matchesQuery;
    }).toList();

    // Sort descending by date of transaction
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Create list with monthly dividers
    final items = <dynamic>[];
    String? lastMonthYear;
    for (var tx in filteredTransactions) {
      final monthYear = DateFormat('MMMM yyyy').format(tx.date);
      if (monthYear != lastMonthYear) {
        items.add(monthYear);
        lastMonthYear = monthYear;
      }
      items.add(tx);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.accentPurple,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Transaction History',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download, color: Colors.white),
              tooltip: 'Import Database',
              onPressed: () => _importDatabase(context),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              tooltip: 'Export Database',
              onPressed: () => _exportDatabase(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Delete All Transactions',
              onPressed: () => _confirmDeleteAll(context),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.accentPurple,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search transactions by description...',
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.textSecondary),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 16.0, right: 16.0, top: 12.0, bottom: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('ALL', 'All Activity'),
                    const SizedBox(width: 8),
                    _filterChip('BANK', 'Bank Accounts'),
                    for (var digits in uniqueCards) ...[
                      const SizedBox(width: 8),
                      _filterChip('CC_$digits', 'Card *$digits'),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: AppColors.textSecondary),
                          SizedBox(height: 12),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        if (item is String) {
                          return Padding(
                            padding: const EdgeInsets.only(
                                top: 16.0, bottom: 8.0, right: 8.0),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }

                        final tx = item as BaseTransaction;
                        final account = repo.getAccountById(tx.accountId);

                        String title = 'Unknown';
                        double displayAmount = 0.0;
                        bool isExpense = false;
                        IconData catIcon = Icons.category;
                        Color catColor = AppColors.primary;
                        String? catName;

                        if (tx.appCategoryId != null) {
                          final cat = repo.getCategoryById(tx.appCategoryId!);
                          if (cat != null) {
                            catIcon = cat.iconData;
                            catColor = cat.color;
                            catName = cat.name;
                          }
                        }

                        if (tx is BankTransactionModel) {
                          title = tx.description;
                          if (tx.expense != null) {
                            displayAmount = tx.expense!;
                            isExpense = true;
                          } else if (tx.income != null) {
                            displayAmount = tx.income!;
                            isExpense = false;
                          }
                          catName ??= tx.category;
                        } else if (tx is CcTransactionModel) {
                          title = tx.businessName;
                          displayAmount = tx.amount ?? 0.0;
                          isExpense = true;
                          catName ??= tx.category;
                        }

                        Widget leadingIcon = Icon(catIcon, color: catColor);

                        String sourceText = "Unknown";
                        if (tx is BankTransactionModel) {
                          sourceText = "Bank Account";
                        } else if (tx is CcTransactionModel) {
                          sourceText =
                              tx.cardDigits ?? account?.name ?? "Credit Card";
                        }

                        String dateText =
                            DateFormat("dd/MM/yyyy").format(tx.date);
                        String subtitleText = '$dateText • $sourceText';
                        if (catName != null) {
                          subtitleText += ' • $catName';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            horizontalTitleGap: 24,
                            leading: leadingIcon,
                            title: Text(
                              title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.textPrimary),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                subtitleText,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                            trailing: Text(
                              '${isExpense ? "-" : "+"}${currencyFormatter.format(displayAmount.abs())}',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isExpense
                                    ? AppColors.expenseRed
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: PopupMenuButton<String>(
          onSelected: (value) async {
            final isBank = value == 'bank';
            final matchingAccount = repo.accounts.firstWhere(
              (acc) => isBank ? !acc.isDebt : acc.isDebt,
              orElse: () => repo.accounts.first,
            );

            final service = FileImportService();
            final newTxs = await service.importTransactions(
                context, matchingAccount.id,
                isBank: isBank);

            if (newTxs != null && newTxs.isNotEmpty) {
              if (context.mounted) {
                try {
                  int duplicates = 0;
                  if (isBank) {
                    duplicates = await repo.addBulkBankTransactions(
                        newTxs.cast<BankTransactionModel>());
                  } else {
                    duplicates = await repo.addBulkCcTransactions(
                        newTxs.cast<CcTransactionModel>());
                  }
                  if (context.mounted) {
                    int added = newTxs.length - duplicates;
                    String msg = 'Imported $added transactions successfully!';
                    if (duplicates > 0) {
                      msg += ' ($duplicates duplicates skipped)';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(
                              'Error saving to database: $e\nPlease restart the app.')),
                    );
                  }
                }
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'bank',
              child: Text('Import Bank File'),
            ),
            const PopupMenuItem(
              value: 'cc',
              child: Text('Import Credit Card File'),
            ),
          ],
          child: const FloatingActionButton(
            onPressed: null,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.upload_file, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String typeKey, String label) {
    final isSelected = _filterType == typeKey;
    return ChoiceChip(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceLight,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filterType = typeKey);
      },
    );
  }
}
