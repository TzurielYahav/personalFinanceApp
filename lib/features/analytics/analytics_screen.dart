import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/models/bank_transaction_model.dart';
import '../../core/models/cc_transaction_model.dart';
import '../../core/models/category.dart';
import '../../core/models/category_group.dart';
import '../../core/models/base_transaction.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _monthlyTabController;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isGroupView = false;
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _monthlyTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _monthlyTabController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
        bottom: TabBar(
          controller: _mainTabController,
          tabs: const [
            Tab(text: 'Monthly'),
            Tab(text: 'Annually'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [
          _buildMonthlyView(context),
          const Center(child: Text('Annually View (Coming Soon)')),
        ],
      ),
    );
  }

  Widget _buildMonthlyView(BuildContext context) {
    return Column(
      children: [
        // Month Selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),
        // Income / Expenses Tabs
        TabBar(
          controller: _monthlyTabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accentBlue,
          tabs: const [
            Tab(text: 'Income'),
            Tab(text: 'Expenses'),
          ],
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _monthlyTabController,
            children: [
              _buildCategoryTabContent(context, CategoryType.income),
              _buildCategoryTabContent(context, CategoryType.expense),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabContent(BuildContext context, CategoryType type) {
    final repo = Provider.of<FinanceRepository>(context);
    final currencyFormatter =
        NumberFormat.currency(symbol: '₪', decimalDigits: 2);

    final relevantCategories = repo.categories
        .where((c) => c.type == type && !c.isExcludedFromAnalytics)
        .toList();
    final Map<Category, double> categoryTotals = {
      for (var c in relevantCategories) c: 0.0
    };

    final relevantGroups = repo.groups.where((g) => g.type == type).toList();
    final Map<CategoryGroup, double> groupTotals = {
      for (var g in relevantGroups) g: 0.0
    };

    double uncatTotal = 0.0;

    final List<BaseTransaction> monthTransactions = repo.transactions
        .where((tx) =>
            tx.date.month == _selectedMonth.month &&
            tx.date.year == _selectedMonth.year)
        .toList();

    for (var tx in monthTransactions) {
      Category? cat;
      if (tx.appCategoryId != null) {
        cat = repo.getCategoryById(tx.appCategoryId!);
      } else if (tx.category != null) {
        cat = repo.categories
            .where((c) => c.name.toLowerCase() == tx.category!.toLowerCase())
            .firstOrNull;
      }

      if (cat != null && cat.isExcludedFromAnalytics) {
        continue; // Skip excluded categories entirely
      }

      double amount = 0.0;
      if (type == CategoryType.expense) {
        if (tx is BankTransactionModel && tx.expense != null)
          amount = tx.expense!;
        if (tx is CcTransactionModel && tx.amount != null) amount = tx.amount!;
      } else {
        if (tx is BankTransactionModel && tx.income != null)
          amount = tx.income!;
      }

      if (amount > 0) {
        if (cat != null && cat.type == type) {
          categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + amount;
        } else if (cat == null) {
          uncatTotal += amount;
        }
      }
    }
    final List<Category> standaloneCategories =
        relevantCategories.where((c) => c.groupId == null).toList();

    double ungroupedTotal = 0.0;
    for (var cat in categoryTotals.keys) {
      if (cat.groupId != null) {
        try {
          final group = repo.groups.firstWhere((g) => g.id == cat.groupId);
          if (groupTotals.containsKey(group)) {
            groupTotals[group] = groupTotals[group]! + categoryTotals[cat]!;
          }
        } catch (_) {
          ungroupedTotal += categoryTotals[cat]!;
        }
      }
    }
    // Any completely unrecognized transactions (uncatTotal) remain uncatTotal.

    final double totalAmount =
        categoryTotals.values.fold(0.0, (sum, val) => sum + val) + uncatTotal;

    final double totalBudget = relevantCategories.fold(
        0.0, (sum, cat) => sum + (cat.monthlyBudgetLimit ?? 500.0));

    final progress =
        totalBudget > 0 ? (totalAmount / totalBudget).clamp(0.0, 1.0) : 0.0;

    final List<PieChartSectionData> sections = [];

    if (_isGroupView) {
      groupTotals.forEach((group, amount) {
        if (amount > 0) {
          sections.add(
            PieChartSectionData(
              color: group.color,
              value: amount,
              title: '${(amount / totalAmount * 100).toStringAsFixed(1)}%',
              radius: 50.0,
              titleStyle: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          );
        }
      });
      for (var cat in standaloneCategories) {
        final amount = categoryTotals[cat] ?? 0.0;
        if (amount > 0) {
          sections.add(
            PieChartSectionData(
              color: cat.color,
              value: amount,
              title: '${(amount / totalAmount * 100).toStringAsFixed(1)}%',
              radius: 50.0,
              titleStyle: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          );
        }
      }
      final otherTotal = ungroupedTotal + uncatTotal;
      if (otherTotal > 0) {
        sections.add(
          PieChartSectionData(
            color: Colors.grey,
            value: otherTotal,
            title: '${(otherTotal / totalAmount * 100).toStringAsFixed(1)}%',
            radius: 50.0,
            titleStyle: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        );
      }
    } else {
      categoryTotals.forEach((cat, amount) {
        if (amount > 0) {
          sections.add(
            PieChartSectionData(
              color: cat.color,
              value: amount,
              title: '${(amount / totalAmount * 100).toStringAsFixed(1)}%',
              radius: 50.0,
              titleStyle: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          );
        }
      });
      if (uncatTotal > 0) {
        sections.add(
          PieChartSectionData(
            color: Colors.grey,
            value: uncatTotal,
            title: '${(uncatTotal / totalAmount * 100).toStringAsFixed(1)}%',
            radius: 50.0,
            titleStyle: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pie Chart
          if (totalAmount > 0)
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: sections,
                ),
              ),
            )
          else
            const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'No data available for this month',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Total Target Budget Bar
          Text(
            type == CategoryType.expense
                ? 'Total Expenses vs Target'
                : 'Total Income vs Target',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyFormatter.format(totalAmount),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              Text(
                currencyFormatter.format(totalBudget),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                type == CategoryType.expense
                    ? (progress > 0.9
                        ? AppColors.expenseRed
                        : AppColors.accentBlue)
                    : AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // View Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Breakdown',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Categories')),
                  ButtonSegment<bool>(value: true, label: Text('Groups')),
                ],
                selected: {_isGroupView},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isGroupView = newSelection.first;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isGroupView)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relevantGroups.length +
                  standaloneCategories.length +
                  ((uncatTotal + ungroupedTotal) > 0 ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx < relevantGroups.length) {
                  final group = relevantGroups[idx];
                  final spent = groupTotals[group] ?? 0.0;
                  final groupCategories = relevantCategories
                      .where((c) => c.groupId == group.id)
                      .toList();
                  final limit = groupCategories.fold(
                      0.0, (sum, c) => sum + (c.monthlyBudgetLimit ?? 500.0));

                  final isExpanded = _expandedGroups.contains(group.id);

                  return Column(
                    children: [
                      _buildGroupItemCard(
                        name: group.name,
                        icon: group.iconData,
                        color: group.color,
                        spent: spent,
                        limit: limit,
                        currencyFormatter: currencyFormatter,
                        isExpanded: isExpanded,
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedGroups.remove(group.id);
                            } else {
                              _expandedGroups.add(group.id);
                            }
                          });
                        },
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: Column(
                            children: groupCategories.map((cat) {
                              final catSpent = categoryTotals[cat] ?? 0.0;
                              final catLimit = cat.monthlyBudgetLimit ?? 500.0;
                              return _buildListItemCard(
                                name: cat.name,
                                icon: cat.iconData,
                                color: cat.color,
                                spent: catSpent,
                                limit: catLimit,
                                currencyFormatter: currencyFormatter,
                                onTap: () => _showCategoryTransactions(context,
                                    cat, monthTransactions, currencyFormatter),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  );
                } else if (idx <
                    relevantGroups.length + standaloneCategories.length) {
                  final cat = standaloneCategories[idx - relevantGroups.length];
                  final spent = categoryTotals[cat] ?? 0.0;
                  final limit = cat.monthlyBudgetLimit ?? 500.0;
                  return _buildListItemCard(
                    name: cat.name,
                    icon: cat.iconData,
                    color: cat.color,
                    spent: spent,
                    limit: limit,
                    currencyFormatter: currencyFormatter,
                    onTap: () => _showCategoryTransactions(
                        context, cat, monthTransactions, currencyFormatter),
                  );
                } else {
                  return _buildListItemCard(
                    name: 'Uncategorized',
                    icon: Icons.category,
                    color: Colors.grey,
                    spent: uncatTotal + ungroupedTotal,
                    limit: 0.0,
                    currencyFormatter: currencyFormatter,
                    onTap: () {},
                  );
                }
              },
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relevantCategories.length + (uncatTotal > 0 ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx == relevantCategories.length) {
                  return _buildListItemCard(
                    name: 'Uncategorized',
                    icon: Icons.category,
                    color: Colors.grey,
                    spent: uncatTotal,
                    limit: 0.0,
                    currencyFormatter: currencyFormatter,
                    onTap: () {},
                  );
                }

                final cat = relevantCategories[idx];
                final spent = categoryTotals[cat] ?? 0.0;
                final limit = cat.monthlyBudgetLimit ?? 500.0;
                return _buildListItemCard(
                  name: cat.name,
                  icon: cat.iconData,
                  color: cat.color,
                  spent: spent,
                  limit: limit,
                  currencyFormatter: currencyFormatter,
                  onTap: () => _showCategoryTransactions(
                      context, cat, monthTransactions, currencyFormatter),
                );
              },
            ),
        ],
      ),
    );
  }

  // _showGroupDetails removed as per user request (inline expansion used instead)

  void _showCategoryTransactions(BuildContext context, Category category,
      List<BaseTransaction> monthTransactions, NumberFormat formatter) {
    final categoryTxs = monthTransactions
        .where((tx) =>
            tx.appCategoryId == category.id ||
            (tx.appCategoryId == null &&
                tx.category?.toLowerCase() == category.name.toLowerCase()))
        .toList();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${category.name} Transactions',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Target: ${formatter.format(category.monthlyBudgetLimit ?? 500.0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Target Budget',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) {
                                final controller = TextEditingController(
                                    text: category.monthlyBudgetLimit
                                            ?.toString() ??
                                        '500.0');
                                return AlertDialog(
                                  title:
                                      Text('Edit Budget for ${category.name}'),
                                  content: TextField(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Monthly Budget Limit',
                                      prefixText: '₪ ',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final val =
                                            double.tryParse(controller.text);
                                        if (val != null) {
                                          final repo =
                                              Provider.of<FinanceRepository>(
                                                  context,
                                                  listen: false);
                                          repo.updateCategory(Category(
                                            id: category.id,
                                            name: category.name,
                                            type: category.type,
                                            iconData: category.iconData,
                                            color: category.color,
                                            monthlyBudgetLimit: val,
                                            groupId: category.groupId,
                                          ));
                                        }
                                        Navigator.pop(ctx); // Close dialog
                                        Navigator.pop(
                                            context); // Close bottom sheet to refresh view
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (categoryTxs.isEmpty)
                  const Text('No transactions in this category for this month.')
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: categoryTxs.length,
                      itemBuilder: (ctx, idx) {
                        final tx = categoryTxs[idx];
                        double amount = 0;
                        String title = '';
                        if (tx is BankTransactionModel) {
                          amount = tx.expense ?? tx.income ?? 0;
                          title = tx.description;
                        } else if (tx is CcTransactionModel) {
                          amount = tx.amount ?? 0;
                          title = tx.businessName;
                        }

                        return ListTile(
                          title: Text(title),
                          subtitle:
                              Text(DateFormat('MMM d, yyyy').format(tx.date)),
                          trailing: Text(formatter.format(amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        });
  }

  Widget _buildGroupItemCard({
    required String name,
    required IconData icon,
    required Color color,
    required double spent,
    required double limit,
    required NumberFormat currencyFormatter,
    required VoidCallback onTap,
    required bool isExpanded,
  }) {
    final progress =
        limit > 0 ? (spent / limit).clamp(0.0, 1.0) : (spent > 0 ? 1.0 : 0.0);
    final isOverBudget = progress > 0.9;
    final progressColor = isOverBudget ? AppColors.expenseRed : color;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                        strokeWidth: 3,
                      ),
                    ),
                    Icon(icon, color: color, size: 22),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFormatter.format(spent)} / ${limit > 0 ? currencyFormatter.format(limit) : 'No limit'}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItemCard({
    required String name,
    required IconData icon,
    required Color color,
    required double spent,
    required double limit,
    required NumberFormat currencyFormatter,
    required VoidCallback onTap,
  }) {
    final progress =
        limit > 0 ? (spent / limit).clamp(0.0, 1.0) : (spent > 0 ? 1.0 : 0.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '${currencyFormatter.format(spent)} / ${limit > 0 ? currencyFormatter.format(limit) : 'No limit'}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.9 ? AppColors.expenseRed : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
