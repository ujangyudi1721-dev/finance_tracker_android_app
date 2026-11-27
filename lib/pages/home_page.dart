import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/account_config.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'transaction_form_page.dart';
import '../widgets/error_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _limit = 200;
  late Future<List<TransactionModel>> _future;

  final NumberFormat _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _future = TransactionService.getTransactions(limit: _limit);
  }

    /// Load the data again (pull down, or after a change).
  Future<void> _refresh() async {
    final next = TransactionService.getTransactions(limit: _limit);

    setState(() {
      _future = next;
    });

    try {
      await next;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

    Future<void> _openForm({TransactionModel? existing}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormPage(existing: existing),
      ),
    );

    // Always reload when we come back. The data may have been saved even if
    // the form was closed with the back button, or showed an error afterwards.
    await _refresh();
  }

  void _onTap(TransactionModel t) {
    if (t.type == 'transfer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer tidak bisa diubah. Hapus lalu buat lagi.'),
        ),
      );
      return;
    }

    _openForm(existing: t);
  }

  Future<void> _confirmDelete(TransactionModel t) async {
    final isTransfer = t.type == 'transfer';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text(
          isTransfer
              ? 'Kedua sisi transfer (keluar dan masuk) akan dihapus.'
              : '"${t.note.isEmpty ? t.category : t.note}" akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    Object? error;

    try {
      if (isTransfer) {
        await TransactionService.deleteTransfer(t);
      } else {
        await TransactionService.deleteTransaction(t.id);
      }
    } catch (e) {
      error = e;
    }

    // Reload in every case: the delete may have worked even if an error came.
    await _refresh();

    if (error != null && mounted) {
      await showErrorDialog(context, 'Gagal menghapus', error);
    }
  }

  MaterialColor _colorOf(String type) {
    if (type == 'income') return Colors.green;
    if (type == 'expense') return Colors.red;
    return Colors.blue; // transfer
  }

  IconData _iconOf(String type) {
    if (type == 'income') return Icons.arrow_downward;
    if (type == 'expense') return Icons.arrow_upward;
    return Icons.swap_horiz; // transfer
  }

  /// Income "+", expense "-". A transfer already has its own sign.
  String _amountText(TransactionModel t) {
    if (t.type == 'income') return '+${_money.format(t.amount)}';
    if (t.type == 'expense') return '-${_money.format(t.amount)}';
    return t.amount >= 0
        ? '+${_money.format(t.amount)}'
        : _money.format(t.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Tracker')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<TransactionModel>>(
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

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada transaksi.'),
                  ),
                ],
              );
            }

            return ListView.separated(
              // Space at the bottom, so the button does not cover the last row.
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Tap = ubah, tekan lama = hapus',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                }

                final t = items[index - 1];
                final color = _colorOf(t.type);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.shade100,
                    child: Icon(_iconOf(t.type), color: color.shade700),
                  ),
                  title: Text(t.note.isEmpty ? t.category : t.note),
                  subtitle: Text(
                    '${AccountConfig.nameOf(t.account)} • '
                    '${DateFormat('d MMM y').format(t.date)}',
                  ),
                  trailing: Text(
                    _amountText(t),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color.shade700,
                    ),
                  ),
                  onTap: () => _onTap(t),
                  onLongPress: () => _confirmDelete(t),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
