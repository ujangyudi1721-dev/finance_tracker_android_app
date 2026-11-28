
import 'package:finance_tracker_app/engine/finance_engine.dart';
import 'package:finance_tracker_app/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(String type, String account, double amount) {
  return TransactionModel(
    id: 1,
    date: DateTime(2026, 1, 1),
    type: type,
    category: 'test',
    amount: amount,
    account: account,
    note: '',
  );
}

void main() {
  group('FinanceEngine - Perhitungan', () {
    test('income adds to the total and to the account', () {
      final r = FinanceEngine.process([tx('income', 'cash', 100000)]);

      expect(r.totalIncome, 100000);
      expect(r.accounts['cash'], 100000);
      expect(r.balance, 100000);
    });

    test('expense subtracts from the account', () {
      final r = FinanceEngine.process([
        tx('income', 'cash', 100000),
        tx('expense', 'cash', 30000),
      ]);

      expect(r.totalExpense, 30000);
      expect(r.accounts['cash'], 70000);
      expect(r.balance, 70000);
    });

    test('a transfer moves money and keeps the totals', () {
      final r = FinanceEngine.process([
        tx('income', 'cash', 100000),
        tx('transfer', 'cash', -40000),
        tx('transfer', 'cimb', 40000),
      ]);

      expect(r.accounts['cash'], 60000);
      expect(r.accounts['cimb'], 40000);
      expect(r.totalIncome, 100000);
      expect(r.totalAssets, 100000);
      expect(r.difference, 0);
    });

    test('an unknown account counts in the totals but not in any account', () {
      final r = FinanceEngine.process([tx('income', 'paypal', 50000)]);

      expect(r.totalIncome, 50000);
      expect(r.totalAssets, 0);
      expect(r.difference, 50000);
    });

    test('type and account are read in a forgiving way', () {
      final model = TransactionModel.fromMap({
        'id': 1,
        'tanggal': '2026-01-01',
        'tipe': ' Income ',
        'kategori': 'x',
        'jumlah': 25000,
        'akun': ' CASH ',
        'keterangan': '',
      });

      final r = FinanceEngine.process([model]);

      expect(r.accounts['cash'], 25000);
    });
  });

  group('FinanceEngine - Validasi Transaksi', () {
    test('detects an unknown account', () {
      final issues = FinanceEngine.validateTransactions([
        tx('income', 'paypal', 50000),
      ]);

      expect(issues, isNotEmpty);
      expect(
        issues.any((issue) => issue.message.contains('tidak dikenal')),
        isTrue,
      );
    });

    test('detects a zero transaction amount', () {
      final issues = FinanceEngine.validateTransactions([
        tx('income', 'cash', 0),
      ]);

      expect(
        issues.any((issue) => issue.message.contains('tidak boleh nol')),
        isTrue,
      );
    });

    test('detects negative income', () {
      final issues = FinanceEngine.validateTransactions([
        tx('income', 'cash', -50000),
      ]);

      expect(
        issues.any((issue) => issue.message.contains('harus positif')),
        isTrue,
      );
    });

    test('detects negative expense', () {
      final issues = FinanceEngine.validateTransactions([
        tx('expense', 'cash', -30000),
      ]);

      expect(
        issues.any((issue) => issue.message.contains('harus positif')),
        isTrue,
      );
    });

    test('detects an unknown transaction type', () {
      final issues = FinanceEngine.validateTransactions([
        tx('deposit', 'cash', 50000),
      ]);

      expect(
        issues.any((issue) => issue.message.contains('tidak dikenal')),
        isTrue,
      );
    });

    test('allows positive and negative transfer amounts', () {
      final issues = FinanceEngine.validateTransactions([
        tx('transfer', 'cash', -40000),
        tx('transfer', 'cimb', 40000),
      ]);

      expect(issues, isEmpty);
    });

    test('detects an invalid non-finite amount', () {
      final issues = FinanceEngine.validateTransactions([
        tx('income', 'cash', double.nan),
      ]);

      expect(
        issues.any((issue) => issue.message.contains('tidak valid')),
        isTrue,
      );
    });
  });
}
