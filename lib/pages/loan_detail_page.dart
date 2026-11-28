
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/loan_model.dart';
import '../models/loan_installment_model.dart';
import '../services/loan_service.dart';
import '../services/account_service.dart';

class LoanDetailPage extends StatefulWidget {
  final LoanModel loan;

  const LoanDetailPage({
    super.key,
    required this.loan,
  });

  @override
  State<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends State<LoanDetailPage> {
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _isCancelled = false;

  List<LoanInstallmentModel> _installments = [];

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    _isCancelled = widget.loan.status == 'cancelled';
    _loadInstallments();
  }

  bool get _isCompleted {
    if (widget.loan.status == 'completed') return true;

    return _installments.isNotEmpty &&
        _installments.every((item) => item.isPaid);
  }

  bool get _canMakePayment {
    return !_isCancelled &&
        !_isCompleted &&
        widget.loan.status == 'active';
  }

  String get _loanStatusLabel {
    if (_isCancelled) return 'Dibatalkan';
    if (_isCompleted) return 'Lunas';
    return 'Aktif';
  }

  Color get _loanStatusColor {
    if (_isCancelled) return Colors.grey;
    if (_isCompleted) return Colors.green;
    return Colors.blue;
  }

  Future<void> _loadInstallments() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await LoanService.getInstallments(widget.loan.id);

      if (!mounted) return;

