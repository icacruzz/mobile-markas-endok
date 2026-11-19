import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data inventaris pakan.
class FeedModel {
  final String? id;
  final DateTime tanggal;
  final double jumlahKg; // Jumlah pakan yang dibeli (kg)
  final double harga; // Total harga pembelian (Rp)
  final double hargaPerKg;
  final String jenisPakan;
  final String? keterangan; // Catatan pembelian
  final String? fotoNotaBase64;
  final String? fotoNotaUrl; // Legacy Firebase Storage URL.
  final DateTime? createdAt;

  FeedModel({
    this.id,
    required this.tanggal,
    required this.jumlahKg,
    required this.harga,
    this.hargaPerKg = 0,
    this.jenisPakan = 'Pakan Layer A',
    this.keterangan,
    this.fotoNotaBase64,
    this.fotoNotaUrl,
    this.createdAt,
  });

  bool get hasFotoNota =>
      (fotoNotaBase64?.isNotEmpty ?? false) ||
      (fotoNotaUrl?.isNotEmpty ?? false);

  factory FeedModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedModel(
      id: doc.id,
      tanggal: (data['tanggal'] as Timestamp).toDate(),
      jumlahKg: (data['jumlahKg'] ?? 0).toDouble(),
      harga: (data['harga'] ?? 0).toDouble(),
      hargaPerKg: (data['hargaPerKg'] ?? 0).toDouble(),
      jenisPakan: data['jenisPakan'] ?? 'Pakan Layer A',
      keterangan: data['keterangan'],
      fotoNotaBase64: data['fotoNotaBase64'],
      fotoNotaUrl: data['fotoNotaUrl'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tanggal': Timestamp.fromDate(tanggal),
      'jumlahKg': jumlahKg,
      'harga': harga,
      'hargaPerKg': hargaPerKg,
      'jenisPakan': jenisPakan,
      'keterangan': keterangan,
      'fotoNotaBase64': fotoNotaBase64,
      'fotoNotaUrl': fotoNotaUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
