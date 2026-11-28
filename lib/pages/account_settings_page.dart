
import 'package:flutter/material.dart';

import '../services/account_service.dart';

/// Halaman pengaturan akun keuangan khusus Owner.
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  List<Map<String, dynamic>> _accounts = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  /// Mengambil seluruh akun, termasuk yang nonaktif.
  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AccountService.getAccounts(
        activeOnly: false,
      );

      if (!mounted) return;

      setState(() {
        _accounts = result;
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
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Menampilkan dialog tambah atau edit akun.
  Future<void> _showAccountDialog({
    Map<String, dynamic>? account,
  }) async {
    final isEditing = account != null;

    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(
      text: account?['kode']?.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: account?['nama']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isEditing ? 'Edit Nama Akun' : 'Tambah Akun Baru',
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isEditing) ...[
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'Kode akun',
                        hintText: 'Contoh: bca',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.none,
                      validator: (value) {
                        final code = value?.trim().toLowerCase() ?? '';

                        if (code.isEmpty) {
                          return 'Kode akun wajib diisi.';
                        }

                        if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$')
                            .hasMatch(code)) {
                          return 'Gunakan huruf kecil, angka, '
                              'garis bawah, atau tanda hubung.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama akun',
                      hintText: 'Contoh: BCA',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama akun wajib diisi.';
                      }

                      return null;
                    },
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Kode akun tidak dapat diubah agar '
                      'riwayat transaksi tetap konsisten.',
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
              onPressed: () => Navigator.pop(dialogContext, false),
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

    if (result == true && mounted) {
      try {
        if (isEditing) {
          await AccountService.updateAccount(
            accountId: account['id'].toString(),
            nama: nameController.text.trim(),
          );

          if (!mounted) return;
          _showMessage('Nama akun berhasil diperbarui.');
        } else {
          await AccountService.createAccount(
            kode: codeController.text.trim().toLowerCase(),
            nama: nameController.text.trim(),
          );

          if (!mounted) return;
          _showMessage('Akun baru berhasil ditambahkan.');
        }

        await _loadAccounts();
      } catch (e) {
        if (!mounted) return;
        _showMessage(
          'Gagal menyimpan akun: $e',
          isError: true,
        );
      }
    }

    codeController.dispose();
    nameController.dispose();
  }

  /// Mengaktifkan atau menonaktifkan akun.
  Future<void> _toggleAccount(
    Map<String, dynamic> account,
    bool isActive,
  ) async {
    try {
      await AccountService.setAccountActive(
        accountId: account['id'].toString(),
        isActive: isActive,
      );

      if (!mounted) return;

      _showMessage(
        isActive
            ? 'Akun berhasil diaktifkan.'
            : 'Akun berhasil dinonaktifkan.',
      );

      await _loadAccounts();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal mengubah status akun: $e',
        isError: true,
      );
    }
  }

  /// Membuat kartu untuk satu akun.
  Widget _buildAccountCard(Map<String, dynamic> account) {
    final isActive = account['is_active'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Colors.blue.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.12),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: isActive ? Colors.blue : Colors.grey,
          ),
        ),
        title: Text(
          account['nama']?.toString() ?? '-',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Kode: ${account['kode']} • '
          '${isActive ? 'Aktif' : 'Nonaktif'}',
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.green : Colors.grey,
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Pilihan akun',
          onSelected: (value) {
            if (value == 'edit') {
              _showAccountDialog(account: account);
            } else if (value == 'toggle') {
              _toggleAccount(account, !isActive);
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
                    isActive ? 'Nonaktifkan' : 'Aktifkan kembali',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _accounts
        .where((account) => account['is_active'] == true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Akun'),
        actions: [
          IconButton(
            onPressed: _loadAccounts,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Akun'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          'Gagal mengambil daftar akun:\n$_errorMessage',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAccounts,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAccounts,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance,
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
                                      'Akun Keuangan Rumah Tangga',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '$activeCount akun aktif '
                                      'dari ${_accounts.length} akun',
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
                      const SizedBox(height: 18),
                      const Text(
                        'Daftar Akun',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_accounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'Belum ada akun keuangan.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._accounts.map(_buildAccountCard),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
    );
  }
}
