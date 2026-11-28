
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_category_model.dart';
import 'household_service.dart';

/// Service untuk mengelola master kategori transaksi.
class TransactionCategoryService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Mengambil kategori berdasarkan rumah tangga.
  ///
  /// type:
  /// - income
  /// - expense
  ///
  /// activeOnly:
  /// - true: hanya kategori aktif.
  /// - false: semua kategori.
  static Future<List<TransactionCategoryModel>> getCategories({
    String? type,
    bool activeOnly = true,
  }) async {
    final household = await HouseholdService.getMyHousehold();

    if (household == null) {
      throw Exception('Rumah tangga tidak ditemukan.');
    }

    final householdId = household['id'].toString();

    var query = _db
        .from('transaction_categories')
        .select()
        .eq('household_id', householdId);

    if (type != null) {
      final normalizedType = type.trim().toLowerCase();

      if (!['income', 'expense'].contains(normalizedType)) {
        throw Exception('Tipe kategori tidak valid.');
      }

      query = query.eq('tipe', normalizedType);
    }

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final result = await query.order('nama');

    return result
        .map(
          (item) => TransactionCategoryModel.fromMap(item),
        )
        .toList();
  }

  /// Menambahkan kategori baru.
  static Future<TransactionCategoryModel> createCategory({
    required String name,
    required String type,
  }) async {
    final normalizedName = name.trim();
    final normalizedType = type.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      throw Exception('Nama kategori tidak boleh kosong.');
    }

    if (!['income', 'expense'].contains(normalizedType)) {
      throw Exception('Tipe kategori tidak valid.');
    }

    final household = await HouseholdService.getMyHousehold();

    if (household == null) {
      throw Exception('Rumah tangga tidak ditemukan.');
    }

    final householdId = household['id'].toString();

    final model = TransactionCategoryModel(
      id: '',
      householdId: householdId,
      name: normalizedName,
      type: normalizedType,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final result = await _db
        .from('transaction_categories')
        .insert(model.toInsertMap())
        .select()
        .single();

    return TransactionCategoryModel.fromMap(result);
  }

  /// Mengubah nama kategori.
  static Future<void> updateCategoryName({
    required String categoryId,
    required String newName,
  }) async {
    final normalizedName = newName.trim();

    if (normalizedName.isEmpty) {
      throw Exception('Nama kategori tidak boleh kosong.');
    }

    final household = await HouseholdService.getMyHousehold();

    if (household == null) {
      throw Exception('Rumah tangga tidak ditemukan.');
    }

    await _db
        .from('transaction_categories')
        .update({
          'nama': normalizedName,
        })
        .eq('id', categoryId)
        .eq('household_id', household['id'].toString());
  }

  /// Mengaktifkan atau menonaktifkan kategori.
  ///
  /// Kategori tidak dihapus secara permanen agar
  /// riwayat transaksi tetap aman.
  static Future<void> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) async {
    final household = await HouseholdService.getMyHousehold();

    if (household == null) {
      throw Exception('Rumah tangga tidak ditemukan.');
    }

    await _db
        .from('transaction_categories')
        .update({
          'is_active': isActive,
        })
        .eq('id', categoryId)
        .eq('household_id', household['id'].toString());
  }
}
