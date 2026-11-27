import '../config/account_config.dart';
import '../models/transaction_model.dart';

/// The result of all calculations.
class FinanceResult {
  final double totalIncome;
  final double totalExpense;
  final Map<String, double> accounts; // balance of each account

  const FinanceResult({
    required this.totalIncome,
    required this.totalExpense,
    required this.accounts,
  });

  /// Income minus expense (the "Saldo" on your website).
  double get balance => totalIncome - totalExpense;

  /// The sum of all account balances ("Total Aset").
  double get totalAssets =>
      accounts.values.fold<double>(0, (sum, v) => sum + v);

  /// This should be 0. If not, some money is not in any known account.
  double get difference => balance - totalAssets;
}

/// The Dart version of processTransactions() in financeEngine.js.
/// It only calculates. There is no screen and no database in it.
class FinanceEngine {
  static FinanceResult process(List<TransactionModel> transactions) {
    final Map<String, double> accounts = {
      for (final key in AccountConfig.accounts.keys) key: 0,
    };

    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
        if (accounts.containsKey(t.account)) {
          accounts[t.account] = accounts[t.account]! + t.amount;
        }
      } else if (t.type == 'expense') {
        totalExpense += t.amount;
        if (accounts.containsKey(t.account)) {
          accounts[t.account] = accounts[t.account]! - t.amount;
        }
      } else if (t.type == 'transfer') {
        // A transfer has its own sign: negative = out, positive = in.
        if (accounts.containsKey(t.account)) {
          accounts[t.account] = accounts[t.account]! + t.amount;
        }
      }
    }

    return FinanceResult(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      accounts: accounts,
    );
  }
}