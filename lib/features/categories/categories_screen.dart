import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/models/base_transaction.dart';
import '../../core/models/bank_transaction_model.dart';
import '../../core/models/cc_transaction_model.dart';
import '../../core/models/category.dart';
import 'package:uuid/uuid.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          actions: [
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Clear All Mappings',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all mappings?'),
                    content: const Text(
                        'This will un-map all categorized transactions. This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Provider.of<FinanceRepository>(context, listen: false)
                              .clearAllCategoryMappings();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('All mappings cleared.')));
                        },
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Uncategorized'),
              Tab(text: 'App Categories'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UncategorizedTab(),
            _AppCategoriesTab(),
          ],
        ),
      ),
    );
  }
}

class _UncategorizedTab extends StatelessWidget {
  const _UncategorizedTab();

  void _showMappingDialog(BuildContext context, FinanceRepository repo,
      String rawString, bool isDescription) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Map "$rawString"'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: repo.categories.length,
              itemBuilder: (context, index) {
                final cat = repo.categories[index];
                return ListTile(
                  leading: Icon(cat.iconData, color: cat.color),
                  title: Text(cat.name),
                  onTap: () {
                    repo.assignCategoryToUnknown(
                        rawString, isDescription, cat.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Mapped to ${cat.name}!')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceRepository>(
      builder: (context, repo, child) {
        final txs = repo.uncategorizedTransactions;

        if (txs.isEmpty) {
          return const Center(
            child: Text('All transactions are categorized! 🎉'),
          );
        }

        // To avoid showing 100 identical raw strings, we can group them,
        // but the user said "for each row... added to a list".
        // Grouping them by raw string is better UX, but let's just list them
        // and when one is mapped, all matching disappear automatically.

        return ListView.builder(
          itemCount: txs.length,
          itemBuilder: (context, index) {
            final tx = txs[index];
            String rawCategory = tx.category ?? '';
            String desc = '';
            double amount = 0;

            if (tx is BankTransactionModel) {
              desc = tx.description;
              amount = tx.expense ?? tx.income ?? 0;
            } else if (tx is CcTransactionModel) {
              desc = tx.businessName;
              amount = tx.amount ?? 0;
            }

            bool isDescription = rawCategory.trim().isEmpty;
            String rawString = isDescription ? desc : rawCategory;

            final account =
                repo.accounts.where((a) => a.id == tx.accountId).firstOrNull;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(rawString,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isDescription) Text('Description: $desc'),
                    Text('Amount: \$${amount.toStringAsFixed(2)}'),
                    Text('Source: ${account?.name ?? 'Unknown'}'),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showMappingDialog(
                      context, repo, rawString, isDescription),
                  child: const Text('Map Category'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppCategoriesTab extends StatelessWidget {
  const _AppCategoriesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceRepository>(
      builder: (context, repo, child) {
        return Scaffold(
          body: ListView.builder(
            itemCount: repo.categories.length,
            itemBuilder: (context, index) {
              final cat = repo.categories[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cat.color.withValues(alpha: 0.2),
                  child: Icon(cat.iconData, color: cat.color),
                ),
                title: Text(cat.name),
                subtitle: Text(cat.type.name.toUpperCase()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) =>
                              _CategoryDialog(repo: repo, category: cat),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Category?'),
                            content: Text(
                                'Are you sure you want to delete ${cat.name}?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  repo.deleteCategory(cat.id);
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => _CategoryDialog(repo: repo),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final Category? category;
  final FinanceRepository repo;

  const _CategoryDialog({this.category, required this.repo});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late TextEditingController _nameController;
  late CategoryType _type;
  late IconData _iconData;
  late Color _color;

  final List<IconData> _iconChoices = [
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.bolt,
    Icons.directions_car,
    Icons.devices,
    Icons.attach_money,
    Icons.work,
    Icons.category,
    Icons.receipt,
    Icons.movie,
    Icons.fitness_center,
    Icons.medical_services,
    Icons.flight,
    Icons.school,
    Icons.home,
  ];

  final List<Color> _colorChoices = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _type = widget.category?.type ?? CategoryType.expense;
    _iconData = widget.category?.iconData ?? Icons.category;
    _color = widget.category?.color ?? Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'New Category' : 'Edit Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CategoryType>(
              value: _type,
              items: CategoryType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.name.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _type = val!),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 16),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _iconChoices
                  .map((i) => ChoiceChip(
                        showCheckmark: false,
                        label: Icon(i,
                            color:
                                _iconData == i ? Colors.white : Colors.black),
                        selectedColor: Theme.of(context).primaryColor,
                        selected: _iconData == i,
                        onSelected: (sel) {
                          if (sel) setState(() => _iconData = i);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorChoices
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _color == c
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            if (widget.category == null) {
              widget.repo.addCategory(Category(
                id: const Uuid().v4(),
                name: _nameController.text.trim(),
                type: _type,
                iconData: _iconData,
                color: _color,
              ));
            } else {
              widget.repo.updateCategory(Category(
                id: widget.category!.id,
                name: _nameController.text.trim(),
                type: _type,
                iconData: _iconData,
                color: _color,
                monthlyBudgetLimit: widget.category!.monthlyBudgetLimit,
              ));
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
