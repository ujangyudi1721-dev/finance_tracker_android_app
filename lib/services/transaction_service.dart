import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';

class TransactionService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// "2026-11-27T10:30:00" -> "2026-11-27"
  static String _day(DateTime date) => date.toIso8601String().split('T').first;

  // ==========================================================================
  // READ
  // ==========================================================================

  /// All transactions, newest first. Use [limit] to get only the latest ones.
  static Future<List<TransactionModel>> getTransactions({int? limit}) async {
    final query = _db
        .from('transactions')
        .select()
        .order('tanggal', ascending: false)
        .order('id', ascending: false);

    final rows = limit == null ? await query : await query.limit(limit);

    return rows.map((row) => TransactionModel.fromMap(row)).toList();
  }

  /// The categories you used before (not transfer), most used first.
  static Future<List<String>> getCategories() async {
    final rows = await _db.from('transactions').select('kategori, tipe');

    final Map<String, int> counts = {};
    for (final row in rows) {
      final type = (row['tipe'] as String? ?? '').trim().toLowerCase();
      if (type == 'transfer') continue;

      final name = (row['kategori'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      counts[name] = (counts[name] ?? 0) + 1;
    }

    final names = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return names;
  }

  // ============================================================
  // CREATE
  // ============================================================

  static Future<void> createTransaction(TransactionModel t) async {
    await _db.from('transactions').insert(t.toMap());
  }

  /// A transfer is saved as TWO rows, exactly like the website:
  /// one negative row (money out) and one positive row (money in).
  static Future<void> createTransfer({
    required DateTime date,
    required String fromAccount,
    required String toAccount,
    required double amount,
  }) async {
    final day = _day(date);

    await _db.from('transactions').insert([
      {
        'tanggal': day,
        'tipe': 'transfer',
        'kategori': 'transfer',
        'jumlah': -amount,
        'keterangan': 'Transfer ke $toAccount',
        'akun': fromAccount,
      },
      {
        'tanggal': day,
        'tipe': 'transfer',
        'kategori': 'transfer',
        'jumlah': amount,
        'keterangan': 'Transfer dari $fromAccount',
        'akun': toAccount,
      },
    ]);
  }

  // ============================================================
  // UPDATE
  // ============================================================

  static Future<void> updateTransaction(TransactionModel t) async {
    final rows = await _db
        .from('transactions')
        .update(t.toMap())
        .eq('id', t.id)
        .select();

    // Supabase says "OK" even when a security rule blocks the change and
    // 0 rows are updated. We check, so you never think it was saved.
    if (rows.isEmpty) {
      throw Exception(
        'Tidak ada data yang diubah. Cek izin (RLS) di Supabase.',
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<void> deleteTransaction(dynamic id) async {
    final rows = await _db.from('transactions').delete().eq('id', id).select();

    if (rows.isEmpty) {
      throw Exception(
        'Tidak ada data yang dihapus. Cek izin (RLS) di Supabase.',
      );
    }
  }

  /// Delete a transfer: BOTH rows together (money out and money in).
  /// If only one row was deleted, the balances of two accounts would be wrong.
  static Future<void> deleteTransfer(TransactionModel t) async {
    final isOut = t.amount < 0;
    final prefix = isOut ? 'Transfer ke ' : 'Transfer dari ';

    final ids = <dynamic>[t.id];

    // The note says which account is on the other side:
    // "Transfer ke cimb" -> the other row belongs to "cimb".
    if (t.note.startsWith(prefix)) {
      final otherAccount = t.note.substring(prefix.length).trim().toLowerCase();
      final otherNote = isOut
          ? 'Transfer dari ${t.account}'
          : 'Transfer ke ${t.account}';

      final others = await _db
          .from('transactions')
          .select('id')
          .eq('tipe', 'transfer')
          .eq('tanggal', _day(t.date))
          .eq('akun', otherAccount)
          .eq('jumlah', -t.amount)
          .eq('keterangan', otherNote)
          .limit(1);

      if (others.isNotEmpty) ids.add(others.first['id']);
    }

    final rows = await _db
        .from('transactions')
        .delete()
        .inFilter('id', ids)
        .select();

    if (rows.isEmpty) {
      throw Exception(
        'Tidak ada data yang dihapus. Cek izin (RLS) di Supabase.',
      );
    }
  }
}
