import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/bank_transaction_model.dart';
import '../../core/models/cc_transaction_model.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<FinanceRepository>(context);
    final currencyFormatter =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final filteredTransactions = repo.transactions.where((tx) {
      String desc = '';
      if (tx is BankTransactionModel) desc = tx.description.toLowerCase();
      if (tx is CcTransactionModel) desc = tx.businessName.toLowerCase();

      final matchesQuery =
          _searchQuery.isEmpty || desc.contains(_searchQuery.toLowerCase());

      if (_filterType == 'BANK')
        return matchesQuery && tx is BankTransactionModel;
      if (_filterType == 'CREDIT_CARD')
        return matchesQuery && tx is CcTransactionModel;

      return matchesQuery;
    }).toList();

    // Sort descending by date of transaction
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            tooltip: 'Delete All Transactions',
            onPressed: () => _confirmDeleteAll(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file, color: AppColors.primary),
            onSelected: (value) async {
              final isBank = value == 'bank';
              // Ideally we'd show an account picker here, but for now we default
              // to the first account of the matching type, or let the user choose.
              // To keep it simple, we'll pick a matching account.
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
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search transactions by description...',
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.textSecondary),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('ALL', 'All Activity'),
                      const SizedBox(width: 8),
                      _filterChip('BANK', 'Bank Accounts'),
                      const SizedBox(width: 8),
                      _filterChip('CREDIT_CARD', 'Credit Cards'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredTransactions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
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
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = filteredTransactions[index];
                      final account = repo.getAccountById(tx.accountId);

                      String title = 'Unknown';
                      String subtitleExtra = '';
                      double displayAmount = 0.0;
                      bool isExpense = false;

                      if (tx is BankTransactionModel) {
                        title = tx.description;
                        if (tx.expense != null) {
                          displayAmount = tx.expense!;
                          isExpense = true;
                        } else if (tx.income != null) {
                          displayAmount = tx.income!;
                          isExpense = false;
                        }
                        if (tx.appCategoryId != null) {
                          final cat = repo.getCategoryById(tx.appCategoryId!);
                          subtitleExtra = ' • ${cat?.name ?? tx.category}';
                        } else if (tx.category != null) {
                          subtitleExtra = ' • ${tx.category}';
                        }
                      } else if (tx is CcTransactionModel) {
                        title = tx.businessName;
                        displayAmount = tx.amount ?? 0.0;
                        isExpense = true; // Assume CC amounts are expenses
                        if (tx.appCategoryId != null) {
                          final cat = repo.getCategoryById(tx.appCategoryId!);
                          subtitleExtra = ' • ${cat?.name ?? tx.category}';
                        } else if (tx.category != null) {
                          subtitleExtra = ' • ${tx.category}';
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                account?.themeColor.withOpacity(0.2) ??
                                    AppColors.surfaceLight,
                            child: Icon(
                                account?.iconData ?? Icons.account_balance,
                                color:
                                    account?.themeColor ?? AppColors.primary),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${DateFormat("MMM dd, yyyy").format(tx.date)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              Text(
                                'Source: ${account?.name ?? "Unknown"}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              if (subtitleExtra.isNotEmpty)
                                Text(
                                  'Category:${subtitleExtra.replaceFirst(' • ', ' ')}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isExpense ? "-" : "+"}${currencyFormatter.format(displayAmount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isExpense
                                      ? AppColors.expenseRed
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isExpense
                                          ? AppColors.expenseRed
                                          : AppColors.primary)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isExpense ? 'EXPENSE' : 'INCOME',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isExpense
                                        ? AppColors.expenseRed
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String typeKey, String label) {
    final isSelected = _filterType == typeKey;
    return ChoiceChip(
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
