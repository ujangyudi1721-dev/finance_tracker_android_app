
import 'package:flutter/material.dart';

import '../models/transaction_category_model.dart';
import '../services/transaction_category_service.dart';

/// Halaman pengaturan kategori pemasukan dan pengeluaran.
class TransactionCategoriesPage extends StatefulWidget {
  const TransactionCategoriesPage({super.key});

  @override
  State<TransactionCategoriesPage> createState() =>
      _TransactionCategoriesPageState();
}

class _TransactionCategoriesPageState
    extends State<TransactionCategoriesPage> {
  List<TransactionCategoryModel> _categories = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  /// Mengambil seluruh kategori, termasuk yang nonaktif.
  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result =
          await TransactionCategoryService.getCategories(
        activeOnly: false,
      );

      if (!mounted) return;

      setState(() {
        _categories = result;
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

  /// Menampilkan notifikasi.
  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Menampilkan dialog tambah atau edit kategori.
  Future<void> _showCategoryDialog({
    TransactionCategoryModel? category,
    required String type,
  }) async {
    final isEditing = category != null;
    final formKey = GlobalKey<FormState>();

    String categoryName = category?.name ?? '';
    String selectedType = category?.type ?? type;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Edit Nama Kategori'
                    : 'Tambah Kategori',
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isEditing) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Jenis kategori',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'income',
                              child: Text('Pemasukan'),
                            ),
                            DropdownMenuItem(
                              value: 'expense',
                              child: Text('Pengeluaran'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              selectedType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        initialValue: categoryName,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Nama kategori',
                          hintText: 'Contoh: Belanja Bulanan',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization:
                            TextCapitalization.words,
                        onChanged: (value) {
                          categoryName = value;
                        },
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Nama kategori wajib diisi.';
                          }

                          return null;
                        },
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Perubahan nama tidak menghapus '
                          'riwayat transaksi sebelumnya.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: Text(isEditing ? 'Simpan' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    try {
      if (isEditing) {
        await TransactionCategoryService.updateCategoryName(
          categoryId: category.id,
          newName: categoryName,
        );

        if (!mounted) return;

        _showMessage('Nama kategori berhasil diperbarui.');
      } else {
        await TransactionCategoryService.createCategory(
          name: categoryName,
          type: selectedType,
        );

        if (!mounted) return;

        _showMessage('Kategori baru berhasil ditambahkan.');
      }

      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString().toLowerCase();

      if (errorText.contains('duplicate') ||
          errorText.contains('unique')) {
        _showMessage(
          'Nama kategori tersebut sudah digunakan.',
          isError: true,
        );
      } else {
        _showMessage(
          'Gagal menyimpan kategori: $e',
          isError: true,
        );
      }
    }
  }

  /// Mengaktifkan atau menonaktifkan kategori.
  Future<void> _toggleCategory(
    TransactionCategoryModel category,
    bool isActive,
  ) async {
    try {
      await TransactionCategoryService.setCategoryActive(
        categoryId: category.id,
        isActive: isActive,
      );

      if (!mounted) return;

      _showMessage(
        isActive
            ? 'Kategori berhasil diaktifkan.'
            : 'Kategori berhasil dinonaktifkan.',
      );

      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal mengubah status kategori: $e',
        isError: true,
      );
    }
  }

  /// Membuat kartu kategori.
  Widget _buildCategoryCard(
    TransactionCategoryModel category,
  ) {
    final isActive = category.isActive;
    final isIncome = category.type == 'income';

    final color = isIncome ? Colors.green : Colors.orange;
    final icon = isIncome
        ? Icons.trending_up
        : Icons.trending_down;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.12),
          child: Icon(
            icon,
            color: isActive ? color : Colors.grey,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          isActive ? 'Aktif' : 'Nonaktif',
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.green : Colors.grey,
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Pilihan kategori',
          onSelected: (value) {
            if (value == 'edit') {
              _showCategoryDialog(
                category: category,
                type: category.type,
              );
            } else if (value == 'toggle') {
              _toggleCategory(category, !isActive);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Edit nama'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isActive
                        ? 'Nonaktifkan'
                        : 'Aktifkan kembali',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membuat bagian daftar kategori berdasarkan jenisnya.
  Widget _buildCategorySection({
    required String title,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    final categories = _categories
        .where((category) => category.type == type)
        .toList();

    final activeCount =
        categories.where((category) => category.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '$activeCount aktif',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            IconButton(
              tooltip: 'Tambah $title',
              onPressed: () {
                _showCategoryDialog(type: type);
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 20,
            ),
            child: Text(
              'Belum ada kategori.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ...categories.map(_buildCategoryCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _categories.where((category) => category.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Kategori'),
        actions: [
          IconButton(
            onPressed: _loadCategories,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal mengambil daftar kategori:\n'
                          '$_errorMessage',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCategories,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.category_outlined,
                                size: 36,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Kategori Keuangan Rumah Tangga',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '$activeCount kategori aktif '
                                      'dari ${_categories.length} kategori',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildCategorySection(
                        title: 'Pemasukan',
                        type: 'income',
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 20),
                      _buildCategorySection(
                        title: 'Pengeluaran',
                        type: 'expense',
                        icon: Icons.trending_down,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 30),
                      const Card(
                        elevation: 0,
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Kategori yang sudah digunakan '
                                  'dalam transaksi tidak dihapus '
                                  'secara permanen. Nonaktifkan '
                                  'kategori agar tidak muncul saat '
                                  'mencatat transaksi baru.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
