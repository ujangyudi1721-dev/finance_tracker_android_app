class TransactionModel {
  final dynamic id; // a number or a text id, whatever your table uses
  final DateTime date;
  final String type; // income, expense, transfer
  final String category;
  final double amount; // for a transfer: negative = out, positive = in
  final String account; // cash, cimb, neo, sea, bri
  final String note;

  const TransactionModel({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.amount,
    required this.account,
    required this.note,
  });

  /// create a transaksi from one row of the Supabase table.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      date: DateTime.tryParse('${map['tanggal']}') ?? DateTime.now(),
      type: (map['tipe'] as String? ?? '').trim().toLowerCase(),
      category: map['kategori'] as String? ?? '',
      amount: (map['jumlah'] as num?)?.toDouble() ?? 0,
      account: (map['akun'] as String? ?? '').trim().toLowerCase(),
      note: map['keterangan'] as String? ?? '',
    );
  }

  /// Convert to a row for Supabase (used in stage 2)
  Map<String, dynamic> toMap() => {
    'tanggal': date.toIso8601String().split('T').first,
    'tipe': type,
    'kategori': category,
    'jumlah': amount,
    'akun': account,
    'keterangan': note,
  };
}
