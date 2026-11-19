import '../models/feed_model.dart';
import '../models/production_model.dart';
import '../models/transaction_model.dart';

/// Sample data is presentation-only and is never persisted to Firebase.
class DemoData {
  static DateTime day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
  }

  static final productions = List<ProductionModel>.generate(7, (i) => ProductionModel(
    tanggal: day(i),
    tray: [48,45,50,42,47,44,49][i],
    lepas: [12,18,8,20,15,10,5][i],
    rusak: [8,5,10,6,9,7,11][i],
    berat: [71.4,68.2,73.0,64.8,69.5,66.0,70.8][i],
    totalButirOverride: [1452,1368,1508,1280,1425,1330,1475][i],
  ));

  static final feeds = <FeedModel>[
    FeedModel(tanggal: day(2), jumlahKg: 500, harga: 4250000, hargaPerKg: 8500, jenisPakan: 'Pakan Layer A', keterangan: 'UD. Maju Jaya'),
    FeedModel(tanggal: day(10), jumlahKg: 300, harga: 2700000, hargaPerKg: 9000, jenisPakan: 'Pakan Layer B', keterangan: 'PT. Ternak Sejahtera'),
  ];
  static const dailyUse = [85.0,82,80,83,84,86,81];
  static const marketPricePerKg = [28000,27500];
  static const marketPricePerTray = [55000,54000];

  static final transactions = <TransactionModel>[
    _tx(0, 'pemasukan', 'Penjualan Telur', 3500000, 'Jual 48 tray ke pasar Padasuka'),
    _tx(1, 'pemasukan', 'Penjualan Telur', 3200000, 'Jual 45 tray ke warung Bu Sari'),
    _tx(2, 'pengeluaran', 'Pembelian Pakan', 4250000, 'Beli pakan Layer A 500 kg'),
    _tx(3, 'pemasukan', 'Penjualan Telur', 2950000, 'Jual 42 tray retail'),
    _tx(4, 'pengeluaran', 'Operasional', 450000, 'Bayar listrik dan air'),
    _tx(5, 'pemasukan', 'Penjualan Telur', 3100000, 'Jual 44 tray'),
    _tx(6, 'pengeluaran', 'Tenaga Kerja', 800000, 'Gaji 2 orang pekerja harian'),
    _tx(7, 'pengeluaran', 'Pembelian Pakan', 2700000, 'Beli pakan Layer B 300 kg'),
    _tx(8, 'pemasukan', 'Penjualan Telur', 3400000, 'Jual grosir ke pengepul'),
    _tx(9, 'pemasukan', 'Penjualan Pupuk', 200000, 'Jual kotoran ayam'),
  ];

  static TransactionModel _tx(int offset, String type, String category, double amount, String desc) => TransactionModel(
    tanggal: day(offset), tipe: type == 'pemasukan' ? TransactionType.pemasukan : TransactionType.pengeluaran,
    kategori: category, jumlah: amount, deskripsi: desc,
  );

  static double stockBalance(Iterable<double> purchases, Iterable<double> uses) =>
      purchases.fold<double>(0, (sum, kg) => sum + kg) - uses.fold<double>(0, (sum, kg) => sum + kg);
}
