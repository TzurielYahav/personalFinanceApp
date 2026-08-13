# Personal Finance Tracker App 💰📊

A modern, offline-first personal finance tracking application built with **Dart** and **Flutter**.

## 🌟 Key Features

- **Multi-Account Tracking**: Monitor Checking/Savings accounts, Credit Cards, Cash Wallets, and Investments in one place.
- **Fast Cash Logging**: Quick transaction entry dialog designed for on-the-go cash and card expenses.
- **Net Worth & Debt Breakdown**: Automatic real-time calculation of Total Net Worth, Available Cash, and Credit Card Debt.
- **Category Analytics**: Visual charts powered by `fl_chart` for category spending breakdowns and income vs. expense cash flows.
- **Search & Filter**: Search transactions by category, account type, or custom notes.
- **Offline First**: All data is stored locally with sample seed data for instant testing.

## 📁 Architecture Overview

```text
lib/
├── core/
│   ├── models/          # Account, Transaction, Category models
│   ├── repositories/    # Reactive state container (FinanceRepository)
│   ├── services/        # Local Database persistence & seed engine
│   └── theme/           # Dark/Light modern financial theme
├── features/
│   ├── accounts/        # Account management screens & cards
│   ├── analytics/       # Spending graphs & visual analytics
│   ├── dashboard/       # Main overview dashboard
│   └── transactions/    # Transaction log & Quick Add dialog
└── main.dart            # Application entrypoint
```

## 🚀 Getting Started

1. Open a terminal in `E:\Dev\personalFinanceApp`.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app on your connected device or emulator (Android, iOS, Windows, Chrome):
   ```bash
   flutter run
   ```
