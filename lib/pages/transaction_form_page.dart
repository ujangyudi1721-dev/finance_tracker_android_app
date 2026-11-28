
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../models/transaction_category_model.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../services/transaction_category_service.dart';
import '../widgets/error_dialog.dart';

class TransactionFormPage extends StatefulWidget {
  final TransactionModel? existing;

  const TransactionFormPage({
    super.key,
    this.existing,
  });

  @override
  State<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  late String _type;
  late DateTime _date;
  late String _account;

  String _toAccount = 'cimb';
  String? _selectedCategoryId;

  List<Map<String, dynamic>> _accounts = [];
  List<TransactionCategoryModel> _categories = [];

  bool _accountsLoading = true;
  bool _categoriesLoading = true;
  bool _saving = false;

  String? _accountsError;
  String? _categoriesError;

  int _categoryLoadToken = 0;

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _noteController =
      TextEditingController();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final t = widget.existing;

    _type = t?.type ?? 'expense';
    _date = t?.date ?? DateTime.now();
    _account = t?.account ?? 'cash';

    _selectedCategoryId = t?.categoryId;
    _noteController.text = t?.note ?? '';

    if (t != null) {
      _amountController.text =
          t.amount == t.amount.roundToDouble()
              ? t.amount.toStringAsFixed(0)
              : t.amount.toString();
    }

    _loadAccounts();
    _loadCategories();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await AccountService.getAccounts(
        activeOnly: false,
      );

      if (!mounted) return;

      final existingAccount = widget.existing?.account;

      if (existingAccount != null &&
          !accounts.any(
            (account) =>
                account['kode']?.toString() == existingAccount,
          )) {
        accounts.add({
          'kode': existingAccount,
          'nama': existingAccount,
          'is_active': false,
        });
      }

      final activeAccounts = accounts.where(
        (account) => account['is_active'] == true,
      ).toList();

