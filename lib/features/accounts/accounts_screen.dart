import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/account.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_theme.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<FinanceRepository>(context);
    final formatter = NumberFormat.currency(symbol: '₪', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Accounts & Cards'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: repo.accounts.length,
        itemBuilder: (context, index) {
          final acc = repo.accounts[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: acc.themeColor.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: acc.themeColor.withOpacity(0.2),
                          child: Icon(acc.iconData, color: acc.themeColor),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              acc.institutionName,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: acc.themeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getAccountTypeLabel(acc.type),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: acc.themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acc.isDebt
                              ? 'CURRENT DEBT / BALANCE'
                              : 'AVAILABLE BALANCE',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatter.format(acc.balance),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: acc.isDebt
                                ? AppColors.expenseRed
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (acc.accountNumberMasked != null)
                      Text(
                        acc.accountNumberMasked!,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.5),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.creditCard:
        return 'CREDIT CARD';
      case AccountType.checking:
      case AccountType.savings:
      case AccountType.cash:
      case AccountType.investment:
      default:
        return 'BANK ACCOUNT';
    }
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final instController = TextEditingController();
    final balanceController = TextEditingController();
    AccountType selectedType = AccountType.checking;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Add Account / Card',
                  style: TextStyle(color: AppColors.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'Account Name (e.g. Sapphire Card)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instController,
                      decoration: const InputDecoration(
                          labelText: 'Bank / Provider Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AccountType>(
                      value: selectedType,
                      decoration:
                          const InputDecoration(labelText: 'Account Type'),
                      dropdownColor: AppColors.surfaceLight,
                      items: const [
                        DropdownMenuItem(
                          value: AccountType.checking,
                          child: Text('Bank Account'),
                        ),
                        DropdownMenuItem(
                          value: AccountType.creditCard,
                          child: Text('Credit Card'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Initial Balance / Debt'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Add Account',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final inst = instController.text.trim();
                    final balance =
                        double.tryParse(balanceController.text) ?? 0.0;

                    if (name.isNotEmpty) {
                      Provider.of<FinanceRepository>(context, listen: false)
                          .addAccount(
                        name: name,
                        type: selectedType,
                        initialBalance: balance,
                        institutionName: inst.isEmpty ? 'Personal' : inst,
                        color: selectedType == AccountType.creditCard
                            ? AppColors.accentPurple
                            : AppColors.accentBlue,
                        icon: selectedType == AccountType.creditCard
                            ? Icons.credit_card
                            : Icons.account_balance,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
