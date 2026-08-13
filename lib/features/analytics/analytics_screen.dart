import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
  int _selectedYear = DateTime.now().year;
  bool _isGroupView = false;
  final Set<String> _expandedGroups = {};
  int _touchedPieIndex = -1;

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

  void _previousYear() {
    setState(() {
      _selectedYear--;
    });
  }

  void _nextYear() {
    setState(() {
      _selectedYear++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.accentPurple,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Financial Analytics',
              style: TextStyle(color: Colors.white)),
          bottom: TabBar(
            controller: _mainTabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
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
            _buildAnnuallyView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyView(BuildContext context) {
    return Column(
      children: [
        // Month Selector
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              _previousMonth();
            } else if (details.primaryVelocity! < 0) {
              _nextMonth();
            }
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _nextMonth,
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
                  onPressed: _previousMonth,
                ),
              ],
            ),
          ),
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
        if (tx is BankTransactionModel && tx.expense != null) {
          amount = tx.expense!;
        } else if (tx is CcTransactionModel && tx.amount != null && tx.amount! >= 0) {
          amount = tx.amount!;
        }
      } else {
        if (tx is BankTransactionModel && tx.income != null) {
          amount = tx.income!;
        } else if (tx is CcTransactionModel && tx.amount != null && tx.amount! < 0) {
          amount = -(tx.amount!);
        }
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

    final activeCategories = relevantCategories.where((c) => (categoryTotals[c] ?? 0.0) > 0).toList();
    final activeStandaloneCategories = activeCategories.where((c) => c.groupId == null).toList();
    final activeGroups = relevantGroups.where((g) => (groupTotals[g] ?? 0.0) > 0).toList();

    final double totalAmount =
        categoryTotals.values.fold(0.0, (sum, val) => sum + val) + uncatTotal;

    final double totalBudget = relevantCategories.fold(
        0.0, (sum, cat) => sum + (cat.monthlyBudgetLimit ?? 500.0));

    final progress =
        totalBudget > 0 ? (totalAmount / totalBudget).clamp(0.0, 1.0) : 0.0;

    Widget buildBadge(IconData icon, Color color, double percentage) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          Text('${percentage.round()}%',
              style: const TextStyle(
                  fontSize: 12.0,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }

    final List<PieChartSectionData> sections = [];
    const double normalRadius = 24.0;
    const double touchedRadius = 34.0;
    const double badgeOffset = 2.3;

    int sectionIndex = 0;
    String touchedCategoryName = '';
    double touchedCategoryAmount = 0.0;

    if (_isGroupView) {
      groupTotals.forEach((group, amount) {
        if (amount > 0) {
          final isTouched = sectionIndex == _touchedPieIndex;
          if (isTouched) {
            touchedCategoryName = group.name;
            touchedCategoryAmount = amount;
          }
          sections.add(
            PieChartSectionData(
              color: group.color,
              value: amount,
              showTitle: false,
              radius: isTouched ? touchedRadius : normalRadius,
              badgeWidget: buildBadge(
                  group.iconData, group.color, amount / totalAmount * 100),
              badgePositionPercentageOffset: badgeOffset,
            ),
          );
          sectionIndex++;
        }
      });
      for (var cat in standaloneCategories) {
        final amount = categoryTotals[cat] ?? 0.0;
        if (amount > 0) {
          final isTouched = sectionIndex == _touchedPieIndex;
          if (isTouched) {
            touchedCategoryName = cat.name;
            touchedCategoryAmount = amount;
          }
          sections.add(
            PieChartSectionData(
              color: cat.color,
              value: amount,
              showTitle: false,
              radius: isTouched ? touchedRadius : normalRadius,
              badgeWidget: buildBadge(
                  cat.iconData, cat.color, amount / totalAmount * 100),
              badgePositionPercentageOffset: badgeOffset,
            ),
          );
          sectionIndex++;
        }
      }
      final otherTotal = ungroupedTotal + uncatTotal;
      if (otherTotal > 0) {
        final isTouched = sectionIndex == _touchedPieIndex;
        if (isTouched) {
            touchedCategoryName = 'Uncategorized';
            touchedCategoryAmount = otherTotal;
        }
        sections.add(
          PieChartSectionData(
            color: Colors.grey,
            value: otherTotal,
            showTitle: false,
            radius: isTouched ? touchedRadius : normalRadius,
            badgeWidget: buildBadge(
                Icons.category, Colors.grey, otherTotal / totalAmount * 100),
            badgePositionPercentageOffset: badgeOffset,
          ),
        );
        sectionIndex++;
      }
    } else {
      categoryTotals.forEach((cat, amount) {
        if (amount > 0) {
          final isTouched = sectionIndex == _touchedPieIndex;
          if (isTouched) {
            touchedCategoryName = cat.name;
            touchedCategoryAmount = amount;
          }
          sections.add(
            PieChartSectionData(
              color: cat.color,
              value: amount,
              showTitle: false,
              radius: isTouched ? touchedRadius : normalRadius,
              badgeWidget: buildBadge(
                  cat.iconData, cat.color, amount / totalAmount * 100),
              badgePositionPercentageOffset: badgeOffset,
            ),
          );
          sectionIndex++;
        }
      });
      if (uncatTotal > 0) {
        final isTouched = sectionIndex == _touchedPieIndex;
        if (isTouched) {
            touchedCategoryName = 'Uncategorized';
            touchedCategoryAmount = uncatTotal;
        }
        sections.add(
          PieChartSectionData(
            color: Colors.grey,
            value: uncatTotal,
            showTitle: false,
            radius: isTouched ? touchedRadius : normalRadius,
            badgeWidget: buildBadge(
                Icons.category, Colors.grey, uncatTotal / totalAmount * 100),
            badgePositionPercentageOffset: badgeOffset,
          ),
        );
        sectionIndex++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            type == CategoryType.income ? 'Income' : 'Expenses',
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          // Pie Chart
          if (totalAmount > 0)
            SizedBox(
              height: 340,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex =
                                pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 6,
                      centerSpaceRadius: 110,
                      sections: sections,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _touchedPieIndex == -1
                            ? (type == CategoryType.income
                                ? 'Total Income'
                                : 'Total Expenses')
                            : touchedCategoryName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(_touchedPieIndex == -1
                            ? totalAmount
                            : touchedCategoryAmount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
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
          _buildGradientProgressBar(
            progress,
            type == CategoryType.expense
                ? (progress > 0.9 ? AppColors.expenseRed : AppColors.accentBlue)
                : AppColors.primary,
            height: 12,
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
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary;
                      }
                      return Colors.transparent;
                    },
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return AppColors.primary;
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isGroupView)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeGroups.length +
                  activeStandaloneCategories.length +
                  ((uncatTotal + ungroupedTotal) > 0 ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx < activeGroups.length) {
                  final group = activeGroups[idx];
                  final spent = groupTotals[group] ?? 0.0;
                  final groupCategories = activeCategories
                      .where((c) => c.groupId == group.id)
                      .toList();
                  final limit = groupCategories.fold(
                      0.0, (sum, c) => sum + (c.monthlyBudgetLimit ?? 500.0));

                  final isExpanded = _expandedGroups.contains(group.id);

                  return Column(
                    children: [
                      _buildGroupItemCard(
                        type: type,
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
                                type: type,
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
                    activeGroups.length + activeStandaloneCategories.length) {
                  final cat = activeStandaloneCategories[idx - activeGroups.length];
                  final spent = categoryTotals[cat] ?? 0.0;
                  final limit = cat.monthlyBudgetLimit ?? 500.0;
                  return _buildListItemCard(
                    type: type,
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
                    type: type,
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
              itemCount: activeCategories.length + (uncatTotal > 0 ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx == activeCategories.length) {
                  return _buildListItemCard(
                    type: type,
                    name: 'Uncategorized',
                    icon: Icons.category,
                    color: Colors.grey,
                    spent: uncatTotal,
                    limit: 0.0,
                    currencyFormatter: currencyFormatter,
                    onTap: () {},
                  );
                }

                final cat = activeCategories[idx];
                final spent = categoryTotals[cat] ?? 0.0;
                final limit = cat.monthlyBudgetLimit ?? 500.0;
                return _buildListItemCard(
                  type: type,
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
    required CategoryType type,
    required String name,
    required IconData icon,
    required Color color,
    required double spent,
    required double limit,
    required NumberFormat currencyFormatter,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final progress =
        limit > 0 ? (spent / limit).clamp(0.0, 1.0) : (spent > 0 ? 1.0 : 0.0);
    final isFull = progress > 0.9;
    final progressColor = type == CategoryType.expense
        ? (isFull ? AppColors.expenseRed : color)
        : (isFull ? AppColors.primary : color);

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
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 16),
                    ),
                  ),
                  Text(
                    '${currencyFormatter.format(spent)} / ${limit > 0 ? currencyFormatter.format(limit) : 'No limit'}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildGradientProgressBar(progress, progressColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItemCard({
    required CategoryType type,
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
              const SizedBox(height: 12),
              _buildGradientProgressBar(
                  progress,
                  type == CategoryType.expense
                      ? (progress > 0.9 ? AppColors.expenseRed : color)
                      : (progress > 0.9 ? AppColors.primary : color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientProgressBar(double progress, Color color,
      {double height = 8}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.75),
                    color,
                  ],
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnuallyView(BuildContext context) {
    final repo = Provider.of<FinanceRepository>(context);
    final currencyFormatter =
        NumberFormat.currency(symbol: '₪', decimalDigits: 0);

    // Group transactions by month
    final Map<int, double> monthlyIncome = {};
    final Map<int, double> monthlyExpense = {};

    for (int i = 1; i <= 12; i++) {
      monthlyIncome[i] = 0.0;
      monthlyExpense[i] = 0.0;
    }

    final List<BaseTransaction> yearTransactions =
        repo.transactions.where((tx) => tx.date.year == _selectedYear).toList();

    for (var tx in yearTransactions) {
      Category? cat;
      if (tx.appCategoryId != null) {
        cat = repo.getCategoryById(tx.appCategoryId!);
      } else if (tx.category != null) {
        cat = repo.categories
            .where((c) => c.name.toLowerCase() == tx.category!.toLowerCase())
            .firstOrNull;
      }

      if (cat != null && cat.isExcludedFromAnalytics) continue;

      final month = tx.date.month;

      double expenseAmount = 0.0;
      double incomeAmount = 0.0;

      if (tx is BankTransactionModel) {
        if (tx.expense != null) expenseAmount = tx.expense!;
        if (tx.income != null) incomeAmount = tx.income!;
      } else if (tx is CcTransactionModel) {
        if (tx.amount != null && tx.amount! >= 0) expenseAmount = tx.amount!;
        if (tx.amount != null && tx.amount! < 0) incomeAmount = -(tx.amount!);
      }

      if (cat != null) {
        if (cat.type == CategoryType.expense) {
          monthlyExpense[month] =
              (monthlyExpense[month] ?? 0.0) + expenseAmount;
        } else {
          monthlyIncome[month] = (monthlyIncome[month] ?? 0.0) + incomeAmount;
        }
      } else {
        // Uncategorized
        if (expenseAmount > 0)
          monthlyExpense[month] =
              (monthlyExpense[month] ?? 0.0) + expenseAmount;
        if (incomeAmount > 0)
          monthlyIncome[month] = (monthlyIncome[month] ?? 0.0) + incomeAmount;
      }
    }

    final double totalIncome = monthlyIncome.values.fold(0.0, (a, b) => a + b);
    final double totalExpense =
        monthlyExpense.values.fold(0.0, (a, b) => a + b);
    final double maxAmount = [...monthlyIncome.values, ...monthlyExpense.values]
        .fold(0.0, (max, val) => val > max ? val : max);

    // Calculate Y axis interval
    final double yInterval =
        maxAmount > 0 ? (maxAmount / 4).ceilToDouble() : 1000.0;

    return Column(
      children: [
        // Year Selector
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              _previousYear();
            } else if (details.primaryVelocity! < 0) {
              _nextYear();
            }
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.textPrimary),
                  onPressed: () =>
                      _nextYear(), // Right arrow for older year in RTL
                ),
                Text(
                  '$_selectedYear',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: AppColors.textPrimary),
                  onPressed: () =>
                      _previousYear(), // Left arrow for newer year in RTL
                ),
              ],
            ),
          ),
        ),

        // Summary Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  color: AppColors.primary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Income',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(totalIncome),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: AppColors.expenseRed.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Expenses',
                            style: TextStyle(
                                color: AppColors.expenseRed,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(totalExpense),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Bar Chart
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(right: 16.0, left: 16.0, bottom: 24.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxAmount * 1.1,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        '${isIncome ? "Income" : "Expense"}\n${currencyFormatter.format(rod.toY)}',
                        TextStyle(
                          color: isIncome
                              ? AppColors.primary
                              : AppColors.expenseRed,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        );
                        final months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                          'Jul',
                          'Aug',
                          'Sep',
                          'Oct',
                          'Nov',
                          'Dec'
                        ];
                        final index = value.toInt() - 1;
                        if (index < 0 || index > 11)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(months[index], style: style),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: yInterval > 0 ? yInterval : 1000,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            currencyFormatter.format(value),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval > 0 ? yInterval : 1000,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (index) {
                  final month = index + 1;
                  return BarChartGroupData(
                    x: month,
                    barRods: [
                      BarChartRodData(
                        toY: monthlyIncome[month] ?? 0.0,
                        color: AppColors.primary,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: monthlyExpense[month] ?? 0.0,
                        color: AppColors.expenseRed,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
