
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction_model.dart';
import 'household_service.dart';

/// Service untuk mengelola transaksi keuangan rumah tangga.
class TransactionService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Generator UUID untuk mengelompokkan dua baris transfer.
  static const Uuid _uuid = Uuid();

  /// Mengubah tanggal menjadi format YYYY-MM-DD.
  static String _day(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  /// Mengambil identitas rumah tangga dan pengguna yang sedang login.
  static Future<Map<String, String>> _getHouseholdContext() async {
    final user = _db.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final household = await HouseholdService.getMyHousehold();

    if (household == null || household['id'] == null) {
      throw Exception('Rumah tangga belum ditemukan.');
    }

    return {
      'household_id': household['id'].toString(),
      'created_by': user.id,
    };
  }

  /// Memastikan kategori sesuai dengan rumah tangga dan jenis transaksi.
  ///
  /// Kategori nonaktif hanya boleh dipertahankan ketika mengedit
  /// transaksi yang sebelumnya memang menggunakan kategori tersebut.
  static Future<void> _validateCategory({
    required String categoryId,
    required String type,
    required String householdId,
    String? previousCategoryId,
  }) async {
    if (categoryId.trim().isEmpty) {
      throw Exception('Silakan pilih kategori transaksi.');
    }

    if (!['income', 'expense'].contains(type)) {
      throw Exception('Jenis transaksi tidak valid.');
    }

    final category = await _db
        .from('transaction_categories')
        .select('id, nama, tipe, is_active')
        .eq('id', categoryId)
        .eq('household_id', householdId)
        .maybeSingle();

    if (category == null) {
      throw Exception(
        'Kategori tidak ditemukan atau bukan milik rumah tangga ini.',
      );
    }

    if (category['tipe'] != type) {
      throw Exception(
        'Jenis kategori tidak sesuai dengan jenis transaksi.',
      );
    }

    final isActive = category['is_active'] == true;
    final isPreviousCategory = previousCategoryId == categoryId;

    if (!isActive && !isPreviousCategory) {
      throw Exception(
        'Kategori tersebut sudah nonaktif. '
        'Silakan pilih kategori yang masih aktif.',
      );
    }
  }

  /// Menyiapkan data transaksi dengan identitas rumah tangga.
  static Future<Map<String, dynamic>> _prepareTransactionData(
    TransactionModel transaction,
  ) async {
    final context = await _getHouseholdContext();

    await _validateCategory(
      categoryId: transaction.categoryId ?? '',
      type: transaction.type,
      householdId: context['household_id']!,
    );

    final data = Map<String, dynamic>.from(transaction.toMap());

    data.remove('id');
    data.remove('household_id');
    data.remove('created_by');

    data['household_id'] = context['household_id'];
    data['created_by'] = context['created_by'];

    return data;
  }

  // ==========================================================================
  // READ
  // ==========================================================================

  /// Mengambil transaksi rumah tangga, dimulai dari tanggal terbaru.
  static Future<List<TransactionModel>> getTransactions({
    int? limit,
  }) async {
    final context = await _getHouseholdContext();

    var query = _db
        .from('transactions')
        .select()
        .eq('household_id', context['household_id']!)
        .order('tanggal', ascending: false)
        .order('id', ascending: false);

    final rows = limit == null ? await query : await query.limit(limit);

    return rows.map((row) => TransactionModel.fromMap(row)).toList();
  }

  /// Mengambil seluruh transaksi rumah tangga secara bertahap.
  static Future<List<TransactionModel>> getAllTransactions() async {
    const pageSize = 1000;

    final context = await _getHouseholdContext();
    final List<TransactionModel> all = [];

    var from = 0;

    while (true) {
      final rows = await _db
          .from('transactions')
          .select()
          .eq('household_id', context['household_id']!)
          .order('tanggal', ascending: false)
          .order('id', ascending: false)
          .range(from, from + pageSize - 1);

      if (rows.isEmpty) {
        break;
      }

      all.addAll(rows.map((row) => TransactionModel.fromMap(row)));

      from += rows.length;
    }

    return all;
  }

  /// Mengambil kategori transaksi yang pernah digunakan.
  ///
  /// Dipertahankan untuk kompatibilitas dengan pemanggil lama.
  /// Formulir transaksi baru menggunakan TransactionCategoryService.
  static Future<List<String>> getCategories() async {
    final context = await _getHouseholdContext();

    final rows = await _db
        .from('transactions')
        .select('kategori, tipe')
        .eq('household_id', context['household_id']!);

    final Map<String, int> counts = {};

    for (final row in rows) {
      final type = (row['tipe'] as String? ?? '').trim().toLowerCase();

      if (type == 'transfer') {
        continue;
      }

      final name = (row['kategori'] as String? ?? '').trim();

      if (name.isEmpty) {
        continue;
      }

      counts[name] = (counts[name] ?? 0) + 1;
    }

    final names = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return names;
  }

  // ==========================================================================
  // CREATE
  // ==========================================================================

  /// Menambahkan transaksi baru ke rumah tangga pengguna.
  static Future<void> createTransaction(
    TransactionModel transaction,
  ) async {
    if (transaction.type == 'transfer') {
      throw Exception(
        'Gunakan fungsi createTransfer untuk transaksi transfer.',
      );
    }

    final data = await _prepareTransactionData(transaction);

    await _db.from('transactions').insert(data);
  }

  /// Menyimpan transfer sebagai dua baris transaksi.
  ///
  /// Kedua baris memiliki transfer_group_id yang sama.
  static Future<void> createTransfer({
    required DateTime date,
    required String fromAccount,
    required String toAccount,
    required double amount,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw Exception('Jumlah transfer harus lebih dari nol.');
    }

    if (fromAccount == toAccount) {
      throw Exception('Akun asal dan tujuan tidak boleh sama.');
    }

    final context = await _getHouseholdContext();
    final transferGroupId = _uuid.v4();
    final day = _day(date);

    await _db.from('transactions').insert([
      {
        'tanggal': day,
        'tipe': 'transfer',
        'kategori': 'transfer',
        'category_id': null,
        'jumlah': -amount,
        'keterangan': 'Transfer ke $toAccount',
        'akun': fromAccount,
        'household_id': context['household_id'],
        'created_by': context['created_by'],
        'transfer_group_id': transferGroupId,
      },
      {
        'tanggal': day,
        'tipe': 'transfer',
        'kategori': 'transfer',
        'category_id': null,
        'jumlah': amount,
        'keterangan': 'Transfer dari $fromAccount',
        'akun': toAccount,
        'household_id': context['household_id'],
        'created_by': context['created_by'],
        'transfer_group_id': transferGroupId,
      },
    ]);
  }

  // ==========================================================================
  // UPDATE
  // ==========================================================================

  /// Mengubah transaksi yang berada dalam rumah tangga pengguna.
  static Future<void> updateTransaction(
    TransactionModel transaction,
  ) async {
    if (transaction.type == 'transfer') {
      throw Exception(
        'Transaksi transfer tidak dapat diubah melalui formulir ini.',
      );
    }

    final context = await _getHouseholdContext();
    final householdId = context['household_id']!;

    // Memastikan transaksi memang ada dan mengambil kategori sebelumnya.
    final existingRows = await _db
        .from('transactions')
        .select('id, category_id')
        .eq('id', transaction.id)
        .eq('household_id', householdId)
        .maybeSingle();

    if (existingRows == null) {
      throw Exception(
        'Transaksi tidak ditemukan atau bukan milik rumah tangga ini.',
      );
    }

    final previousCategoryId =
        existingRows['category_id']?.toString();

    await _validateCategory(
      categoryId: transaction.categoryId ?? '',
      type: transaction.type,
      householdId: householdId,
      previousCategoryId: previousCategoryId,
    );

    final data = Map<String, dynamic>.from(transaction.toMap());

    data.remove('id');
    data.remove('household_id');
    data.remove('created_by');

    final rows = await _db
        .from('transactions')
        .update(data)
        .eq('id', transaction.id)
        .eq('household_id', householdId)
        .select();

    if (rows.isEmpty) {
      throw Exception(
        'Tidak ada data yang diubah. Periksa transaksi dan izin akses.',
      );
    }
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  /// Menghapus satu transaksi dari rumah tangga pengguna.
  static Future<void> deleteTransaction(dynamic id) async {
    final context = await _getHouseholdContext();

    final rows = await _db
        .from('transactions')
        .delete()
        .eq('id', id)
        .eq('household_id', context['household_id']!)
        .select();

    if (rows.isEmpty) {
      throw Exception(
        'Tidak ada data yang dihapus. Periksa transaksi dan izin akses.',
      );
    }
  }

  /// Menghapus kedua baris transfer berdasarkan UUID kelompok.
  static Future<void> deleteTransfer(
    TransactionModel transaction,
  ) async {
    final context = await _getHouseholdContext();

    final currentRows = await _db
        .from('transactions')
        .select('transfer_group_id')
        .eq('id', transaction.id)
        .eq('household_id', context['household_id']!)
        .eq('tipe', 'transfer')
        .limit(1);

    if (currentRows.isEmpty) {
      throw Exception('Transaksi transfer tidak ditemukan.');
    }

    final groupId = currentRows.first['transfer_group_id'];

    if (groupId == null) {
      throw Exception(
        'Transfer ini merupakan data lama. '
        'Pasangan transfer belum memiliki ID kelompok.',
      );
    }

    final rows = await _db
        .from('transactions')
        .delete()
        .eq('household_id', context['household_id']!)
        .eq('transfer_group_id', groupId)
        .select();

    if (rows.length != 2) {
      throw Exception(
        'Pasangan transfer tidak lengkap. '
        'Periksa data transfer di Supabase.',
      );
    }
  }
}
