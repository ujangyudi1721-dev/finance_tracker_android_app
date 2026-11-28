
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/loan_model.dart';
import '../services/loan_service.dart';
import 'add_loan_page.dart';
import 'loan_detail_page.dart';

/// Halaman utama untuk mengelola data utang dan piutang.
class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  List<LoanModel> _loans = [];

  // Menyimpan sisa pinjaman berdasarkan ID pinjaman.
  Map<String, double> _remainingByLoanId = {};

  bool _isLoading = true;
  String? _errorMessage;

  String _filter = 'all';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  /// Mengambil data pinjaman dan menghitung sisa setiap pinjaman.
  Future<void> _loadLoans() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await LoanService.getLoans();

      final remainingBalances =
          await LoanService.getOutstandingBalances(result);

      if (!mounted) return;

      setState(() {
        _loans = result;
        _remainingByLoanId = remainingBalances;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Mengambil sisa pinjaman berdasarkan ID.
  double _remainingBalance(LoanModel loan) {
    if (loan.status == 'cancelled' ||
        loan.status == 'completed') {
      return 0;
    }

    return _remainingByLoanId[loan.id] ?? loan.totalLoan;
  }

  /// Menghitung total sisa pinjaman aktif berdasarkan jenis.
  double _totalByType(String jenis) {
    return _loans
        .where(
          (loan) =>
              loan.jenis == jenis &&
              loan.status == 'active',
        )
        .fold<double>(
          0,
          (total, loan) => total + _remainingBalance(loan),
        );
  }

  /// Memformat nominal menjadi Rupiah.
  String _formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  /// Mengambil label status pinjaman.
  String _statusLabel(LoanModel loan) {
    switch (loan.status) {
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Lunas';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return loan.status;
    }
  }

  /// Mengambil warna berdasarkan status pinjaman.
  Color _statusColor(LoanModel loan) {
    switch (loan.status) {
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  /// Menampilkan data berdasarkan filter.
  List<LoanModel> get _filteredLoans {
    if (_filter == 'all') return _loans;

    return _loans.where((loan) => loan.jenis == _filter).toList();
  }

  /// Membuat kartu ringkasan keuangan.
  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.09),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatCurrency(amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membuka halaman detail pinjaman.
  Future<void> _openLoanDetail(LoanModel loan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanDetailPage(loan: loan),
      ),
    );

    if (!mounted) return;

    await _loadLoans();
  }

  /// Membuat kartu informasi satu pinjaman.
  Widget _buildLoanCard(LoanModel loan) {
    final isDebt = loan.isDebt;
    final color = isDebt ? Colors.red : Colors.green;
    final remaining = _remainingBalance(loan);
    final statusColor = _statusColor(loan);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isDebt ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
          ),
        ),
        title: Text(
          loan.nama,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(isDebt ? 'Utang' : 'Piutang'),
            const SizedBox(height: 6),

            // Label status pinjaman.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(loan),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            if (loan.pihakTerkait != null &&
                loan.pihakTerkait!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Pihak: ${loan.pihakTerkait}'),
              ),

            const SizedBox(height: 5),
            Text(
              'Total awal: ${_formatCurrency(loan.totalLoan)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Tenor: ${loan.tenor} bulan',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ketuk untuk melihat detail dan jadwal cicilan',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                _formatCurrency(remaining),
                style: TextStyle(
                  color: loan.status == 'cancelled'
                      ? Colors.grey
                      : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Text(
              'Sisa',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
        onTap: () => _openLoanDetail(loan),
      ),
    );
  }

  /// Menampilkan kondisi ketika belum ada pinjaman.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data utang atau piutang',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol Tambah untuk memasukkan data pinjaman.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// Membuka formulir dan memperbarui daftar setelah penyimpanan.
  Future<void> _openAddLoanPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddLoanPage(),
      ),
    );

    if (result == true && mounted) {
      await _loadLoans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDebt = _totalByType('debt');
    final totalReceivable = _totalByType('receivable');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utang & Piutang'),
        actions: [
          IconButton(
            onPressed: _loadLoans,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoans,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Gagal mengambil data:\n$_errorMessage',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Center(
                        child: ElevatedButton(
                          onPressed: _loadLoans,
                          child: const Text('Coba Lagi'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          _buildSummaryCard(
                            title: 'Sisa Total Utang',
                            amount: totalDebt,
                            icon: Icons.arrow_upward,
                            color: Colors.red,
                          ),
                          _buildSummaryCard(
                            title: 'Sisa Total Piutang',
                            amount: totalReceivable,
                            icon: Icons.arrow_downward,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Daftar Pinjaman',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'all',
                            label: Text('Semua'),
                          ),
                          ButtonSegment(
                            value: 'debt',
                            label: Text('Utang'),
                          ),
                          ButtonSegment(
                            value: 'receivable',
                            label: Text('Piutang'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _filter = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_filteredLoans.isEmpty)
                        _buildEmptyState()
                      else
                        ..._filteredLoans.map(_buildLoanCard),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddLoanPage,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}
