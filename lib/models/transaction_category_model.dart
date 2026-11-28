
class TransactionCategoryModel {
  final String id;
  final String householdId;
  final String name;
  final String type; // income atau expense
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;

  const TransactionCategoryModel({
    required this.id,
    required this.householdId,
    required this.name,
    required this.type,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
  });

  /// Membuat model kategori dari satu baris tabel Supabase.
  factory TransactionCategoryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return TransactionCategoryModel(
      id: map['id']?.toString() ?? '',
      householdId: map['household_id']?.toString() ?? '',
      name: (map['nama'] as String? ?? '').trim(),
      type: (map['tipe'] as String? ?? '').trim().toLowerCase(),
      isActive: map['is_active'] as bool? ?? true,
      createdBy: map['created_by']?.toString(),
      createdAt: DateTime.tryParse(
            '${map['created_at']}',
          ) ??
          DateTime.now(),
    );
  }

  /// Mengubah model menjadi data untuk INSERT Supabase.
  Map<String, dynamic> toInsertMap() {
    return {
      'household_id': householdId,
      'nama': name.trim(),
      'tipe': type,
    };
  }

  /// Mengubah model menjadi data untuk UPDATE Supabase.
  Map<String, dynamic> toUpdateMap() {
    return {
      'nama': name.trim(),
      'is_active': isActive,
    };
  }
}
