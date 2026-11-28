
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/loan_service.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Halaman formulir untuk menambahkan utang atau piutang.
class AddLoanPage extends StatefulWidget {
  const AddLoanPage({super.key});

  @override
  State<AddLoanPage> createState() => _AddLoanPageState();
}

class _AddLoanPageState extends State<AddLoanPage> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _pihakController = TextEditingController();
  final _totalController = TextEditingController();
  final _tenorController = TextEditingController();
  final _cicilanController = TextEditingController();
  final _keteranganController = TextEditingController();

  String _jenis = 'debt';

  DateTime _tanggalMulai = DateTime.now();

  bool _isSaving = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
void initState() {
  super.initState();
  initializeDateFormatting('id_ID', null);
}

  @override
  void dispose() {
    _namaController.dispose();
    _pihakController.dispose();
    _totalController.dispose();
    _tenorController.dispose();
    _cicilanController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  /// Mengubah teks nominal menjadi angka.
  double _parseAmount(String value) {
    final cleaned = value
        .replaceAll('Rp', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');

    return double.tryParse(cleaned) ?? 0;
  }

  /// Mengubah tanggal menjadi hari terakhir bulan jika diperlukan.
  DateTime _dateInMonth(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;

    return DateTime(
      year,
      month,
      day > lastDay ? lastDay : day,
    );
  }

  /// Menghitung tanggal cicilan pertama.
  DateTime get _tanggalCicilanPertama {
    return _dateInMonth(
      _tanggalMulai.year,
      _tanggalMulai.month + 1,
      _tanggalMulai.day,
    );
  }

  /// Menghitung tanggal jatuh tempo cicilan terakhir.
  DateTime _calculateDueDate(int tenor) {
    return _dateInMonth(
      _tanggalMulai.year,
      _tanggalMulai.month + tenor,
      _tanggalMulai.day,
    );
  }

  /// Menghitung cicilan bulanan secara otomatis.
  void _calculateInstallment() {
    final total = _parseAmount(_totalController.text);
    final tenor = int.tryParse(_tenorController.text) ?? 0;

    if (total > 0 && tenor > 0) {
      final installment = (total / tenor).ceilToDouble();

      _cicilanController.text = installment.toStringAsFixed(0);
    } else {
      _cicilanController.clear();
    }

    setState(() {});
  }

  /// Memilih tanggal mulai pinjaman.
  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _tanggalMulai,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );

    if (selected != null && mounted) {
      setState(() {
        _tanggalMulai = selected;
      });
    }
  }

  /// Memvalidasi seluruh data dan menyimpan pinjaman.
  Future<void> _saveLoan() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    final total = _parseAmount(_totalController.text);
    final tenor = int.parse(_tenorController.text);
    final cicilan = _parseAmount(_cicilanController.text);

    setState(() {
      _isSaving = true;
    });

    try {
      await LoanService.createLoan(
        jenis: _jenis,
        nama: _namaController.text,
        pihakTerkait: _pihakController.text,
        totalLoan: total,
        tenor: tenor,
        cicilanPerBulan: cicilan,
        tanggalMulai: _tanggalMulai,
        keterangan: _keteranganController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pinjaman berhasil disimpan.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pinjaman: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Membuat input teks dengan validasi.
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Menghitung nominal cicilan terakhir.
  double _lastInstallment(double total, int tenor, double monthly) {
    return total - (monthly * (tenor - 1));
  }

  @override
  Widget build(BuildContext context) {
    final total = _parseAmount(_totalController.text);
    final tenor = int.tryParse(_tenorController.text) ?? 0;
    final cicilan = _parseAmount(_cicilanController.text);

    final jatuhTempo = tenor > 0
        ? _calculateDueDate(tenor)
        : _tanggalMulai;

    final cicilanTerakhir = tenor > 0
        ? _lastInstallment(total, tenor, cicilan)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Pinjaman'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Jenis Pinjaman',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'debt',
                  label: Text('Utang'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: 'receivable',
                  label: Text('Piutang'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_jenis},
              onSelectionChanged: (selection) {
                setState(() {
                  _jenis = selection.first;
                });
              },
            ),

            const SizedBox(height: 24),

            _buildTextField(
              label: 'Nama Pinjaman',
              controller: _namaController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama pinjaman wajib diisi.';
                }
                return null;
              },
            ),

            _buildTextField(
              label: 'Pihak Terkait (Bank / Orang)',
              controller: _pihakController,
              validator: (_) => null,
            ),

            _buildTextField(
              label: 'Total Pinjaman (Rp)',
              controller: _totalController,
              keyboardType: TextInputType.number,
              onChanged: _calculateInstallment,
              validator: (value) {
                final amount = _parseAmount(value ?? '');

                if (!amount.isFinite || amount <= 0) {
                  return 'Masukkan nominal yang valid.';
                }

                return null;
              },
            ),

            _buildTextField(
              label: 'Tenor (Bulan)',
              controller: _tenorController,
              keyboardType: TextInputType.number,
              onChanged: _calculateInstallment,
              validator: (value) {
                final valueTenor = int.tryParse(value ?? '');

                if (valueTenor == null ||
                    valueTenor < 1 ||
                    valueTenor > 32767) {
                  return 'Tenor harus antara 1 sampai 32767 bulan.';
                }

                return null;
              },
            ),

            _buildTextField(
              label: 'Cicilan Per Bulan (Rp)',
              controller: _cicilanController,
              keyboardType: TextInputType.number,
              validator: (value) {
                final amount = _parseAmount(value ?? '');
                final valueTenor =
                    int.tryParse(_tenorController.text) ?? 0;

                if (!amount.isFinite || amount <= 0) {
                  return 'Nominal cicilan tidak valid.';
                }

                if (valueTenor < 1) {
                  return 'Isi tenor terlebih dahulu.';
                }

                if (amount * (valueTenor - 1) >= total) {
                  return 'Nominal cicilan terlalu besar.';
                }

                if (amount * valueTenor < total) {
                  return 'Total cicilan kurang dari total pinjaman.';
                }

                return null;
              },
            ),

            const Text(
              'Tanggal Mulai',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _selectStartDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                DateFormat('dd MMMM yyyy', 'id_ID')
                    .format(_tanggalMulai),
              ),
            ),

            const SizedBox(height: 16),

            if (tenor > 0 && total > 0 && cicilan > 0)
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rincian Jadwal Cicilan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cicilan pertama: '
                        '${DateFormat('dd MMMM yyyy', 'id_ID').format(
                          _tanggalCicilanPertama,
                        )}',
                      ),
                      Text(
                        'Cicilan terakhir: '
                        '${DateFormat('dd MMMM yyyy', 'id_ID').format(
                          jatuhTempo,
                        )}',
                      ),
                      const Divider(),
                      Text(
                        'Cicilan 1 sampai ${tenor - 1}: '
                        '${_currencyFormat.format(cicilan)}',
                      ),
                      Text(
                        'Cicilan terakhir: '
                        '${_currencyFormat.format(cicilanTerakhir)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total pinjaman: ${_currencyFormat.format(total)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            _buildTextField(
              label: 'Keterangan (Opsional)',
              controller: _keteranganController,
              validator: (_) => null,
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveLoan,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Pinjaman',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
