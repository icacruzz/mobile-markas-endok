import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data produksi telur harian.
class ProductionModel {
  final String? id;
  final DateTime tanggal;
  final int tray;
  final int lepas;
  final int rusak;
  final double berat;
  final int? totalButirOverride;
  final String? fotoRusakUrl;
  final String? catatan;
  final DateTime? createdAt;

  ProductionModel({
    this.id,
    required this.tanggal,
    required this.tray,
    required this.lepas,
    required this.rusak,
    required this.berat,
    this.totalButirOverride,
    this.fotoRusakUrl,
    this.catatan,
    this.createdAt,
  });

  int get totalButir => totalButirOverride ?? (tray * 30) + lepas;

  factory ProductionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductionModel(
      id: doc.id,
      tanggal: (data['tanggal'] as Timestamp).toDate(),
      tray: data['tray'] ?? 0,
      lepas: data['lepas'] ?? 0,
      rusak: data['rusak'] ?? 0,
      berat: (data['berat'] ?? 0).toDouble(),
      fotoRusakUrl: data['fotoRusakUrl'],
      catatan: data['catatan'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'tanggal': Timestamp.fromDate(tanggal),
    'tray': tray,
    'lepas': lepas,
    'rusak': rusak,
    'berat': berat,
    'fotoRusakUrl': fotoRusakUrl,
    'catatan': catatan,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
