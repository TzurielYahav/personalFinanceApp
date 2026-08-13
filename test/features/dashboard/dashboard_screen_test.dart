import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance_app/core/repositories/finance_repository.dart';
import 'package:personal_finance_app/features/dashboard/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen renders Net Worth card and summary metrics', (WidgetTester tester) async {
    final repository = FinanceRepository();

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceRepository>.value(
        value: repository,
        child: const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main financial headers exist
    expect(find.text('TOTAL NET WORTH'), findsOneWidget);
    expect(find.text('Available Cash'), findsOneWidget);
    expect(find.text('Total Debt'), findsOneWidget);

    // Verify section titles
    expect(find.text('Accounts Overview'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
  });
}
