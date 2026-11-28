
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/account_config.dart';
import '../engine/finance_engine.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../services/auth_service.dart';
import '../services/household_service.dart';

/// Menyimpan hasil pemuatan data dashboard.
class DashboardData {
  final FinanceResult result;
  final List<Map<String, dynamic>> accounts;

  const DashboardData({
    required this.result,
    required this.accounts,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardData> _future;

  final NumberFormat _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Mengambil transaksi dan daftar akun dari Supabase.
  ///
  /// Semua akun tetap dimuat, termasuk akun nonaktif,
  /// agar saldo dan total aset historis tetap diperhitungkan.
  Future<DashboardData> _load() async {
    final accounts = await AccountService.getAccounts(
      activeOnly: false,
    );

    final transactions = await TransactionService.getAllTransactions();

    final accountCodes = accounts
        .map((account) => account['kode'].toString())
        .toList();

    final result = FinanceEngine.process(
      transactions,
      accountCodes: accountCodes,
    );

    return DashboardData(
      result: result,
      accounts: accounts,
    );
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Memuat ulang dashboard ketika pengguna menarik layar ke bawah.
  Future<void> _refresh() async {
    final next = _load();

    setState(() {
      _future = next;
    });

    try {
      await next;
    } catch (_) {
      // Kesalahan ditampilkan melalui FutureBuilder.
    }
  }

  /// Mengambil nama akun berdasarkan kode akun.
  String _accountName(String code, List<Map<String, dynamic>> accounts) {
    for (final account in accounts) {
      if (account['kode']?.toString() == code) {
        return account['nama']?.toString() ?? code;
      }
    }

    return AccountConfig.nameOf(code);
  }

  /// Mengambil nama singkat akun untuk label grafik.
  String _shortAccountName(
    String code,
    List<Map<String, dynamic>> accounts,
  ) {
    for (final account in accounts) {
      if (account['kode']?.toString() == code) {
        final name = account['nama']?.toString() ?? code;

        if (name.length > 7) {
          return name.substring(0, 7);
        }

        return name;
      }
    }

    return AccountConfig.shortNameOf(code);
  }

  /// 1500 -> "2k", 2500000 -> "2.5M".
  static String _shortNumber(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }

    return value.toStringAsFixed(0);
  }

  /// Membuat kartu ringkasan keuangan.
  Widget _summaryCard(
    String title,
    double value,
    MaterialColor color,
  ) {
    return Card(
      color: color.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: color.shade800),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _money.format(value),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membuat grafik saldo berdasarkan daftar akun dinamis.
  Widget _buildChart(
    FinanceResult result,
    List<Map<String, dynamic>> accounts,
  ) {
    // Mengambil seluruh kode akun dari hasil perhitungan.
    final keys = result.accounts.keys.toList();

    if (keys.isEmpty) {
      return const Center(
        child: Text('Belum ada akun untuk ditampilkan.'),
      );
    }

    // Menentukan batas minimum dan maksimum grafik.
    var low = 0.0;
    var high = 0.0;

    for (final value in result.accounts.values) {
      low = min(low, value);
      high = max(high, value);
    }

    final span = max(high - low, 1.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: low < 0 ? low - span * 0.15 : 0,
        maxY: high + span * 0.15,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _shortNumber(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index >= keys.length) {
                  return const SizedBox.shrink();
                }

                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _shortAccountName(keys[index], accounts),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < keys.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: result.accounts[keys[i]] ?? 0,
                  color: AccountConfig.colorOf(keys[i]),
                  width: 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final code = keys[groupIndex];

              return BarTooltipItem(
                '${_accountName(code, accounts)}\n'
                '${_money.format(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Membangun seluruh isi dashboard.
  Widget _buildContent(DashboardData data) {
    final result = data.result;
    final accounts = data.accounts;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Ringkasan pemasukan dan pengeluaran.
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Total Income',
                result.totalIncome,
                Colors.green,
              ),
            ),
            Expanded(
              child: _summaryCard(
                'Total Expense',
                result.totalExpense,
                Colors.red,
              ),
            ),
          ],
        ),

        // Ringkasan saldo dan total aset.
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Saldo',
                result.balance,
                result.balance >= 0 ? Colors.teal : Colors.red,
              ),
            ),
            Expanded(
              child: _summaryCard(
                'Total Aset',
                result.totalAssets,
                Colors.blue,
              ),
            ),
          ],
        ),

        // Memperingatkan pengguna jika saldo dan aset tidak cocok.
        if (result.difference.abs() > 0.5)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ada selisih ${_money.format(result.difference)} '
                      'antara Saldo dan Total Aset. Biasanya karena '
                      'transfer yang hanya terhapus satu sisi, atau '
                      'transaksi dengan akun yang tidak dikenal.',
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        Text(
          'Akun',
          style: Theme.of(context).textTheme.titleMedium,
        ),

        // Menampilkan saldo seluruh akun dari database.
        for (final entry in result.accounts.entries)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AccountConfig.colorOf(entry.key),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              _accountName(entry.key, accounts),
            ),
            subtitle: _isAccountInactive(entry.key, accounts)
                ? const Text(
                    'Nonaktif',
                    style: TextStyle(color: Colors.grey),
                  )
                : null,
            trailing: Text(
              _money.format(entry.value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.value < 0 ? Colors.red : null,
              ),
            ),
          ),

        const SizedBox(height: 16),

        Text(
          'Grafik saldo akun',
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 240,
          child: _buildChart(result, accounts),
        ),
      ],
    );
  }

  /// Memeriksa apakah suatu akun berstatus nonaktif.
  bool _isAccountInactive(
    String code,
    List<Map<String, dynamic>> accounts,
  ) {
    for (final account in accounts) {
      if (account['kode']?.toString() == code) {
        return account['is_active'] != true;
      }
    }

    return false;
  }

  /// Menampilkan informasi akun dan tombol Logout.
  Future<void> _showAccountDialog() async {
    final user = AuthService.currentUser;

    if (user == null) return;

    final householdFuture = HouseholdService.getMyHousehold();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_circle, size: 28),
              SizedBox(width: 10),
              Text('Informasi Akun'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(user.email ?? '-'),
              const SizedBox(height: 16),
              const Text(
                'Rumah Tangga',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              FutureBuilder<Map<String, dynamic>?>(
                future: householdFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return const Text(
                      'Gagal mengambil informasi rumah tangga.',
                    );
                  }

                  final household = snapshot.data;

                  if (household == null) {
                    return const Text(
                      'Belum memiliki rumah tangga.',
                    );
                  }

                  final role = household['role'] == 'owner'
                      ? 'Owner'
                      : 'Member';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(household['name']?.toString() ?? '-'),
                      const SizedBox(height: 4),
                      Text('Peran: $role'),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  await AuthService.signOut();
                } catch (error) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal logout: $error'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Akun dan Logout',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _showAccountDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Gagal mengambil data:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tarik ke bawah untuk mencoba lagi.',
                  ),
                ],
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Text('Data dashboard belum tersedia.'),
              );
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }
}
