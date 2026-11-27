import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/account_config.dart';
import '../engine/finance_engine.dart';
import '../services/transaction_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<FinanceResult> _future;

  final NumberFormat _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<FinanceResult> _load() async {
    final all = await TransactionService.getAllTransactions();
    return FinanceEngine.process(all);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    final next = _load();

    // Braces, not an arrow: setState must not return a Future.
    setState(() {
      _future = next;
    });

    try {
      await next;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  /// 1500 -> "1.5k", 2500000 -> "2.5M"
  static String _shortNumber(double v) {
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  Widget _summaryCard(String title, double value, MaterialColor color) {
    return Card(
      color: color.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color.shade800)),
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

  Widget _buildChart(FinanceResult result) {
    final keys = AccountConfig.accounts.keys.toList();

    // The lowest and highest balance decide the height of the chart.
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
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _shortNumber(value),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= keys.length) return const SizedBox.shrink();

                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    AccountConfig.shortNameOf(keys[i]),
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
              return BarTooltipItem(
                '${AccountConfig.nameOf(keys[groupIndex])}\n'
                '${_money.format(rod.toY)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(FinanceResult r) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard('Total Income', r.totalIncome, Colors.green),
            ),
            Expanded(
              child: _summaryCard('Total Expense', r.totalExpense, Colors.red),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Saldo',
                r.balance,
                r.balance >= 0 ? Colors.teal : Colors.red,
              ),
            ),
            Expanded(
              child: _summaryCard('Total Aset', r.totalAssets, Colors.blue),
            ),
          ],
        ),

        // A check that your data is consistent.
        if (r.difference.abs() > 0.5)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ada selisih ${_money.format(r.difference)} antara Saldo '
                      'dan Total Aset. Biasanya karena transfer yang hanya '
                      'terhapus satu sisi, atau transaksi dengan akun yang '
                      'tidak dikenal.',
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),
        Text('Akun', style: Theme.of(context).textTheme.titleMedium),
        for (final entry in r.accounts.entries)
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
            title: Text(AccountConfig.nameOf(entry.key)),
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
        SizedBox(height: 240, child: _buildChart(r)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<FinanceResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
                  const Text('Tarik ke bawah untuk mencoba lagi.'),
                ],
              );
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }
}