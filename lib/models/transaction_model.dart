
class TransactionModel {
  final dynamic id;
  final DateTime date;
  final String type;
  final String category;
  final String? categoryId;
  final double amount;
  final String account;
  final String note;

  const TransactionModel({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    this.categoryId,
    required this.amount,
    required this.account,
    required this.note,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      date: DateTime.tryParse('${map['tanggal']}') ?? DateTime.now(),
      type: (map['tipe'] as String? ?? '').trim().toLowerCase(),
      category: map['kategori'] as String? ?? '',
      categoryId: map['category_id']?.toString(),
      amount: (map['jumlah'] as num?)?.toDouble() ?? 0,
      account: (map['akun'] as String? ?? '').trim().toLowerCase(),
      note: map['keterangan'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'tanggal': date.toIso8601String().split('T').first,
        'tipe': type,
        'kategori': category,
        'category_id': categoryId,
        'jumlah': amount,
        'akun': account,
        'keterangan': note,
      };
}