      setState(() {
        _installments = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil data cicilan: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double get _totalPaid {
    return _installments.fold<double>(
      0,
      (sum, installment) => sum + installment.totalDibayar,
    );
  }

  double get _remainingBalance {
    if (_isCancelled || _isCompleted) return 0;

    final remaining = widget.loan.totalLoan - _totalPaid;
    return remaining > 0 ? remaining : 0;
  }

  int get _paidCount {
    return _installments.where((item) => item.isPaid).length;
  }

  int get _partialCount {
    return _installments.where((item) => item.isPartial).length;
  }

  String _formatCurrency(double value) => _currency.format(value);

  String _formatDate(DateTime date) => _dateFormat.format(date);

  // ============================================================
  // PEMBATALAN PINJAMAN
  // ============================================================

  Future<void> _confirmCancelLoan() async {
    if (!_canMakePayment || _isCancelling) return;

    // Tidak menggunakan TextEditingController.
    // Teks disimpan melalui onChanged.
    String cancellationNote = '';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Batalkan Pinjaman?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pinjaman ini akan ditandai sebagai dibatalkan. '
                  'Sisa kewajiban yang belum dibayar akan dihapuskan.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Total pinjaman: '
                  '${_formatCurrency(widget.loan.totalLoan)}',
                ),
                Text(
                  'Total sudah dibayar: '
                  '${_formatCurrency(_totalPaid)}',
                ),
                Text(
                  'Sisa yang dihapuskan: '
                  '${_formatCurrency(_remainingBalance)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Riwayat pembayaran dan transaksi keuangan yang sudah '
                  'tercatat tidak akan dihapus atau dibalik.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  maxLines: 2,
                  onChanged: (value) {
                    cancellationNote = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Alasan pembatalan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Kembali'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Ya, Batalkan'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await LoanService.cancelLoan(
        loanId: widget.loan.id,
        note: cancellationNote.trim().isEmpty
            ? null
            : cancellationNote.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isCancelled = true;
        _isCancelling = false;
      });

      await _loadInstallments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pinjaman berhasil dibatalkan. Riwayat pembayaran tetap tersimpan.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isCancelling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan pinjaman: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // PEMBAYARAN CICILAN
  // ============================================================

  Future<void> _showPaymentDialog(
    LoanInstallmentModel installment,
  ) async {
    if (!_canMakePayment) return;

    try {
      final accounts = await AccountService.getAccounts(
        activeOnly: true,
      );

      if (!mounted || !_canMakePayment) return;

      if (accounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Belum ada rekening aktif. Aktifkan atau tambahkan rekening terlebih dahulu.',
            ),
          ),
        );
        return;
      }

      // Data dialog disimpan sebagai variabel biasa.
      // Tidak ada TextEditingController yang perlu di-dispose.
      String amountText = '';
      String noteText = '';

      String selectedAccount = accounts.first['kode'].toString();
      DateTime selectedDate = DateTime.now();
      bool isSaving = false;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Bayar Cicilan'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanggal cicilan: '
                        '${_formatDate(installment.tanggal)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sisa pembayaran: '
                        '${_formatCurrency(installment.sisaPembayaran)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (value) {
                          amountText = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Jumlah pembayaran',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                          hintText: 'Contoh: 500000',
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: selectedAccount,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Rekening pembayaran',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts.map((account) {
                          final code = account['kode'].toString();
                          final name =
                              account['nama']?.toString() ?? code;

                          return DropdownMenuItem<String>(
                            value: code,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedAccount = value;
                                });
                              },
                      ),

                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );

                                if (date != null &&
                                    dialogContext.mounted) {
                                  setDialogState(() {
                                    selectedDate = date;
                                  });
                                }
                              },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          'Tanggal: ${_formatDate(selectedDate)}',
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        maxLines: 2,
                        onChanged: (value) {
                          noteText = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.pop(dialogContext, false);
                          },
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final rawAmount = amountText
                                .trim()
                                .replaceAll('.', '')
                                .replaceAll(',', '.');

                            final amount =
                                double.tryParse(rawAmount);

                            if (amount == null ||
                                !amount.isFinite ||
                                amount <= 0) {
                              ScaffoldMessenger.of(dialogContext)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Masukkan jumlah pembayaran yang valid.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (amount >
                                installment.sisaPembayaran + 0.000001) {
                              ScaffoldMessenger.of(dialogContext)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Jumlah pembayaran melebihi sisa cicilan.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            try {
                              await LoanService.recordPayment(
                                installmentId: installment.id,
                                amount: amount,
                                date: selectedDate,
                                account: selectedAccount,
                                note: noteText.trim().isEmpty
                                    ? null
                                    : noteText.trim(),
                              );

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext, true);
                            } catch (error) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() {
                                isSaving = false;
                              });

                              ScaffoldMessenger.of(dialogContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal menyimpan pembayaran: $error',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Pembayaran'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true && mounted) {
        await _loadInstallments();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran cicilan berhasil disimpan.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat rekening: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // PEMBALIKAN PEMBAYARAN
  // ============================================================

  Future<void> _confirmReversePayment(
    Map<String, dynamic> payment,
  ) async {
    final paymentId = payment['id']?.toString();

    if (paymentId == null || paymentId.isEmpty) return;

    // Catatan disimpan tanpa TextEditingController.
    String reversalNote = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Batalkan Pembayaran?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pembatalan akan membuat transaksi pembalik. '
                'Riwayat pembayaran asli tetap disimpan.',
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 2,
                onChanged: (value) {
                  reversalNote = value;
                },
                decoration: const InputDecoration(
                  labelText: 'Alasan pembatalan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Kembali'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Batalkan Pembayaran'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await LoanService.reversePayment(
        paymentId: paymentId,
        note: reversalNote.trim().isEmpty
            ? null
            : reversalNote.trim(),
      );

      if (!mounted) return;

      await _loadInstallments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pembayaran berhasil dibatalkan melalui transaksi pembalik.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan pembayaran: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // RIWAYAT PEMBAYARAN
  // ============================================================

  Widget _buildPaymentHistory(String installmentId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LoanService.getPayments(installmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Gagal mengambil riwayat pembayaran: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final payments = snapshot.data ?? [];

        if (payments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Belum ada riwayat pembayaran.'),
          );
        }

        return Column(
          children: payments.map((payment) {
            final amount =
                (payment['jumlah'] as num?)?.toDouble() ?? 0;

            final date = DateTime.tryParse(
              payment['tanggal']?.toString() ?? '',
            );

            final account = payment['akun']?.toString() ?? '-';
            final status = payment['status']?.toString() ?? 'active';
            final isReversed = status == 'reversed';

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: ListTile(
                leading: Icon(
                  isReversed
                      ? Icons.undo
                      : Icons.check_circle,
                  color: isReversed
                      ? Colors.orange
                      : Colors.green,
                ),
                title: Text(
                  _formatCurrency(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isReversed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal: '
                      '${date == null ? '-' : _formatDate(date)}',
                    ),
                    Text('Rekening: $account'),
                    Text(
                      isReversed ? 'Dibatalkan' : 'Aktif',
                      style: TextStyle(
                        color: isReversed
                            ? Colors.orange
                            : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isReversed &&
                        payment['reversal_note'] != null &&
                        payment['reversal_note']
                            .toString()
                            .isNotEmpty)
                      Text(
                        'Alasan: ${payment['reversal_note']}',
                      ),
                  ],
                ),
                isThreeLine: true,
                trailing: isReversed
                    ? null
                    : IconButton(
                        tooltip: 'Batalkan pembayaran',
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          _confirmReversePayment(payment);
                        },
                      ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // KARTU CICILAN
  // ============================================================

  Widget _buildInstallmentCard(
    LoanInstallmentModel installment,
    int index,
  ) {
    final isPaid = installment.isPaid;
    final isPartial = installment.isPartial;

    final Color statusColor = isPaid
        ? Colors.green
        : isPartial
            ? Colors.orange
            : Colors.red;

    final String statusText = isPaid
        ? 'Lunas'
        : isPartial
            ? 'Dibayar sebagian'
            : 'Belum dibayar';

    return Card(
      key: ValueKey('installment-card-${installment.id}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'installment-${installment.id}',
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          _formatCurrency(installment.jumlah),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jatuh tempo: ${_formatDate(installment.tanggal)}',
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (installment.totalDibayar > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Sudah dibayar: '
                '${_formatCurrency(installment.totalDibayar)}',
              ),
              Text(
                'Sisa: '
                '${_formatCurrency(installment.sisaPembayaran)}',
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_canMakePayment &&
                    !isPaid &&
                    installment.sisaPembayaran > 0)
                  FilledButton.icon(
                    onPressed: () {
                      _showPaymentDialog(installment);
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Bayar Cicilan'),
                  ),
                if (_isCancelled)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Pinjaman telah dibatalkan. '
                      'Pembayaran baru tidak dapat dilakukan.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Riwayat Pembayaran',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildPaymentHistory(installment.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RINGKASAN PINJAMAN
  // ============================================================

  Widget _buildLoanSummary() {
    final isDebt = widget.loan.jenis == 'debt';

    final typeText = isDebt ? 'Utang' : 'Piutang';
    final typeColor = isDebt ? Colors.red : Colors.green;

    final progress = widget.loan.totalLoan > 0
        ? (_totalPaid / widget.loan.totalLoan).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.loan.nama,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(typeText),
                  backgroundColor:
                      typeColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: _loanStatusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _loanStatusLabel,
                style: TextStyle(
                  color: _loanStatusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            if (_isCancelled) ...[
              const SizedBox(height: 12),
              const Text(
                'Pinjaman ini telah dibatalkan. '
                'Sisa kewajiban yang belum dibayar telah dihapuskan. '
                'Riwayat pembayaran tetap dipertahankan.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
            if (widget.loan.pihakTerkait != null &&
                widget.loan.pihakTerkait!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Pihak terkait: ${widget.loan.pihakTerkait}',
                ),
              ),
            const SizedBox(height: 16),
            _summaryRow(
              'Total pinjaman',
              _formatCurrency(widget.loan.totalLoan),
            ),
            _summaryRow(
              'Total dibayar',
              _formatCurrency(_totalPaid),
            ),
            _summaryRow(
              'Sisa pinjaman',
              _formatCurrency(_remainingBalance),
            ),
            _summaryRow(
              'Jumlah cicilan',
              '${_installments.length} kali',
            ),
            _summaryRow(
              'Cicilan lunas',
              '$_paidCount',
            ),
            _summaryRow(
              'Cicilan sebagian',
              '$_partialCount',
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            Text(
              _isCancelled
                  ? '${(progress * 100).toStringAsFixed(1)}% telah dibayar sebelum pembatalan'
                  : '${(progress * 100).toStringAsFixed(1)}% telah dibayar',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (widget.loan.keterangan != null &&
                widget.loan.keterangan!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Keterangan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(widget.loan.keterangan!),
            ],
            if (_canMakePayment) ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isCancelling ? null : _confirmCancelLoan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    _isCancelling
                        ? 'Membatalkan...'
                        : 'Batalkan Pinjaman',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pinjaman'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loadInstallments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadInstallments,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  _buildLoanSummary(),
                  const SizedBox(height: 16),
                  Text(
                    'Jadwal Cicilan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_installments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Belum ada jadwal cicilan.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._installments.asMap().entries.map(
                      (entry) => _buildInstallmentCard(
                        entry.value,
                        entry.key,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
