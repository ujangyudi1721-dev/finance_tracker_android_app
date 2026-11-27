import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/account_config.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../widgets/error_dialog.dart';

/// One form for adding AND editing. Give it [existing] to edit.
class TransactionFormPage extends StatefulWidget {
  final TransactionModel? existing;

  const TransactionFormPage({super.key, this.existing});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  late String _type;
  late DateTime _date;
  late String _account;
  String _toAccount = 'cimb';
  String _category = '';

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<String> _categories = []; // suggestions from your own history
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final t = widget.existing;
    _type = t?.type ?? 'expense';
    _date = t?.date ?? DateTime.now();
    _account = (t != null && AccountConfig.accounts.containsKey(t.account))
        ? t.account
        : 'cash';
    _category = t?.category ?? '';
    _noteController.text = t?.note ?? '';

    if (t != null) {
      // 25000.0 -> "25000", 25000.5 -> "25000.5"
      _amountController.text =
          t.amount == t.amount.roundToDouble()
              ? t.amount.toStringAsFixed(0)
              : t.amount.toString();
    }

    TransactionService.getCategories().then((list) {
      if (!mounted) return;
      setState(() => _categories = list);
    }).catchError((_) {
      // Suggestions are only a help. The form works without them.
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    if (amount == null || amount <= 0) {
      _showMessage('Isi nominal dengan benar.');
      return;
    }

    if (_type == 'transfer') {
      if (_account == _toAccount) {
        _showMessage('Akun asal dan akun tujuan tidak boleh sama.');
        return;
      }
    } else if (_category.trim().isEmpty) {
      _showMessage('Isi kategori.');
      return;
    }

    setState(() => _saving = true);

    try {
      if (_type == 'transfer') {
        await TransactionService.createTransfer(
          date: _date,
          fromAccount: _account,
          toAccount: _toAccount,
          amount: amount,
        );
      } else {
        final entry = TransactionModel(
          id: widget.existing?.id,
          date: _date,
          type: _type,
          category: _category.trim(),
          amount: amount,
          account: _account,
          note: _noteController.text.trim(),
        );

        if (_isEdit) {
          await TransactionService.updateTransaction(entry);
        } else {
          await TransactionService.createTransaction(entry);
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true); // go back and say "saved"
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showErrorDialog(context, 'Gagal menyimpan', e);
    }
  }

  /// A row of account chips (Cash, CIMB, ...).
  Widget _accountChips({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AccountConfig.accounts.entries.map((entry) {
        return ChoiceChip(
          label: Text(entry.value),
          selected: selected == entry.key,
          onSelected: (_) => onSelected(entry.key),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = _type == 'transfer';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah transaksi' : 'Tambah transaksi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Type. A transfer cannot be edited, so it is only for new ones.
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'income', label: Text('Pemasukan')),
              const ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
              if (!_isEdit)
                const ButtonSegment(value: 'transfer', label: Text('Transfer')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),

          // Date
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(DateFormat('EEEE, d MMM y').format(_date)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),

          // Amount
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Category + note (not for transfers)
          if (!isTransfer) ...[
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _category),
              optionsBuilder: (value) {
                final text = value.text.trim().toLowerCase();
                if (text.isEmpty) return _categories.take(8);
                return _categories.where((c) => c.toLowerCase().contains(text));
              },
              onSelected: (selection) => _category = selection,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (text) => _category = text,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    helperText: 'Ketik, atau pilih dari yang pernah dipakai',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Accounts
          Text(isTransfer ? 'Dari akun' : 'Akun'),
          const SizedBox(height: 8),
          _accountChips(
            selected: _account,
            onSelected: (key) => setState(() => _account = key),
          ),

          if (isTransfer) ...[
            const SizedBox(height: 16),
            const Text('Ke akun'),
            const SizedBox(height: 8),
            _accountChips(
              selected: _toAccount,
              onSelected: (key) => setState(() => _toAccount = key),
            ),
          ],

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ),
        ],
      ),
    );
  }
}