      setState(() {
        _accounts = accounts;
        _accountsLoading = false;
        _accountsError = null;

        if (!_isEdit && activeAccounts.isNotEmpty) {
          _account = activeAccounts.first['kode'].toString();
        }

        final otherAccounts = activeAccounts.where(
          (account) =>
              account['kode'].toString() != _account,
        );

        if (otherAccounts.isNotEmpty) {
          _toAccount = otherAccounts.first['kode'].toString();
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _accountsLoading = false;
        _accountsError = e.toString();
      });
    }
  }

  Future<void> _loadCategories() async {
    final requestToken = ++_categoryLoadToken;

    if (_type == 'transfer') {
      if (!mounted) return;

      setState(() {
        _categories = [];
        _categoriesLoading = false;
        _categoriesError = null;
        _selectedCategoryId = null;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _categoriesLoading = true;
        _categoriesError = null;
      });
    }

    try {
      final result =
          await TransactionCategoryService.getCategories(
        type: _type,
        activeOnly: false,
      );

      if (!mounted || requestToken != _categoryLoadToken) {
        return;
      }

      final original = widget.existing;

      final isOriginalType =
          original != null && original.type == _type;

      TransactionCategoryModel? previousCategory;

      if (isOriginalType) {
        for (final category in result) {
          if (original.categoryId != null &&
              category.id == original.categoryId) {
            previousCategory = category;
            break;
          }

          if (original.categoryId == null &&
              category.name.toLowerCase() ==
                  original.category.trim().toLowerCase()) {
            previousCategory = category;
            break;
          }
        }
      }

      final availableCategories = result.where((category) {
        return category.isActive ||
            (previousCategory != null &&
                category.id == previousCategory.id);
      }).toList();

      String? selectedId;

      if (previousCategory != null &&
          availableCategories.any(
            (category) => category.id == previousCategory!.id,
          )) {
        selectedId = previousCategory.id;
      } else if (availableCategories.isNotEmpty) {
        selectedId = availableCategories.first.id;
      }

      setState(() {
        _categories = availableCategories;
        _selectedCategoryId = selectedId;
        _categoriesLoading = false;
        _categoriesError = null;
      });
    } catch (e) {
      if (!mounted || requestToken != _categoryLoadToken) {
        return;
      }

      setState(() {
        _categories = [];
        _categoriesLoading = false;
        _categoriesError = e.toString();
      });
    }
  }

  Future<void> _changeType(String type) async {
    if (type == _type) return;

    setState(() {
      _type = type;
      _selectedCategoryId = null;
    });

    await _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  String _accountName(String code) {
    for (final account in _accounts) {
      if (account['kode']?.toString() == code) {
        return account['nama']?.toString() ?? code;
      }
    }

    return code;
  }

  bool _isAccountActive(String code) {
    for (final account in _accounts) {
      if (account['kode']?.toString() == code) {
        return account['is_active'] == true;
      }
    }

    return false;
  }

  void _showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String? _validateForm(double? amount) {
    if (amount == null) {
      return 'Isi nominal dengan angka yang benar.';
    }

    if (!amount.isFinite) {
      return 'Nominal transaksi tidak valid.';
    }

    if (amount <= 0) {
      return 'Nominal transaksi harus lebih besar dari nol.';
    }

    if (!['income', 'expense', 'transfer'].contains(_type)) {
      return 'Jenis transaksi tidak dikenal.';
    }

    if (!_accounts.any(
      (account) => account['kode']?.toString() == _account,
    )) {
      return 'Rekening yang dipilih tidak valid.';
    }

    final isOriginalInactiveAccount = _isEdit &&
        widget.existing?.account == _account &&
        !_isAccountActive(_account);

    if (!_isAccountActive(_account) &&
        !isOriginalInactiveAccount) {
      return 'Akun yang dipilih sudah tidak aktif.';
    }

    if (_type == 'transfer') {
      if (!_isAccountActive(_toAccount)) {
        return 'Rekening tujuan tidak aktif atau tidak valid.';
      }

      if (_account == _toAccount) {
        return 'Akun asal dan akun tujuan tidak boleh sama.';
      }
    } else {
      if (_selectedCategoryId == null ||
          !_categories.any(
            (category) =>
                category.id == _selectedCategoryId &&
                category.type == _type,
          )) {
        return 'Silakan pilih kategori transaksi.';
      }
    }

    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_accountsLoading) {
      _showMessage('Mohon tunggu, daftar akun sedang dimuat.');
      return;
    }

    if (_categoriesLoading && _type != 'transfer') {
      _showMessage('Mohon tunggu, daftar kategori sedang dimuat.');
      return;
    }

    if (_accountsError != null) {
      _showMessage('Daftar akun belum berhasil dimuat.');
      return;
    }

    if (_categoriesError != null && _type != 'transfer') {
      _showMessage('Daftar kategori belum berhasil dimuat.');
      return;
    }

    if (_accounts.isEmpty) {
      _showMessage('Belum ada akun yang tersedia.');
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    final validationMessage = _validateForm(amount);

    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (_type == 'transfer') {
        await TransactionService.createTransfer(
          date: _date,
          fromAccount: _account,
          toAccount: _toAccount,
          amount: amount!,
        );
      } else {
        final selectedCategory = _categories.firstWhere(
          (category) => category.id == _selectedCategoryId,
        );

        final entry = TransactionModel(
          id: widget.existing?.id,
          date: _date,
          type: _type,
          category: selectedCategory.name,
          categoryId: selectedCategory.id,
          amount: amount!,
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

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      await showErrorDialog(
        context,
        'Gagal menyimpan',
        e,
      );
    }
  }

  Widget _accountChips({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    final availableAccounts = _accounts.where((account) {
      final code = account['kode']?.toString() ?? '';
      final isActive = account['is_active'] == true;

      return isActive || code == selected;
    }).toList();

    if (availableAccounts.isEmpty) {
      return const Text(
        'Belum ada akun aktif. Silakan hubungi Owner untuk menambahkan akun.',
        style: TextStyle(color: Colors.red),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableAccounts.map((account) {
        final code = account['kode'].toString();
        final name = _accountName(code);
        final isActive = account['is_active'] == true;

        return ChoiceChip(
          label: Text(
            isActive ? name : '$name (Nonaktif)',
          ),
          selected: selected == code,
          onSelected: (_) => onSelected(code),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryDropdown() {
    if (_categoriesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_categoriesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gagal memuat kategori.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(
            _categoriesError!,
            style: const TextStyle(fontSize: 12),
          ),
          TextButton.icon(
            onPressed: _loadCategories,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      );
    }

    if (_categories.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Kategori',
          border: OutlineInputBorder(),
        ),
        child: Text(
          'Belum ada kategori aktif. '
          'Hubungi Owner untuk menambahkan kategori.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(
        '$_type-$_selectedCategoryId-${_categories.length}',
      ),
      initialValue: _categories.any(
        (category) => category.id == _selectedCategoryId,
      )
          ? _selectedCategoryId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kategori',
        border: OutlineInputBorder(),
      ),
      hint: const Text('Pilih kategori'),
      items: _categories.map((category) {
        return DropdownMenuItem<String>(
          value: category.id,
          child: Text(
            category.isActive
                ? category.name
                : '${category.name} (Nonaktif)',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _selectedCategoryId = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = _type == 'transfer';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Ubah transaksi' : 'Tambah transaksi',
        ),
      ),
      body: _accountsLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _accountsError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gagal memuat daftar akun.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _accountsError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _accountsLoading = true;
                              _accountsError = null;
                            });
                            _loadAccounts();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _accounts.where(
                    (account) => account['is_active'] == true,
                  ).isEmpty &&
                  !_isEdit
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada akun aktif.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Hubungi Owner untuk menambahkan atau mengaktifkan akun.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SegmentedButton<String>(
                          segments: [
                            const ButtonSegment(
                              value: 'income',
                              label: Text('Pemasukan'),
                            ),
                            const ButtonSegment(
                              value: 'expense',
                              label: Text('Pengeluaran'),
                            ),
                            if (!_isEdit)
                              const ButtonSegment(
                                value: 'transfer',
                                label: Text('Transfer'),
                              ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (selection) {
                            _changeType(selection.first);
                          },
                        ),

                        const SizedBox(height: 16),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            DateFormat('EEEE, d MMM y').format(_date),
                          ),
                          trailing: const Icon(Icons.edit_calendar),
                          onTap: _pickDate,
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: _amountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                            helperText:
                                'Contoh: 100000 atau 100000.50',
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (!isTransfer) ...[
                          _buildCategoryDropdown(),

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

                        Text(
                          isTransfer ? 'Dari akun' : 'Akun',
                        ),

                        const SizedBox(height: 8),

                        _accountChips(
                          selected: _account,
                          onSelected: (key) {
                            setState(() {
                              _account = key;

                              if (_account == _toAccount) {
                                final otherAccount =
                                    _accounts.firstWhere(
                                  (account) =>
                                      account['is_active'] == true &&
                                      account['kode'].toString() !=
                                          _account,
                                  orElse: () => <String, dynamic>{},
                                );

                                if (otherAccount.isNotEmpty) {
                                  _toAccount =
                                      otherAccount['kode'].toString();
                                }
                              }
                            });
                          },
                        ),

                        if (isTransfer) ...[
                          const SizedBox(height: 16),
                          const Text('Ke akun'),
                          const SizedBox(height: 8),
                          _accountChips(
                            selected: _toAccount,
                            onSelected: (key) {
                              setState(() {
                                _toAccount = key;
                              });
                            },
                          ),
                        ],

                        const SizedBox(height: 24),

                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            child: Text(
                              _saving ? 'Menyimpan...' : 'Simpan',
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
