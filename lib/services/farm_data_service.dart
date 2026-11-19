import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/feed_model.dart';
import '../models/production_model.dart';
import '../models/transaction_model.dart';

/// Firestore repositories for the three operational record types.
class FarmDataService {
  FarmDataService._();
  static final instance = FarmDataService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productions =>
      _db.collection('productions');
  CollectionReference<Map<String, dynamic>> get _feeds =>
      _db.collection('feeds');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _feedUsage =>
      _db.collection('feed_usage');

  Stream<List<Map<String, dynamic>>> watchFeedUsage() => _feedUsage
      .orderBy('tanggal', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> saveFeedUsage(DateTime date, double kg, {String? id}) async {
    final day = DateTime(date.year, date.month, date.day);
    final nextDay = day.add(const Duration(days: 1));
    final sameDay = await _feedUsage
        .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
        .where('tanggal', isLessThan: Timestamp.fromDate(nextDay))
        .get();
    DocumentReference<Map<String, dynamic>>? existingRef;
    if (id != null) {
      for (final doc in sameDay.docs) {
        if (doc.id == id) {
          existingRef = doc.reference;
          break;
        }
      }
    }
    final target = existingRef ??
        (sameDay.docs.isNotEmpty
            ? sameDay.docs.first.reference
            : _feedUsage.doc(
                '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
              ));
    final batch = _db.batch();
    batch.set(target, {
      'tanggal': Timestamp.fromDate(day),
      'jumlahKg': kg,
      'updatedAt': FieldValue.serverTimestamp(),
      if (sameDay.docs.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    for (final doc in sameDay.docs) {
      if (doc.reference.path != target.path) batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteFeedUsage(String id) => _feedUsage.doc(id).delete();

  Stream<List<ProductionModel>> watchProductions() => _productions
      .orderBy('tanggal', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ProductionModel.fromFirestore).toList());
  Stream<List<FeedModel>> watchFeeds() => _feeds
      .orderBy('tanggal', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FeedModel.fromFirestore).toList());
  Stream<List<TransactionModel>> watchTransactions() => _transactions
      .orderBy('tanggal', descending: true)
      .snapshots()
      .map((s) => s.docs.map(TransactionModel.fromFirestore).toList());

  Future<void> saveProduction(ProductionModel value, {String? id}) async {
    final ref = id == null ? _productions.doc() : _productions.doc(id);
    await ref.set({
      ...value.toFirestore(),
      if (id != null) 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: id != null));
  }

  Future<void> deleteProduction(String id) => _productions.doc(id).delete();

  Future<void> saveFeed(FeedModel value, {String? id, String? vendor}) async {
    final batch = _db.batch();
    final ref = id == null ? _feeds.doc() : _feeds.doc(id);
    // Keep the cashbook in sync with feed purchases. Update existing linked row on edit.
    final linkedId = id == null
        ? null
        : (await ref.get()).data()?['transaksiId'] as String?;
    final txRef = linkedId == null
        ? _transactions.doc()
        : _transactions.doc(linkedId);
    final payload = value.toFirestore();
    payload['pemasok'] = vendor;
    payload['transaksiId'] = txRef.id;
    batch.set(ref, {
      ...payload,
      if (id != null) 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: id != null));
    batch.set(txRef, {
      'tanggal': Timestamp.fromDate(value.tanggal),
      'tipe': 'pengeluaran',
      'kategori': 'Pembelian Pakan',
      'deskripsi':
          '${value.jenisPakan} ${value.jumlahKg} kg${vendor == null || vendor.isEmpty ? '' : ' dari $vendor'}',
      'jumlah': value.harga,
      'createdAt': FieldValue.serverTimestamp(),
      'feedId': ref.id,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteFeed(String id) async {
    final ref = _feeds.doc(id);
    final snap = await ref.get();
    final batch = _db.batch();
    batch.delete(ref);
    final txId = snap.data()?['transaksiId'] as String?;
    if (txId != null) batch.delete(_transactions.doc(txId));
    await batch.commit();
  }

  Future<void> saveTransaction(TransactionModel value, {String? id}) async {
    final ref = id == null ? _transactions.doc() : _transactions.doc(id);
    await ref.set({
      ...value.toFirestore(),
      if (id != null) 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: id != null));
  }

  Future<void> deleteTransaction(String id) => _transactions.doc(id).delete();
}
