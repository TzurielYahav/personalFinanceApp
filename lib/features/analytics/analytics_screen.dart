import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/models/bank_transaction_model.dart';
import '../../core/models/cc_transaction_model.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<FinanceRepository>(context);
    final currencyFormatter =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    // Calculate category spending breakdown for expenses
    final Map<String, double> categoryTotals = {};
    for (var tx in repo.transactions) {
      if (tx is BankTransactionModel && tx.expense != null) {
        final cat = tx.category ?? 'Uncategorized';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + tx.expense!;
      } else if (tx is CcTransactionModel) {
        final cat = tx.category ?? 'Uncategorized';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + (tx.amount ?? 0.0);
      }
    }

    final double totalExpenses =
        categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    final List<PieChartSectionData> sections = [];
    int index = 0;
    categoryTotals.forEach((catName, amount) {
      // Find category in repo by name to get its color, or use default
      final category = repo.categories
          .where((c) => c.name.toLowerCase() == catName.toLowerCase())
          .firstOrNull;
      final isTouched = index == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final percentage = totalExpenses > 0
          ? (amount / totalExpenses * 100).toStringAsFixed(1)
          : '0';

      sections.add(
        PieChartSectionData(
          color: category?.color ?? AppColors.accentBlue,
          value: amount,
          title: '$percentage%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      index++;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spending Pie Chart Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Category Expenses Breakdown',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: sections.isEmpty
                          ? const Center(
                              child: Text('No expense data available',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                            )
                          : PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection ==
                                              null) {
                                        _touchedIndex = -1;
                                        return;
                                      }
                                      _touchedIndex = pieTouchResponse
                                          .touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: 3,
                                centerSpaceRadius: 40,
                                sections: sections,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Limits & Progress Bars
            const Text(
              'Monthly Category Budgets',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: repo.categories.length,
              itemBuilder: (context, idx) {
                final cat = repo.categories[idx];
                final spent = categoryTotals[cat.name] ??
                    categoryTotals.entries
                        .where((e) =>
                            e.key.toLowerCase() == cat.name.toLowerCase())
                        .map((e) => e.value)
                        .fold(0.0, (sum, val) => sum! + val) ??
                    0.0;
                final limit = cat.monthlyBudgetLimit ?? 500.0;
                final progress = (spent / limit).clamp(0.0, 1.0);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(cat.iconData, color: cat.color, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              cat.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                            const Spacer(),
                            Text(
                              '${currencyFormatter.format(spent)} / ${currencyFormatter.format(limit)}',
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
                              progress > 0.9 ? AppColors.expenseRed : cat.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
