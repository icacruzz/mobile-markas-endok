import 'package:cloud_firestore/cloud_firestore.dart';

/// Jenis transaksi keuangan
enum TransactionType { pemasukan, pengeluaran }

/// Model data transaksi buku kas.
class TransactionModel {
  final String? id;
  final DateTime tanggal;
  final TransactionType tipe;
  final String kategori;     // Misal: "Penjualan Telur", "Pembelian Pakan", "Listrik & Air"
  final String deskripsi;    // Detail transaksi
  final double jumlah;       // Nominal (Rp)
  final DateTime? createdAt;

  TransactionModel({
    this.id,
    required this.tanggal,
    required this.tipe,
    required this.kategori,
    required this.deskripsi,
    required this.jumlah,
    this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      tanggal: (data['tanggal'] as Timestamp).toDate(),
      tipe: data['tipe'] == 'pemasukan'
          ? TransactionType.pemasukan
          : TransactionType.pengeluaran,
      kategori: data['kategori'] ?? '',
      deskripsi: data['deskripsi'] ?? '',
      jumlah: (data['jumlah'] ?? 0).toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tanggal': Timestamp.fromDate(tanggal),
      'tipe': tipe == TransactionType.pemasukan ? 'pemasukan' : 'pengeluaran',
      'kategori': kategori,
      'deskripsi': deskripsi,
      'jumlah': jumlah,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
