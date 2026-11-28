
import '../models/transaction_model.dart';

/// Menyimpan informasi masalah yang ditemukan pada transaksi.
class FinanceIssue {
  final String transactionId;
  final String message;

  const FinanceIssue({
    required this.transactionId,
    required this.message,
  });

  @override
  String toString() {
    return 'Transaksi $transactionId: $message';
  }
}

/// Hasil dari seluruh perhitungan keuangan.
class FinanceResult {
  final double totalIncome;
  final double totalExpense;
  final Map<String, double> accounts;

  const FinanceResult({
    required this.totalIncome,
    required this.totalExpense,
    required this.accounts,
  });

  /// Pendapatan dikurangi pengeluaran.
  double get balance => totalIncome - totalExpense;

  /// Jumlah seluruh saldo rekening.
  double get totalAssets =>
      accounts.values.fold<double>(0, (sum, value) => sum + value);

  /// Selisih antara saldo perhitungan dan total aset rekening.
  double get difference => balance - totalAssets;
}

/// Mesin utama perhitungan keuangan.
class FinanceEngine {
  /// Memproses transaksi dan menghitung saldo setiap akun.
  ///
  /// [accountCodes] berisi kode akun dari database Supabase.
  /// Akun yang belum memiliki transaksi tetap mendapatkan saldo nol.
  ///
  /// Kode akun yang ditemukan dalam transaksi juga otomatis ditambahkan
  /// agar transaksi lama tetap diperhitungkan.
  static FinanceResult process(
    List<TransactionModel> transactions, {
    List<String> accountCodes = const [],
  }) {
    // Membuat daftar akun secara dinamis.
    final Map<String, double> accounts = {
      for (final code in accountCodes)
        if (code.trim().isNotEmpty) code: 0,
    };

    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in transactions) {
      // Memastikan akun dari transaksi selalu tersedia dalam perhitungan.
      accounts.putIfAbsent(t.account, () => 0);

      if (t.type == 'income') {
        totalIncome += t.amount;

        accounts[t.account] = accounts[t.account]! + t.amount;
      } else if (t.type == 'expense') {
        totalExpense += t.amount;

        accounts[t.account] = accounts[t.account]! - t.amount;
      } else if (t.type == 'transfer') {
        // Transfer negatif berarti uang keluar.
        // Transfer positif berarti uang masuk.
        accounts[t.account] = accounts[t.account]! + t.amount;
      }
    }

    return FinanceResult(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      accounts: accounts,
    );
  }

  /// Memeriksa apakah transaksi memiliki data yang bermasalah.
  ///
  /// Pemeriksaan ini tidak lagi menggunakan daftar akun statis.
  /// Akun baru dari Supabase dianggap valid selama kodenya tidak kosong.
  static List<FinanceIssue> validateTransactions(
    List<TransactionModel> transactions,
  ) {
    final List<FinanceIssue> issues = [];

    for (final t in transactions) {
      final transactionId = t.id?.toString() ?? 'Tidak diketahui';

      // Memeriksa kode akun.
      if (t.account.trim().isEmpty) {
        issues.add(
          FinanceIssue(
            transactionId: transactionId,
            message: 'Kode akun tidak boleh kosong.',
          ),
        );
      }

      // Memeriksa nominal yang tidak valid.
      if (!t.amount.isFinite) {
        issues.add(
          FinanceIssue(
            transactionId: transactionId,
            message: 'Nominal transaksi tidak valid.',
          ),
        );
        continue;
      }

      if (t.amount == 0) {
        issues.add(
          FinanceIssue(
            transactionId: transactionId,
            message: 'Nominal transaksi tidak boleh nol.',
          ),
        );
      }

      // Pendapatan dan pengeluaran harus menggunakan nominal positif.
      if ((t.type == 'income' || t.type == 'expense') &&
          t.amount < 0) {
        issues.add(
          FinanceIssue(
            transactionId: transactionId,
            message: 'Nominal pendapatan/pengeluaran harus positif.',
          ),
        );
      }

      // Memeriksa jenis transaksi.
      if (!['income', 'expense', 'transfer'].contains(t.type)) {
        issues.add(
          FinanceIssue(
            transactionId: transactionId,
            message: 'Jenis transaksi "${t.type}" tidak dikenal.',
          ),
        );
      }
    }

    return issues;
  }
}
