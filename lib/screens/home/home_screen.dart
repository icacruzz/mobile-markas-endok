import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/demo_data.dart';
import '../../main.dart';
import '../../models/feed_model.dart';
import '../../models/production_model.dart';
import '../../models/transaction_model.dart';
import '../../services/feed_stock_calculator.dart';
import '../../widgets/app_page_header.dart';

/// Dashboard Beranda — persis sesuai referensi desain UI.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onOpenHarvest,
    this.onOpenFeed,
    this.onOpenCashbook,
  });

  final VoidCallback? onOpenHarvest;
  final VoidCallback? onOpenFeed;
  final VoidCallback? onOpenCashbook;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final thousandFmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: MarkasEndogApp.primaryOrange,
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // === 1. Top Header App Bar ===
              _buildTopHeader(context),
              const SizedBox(height: 16),

              // === 2. Peringatan Stok Pakan Kritis ===
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('feeds')
                    .snapshots(),
                builder: (context, feedSnap) =>
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('feed_usage')
                          .snapshots(),
                      builder: (context, usageSnap) {
                        final buys =
                            feedSnap.data?.docs
                                .map<double>(
                                  (d) => (d.data()['jumlahKg'] as num? ?? 0)
                                      .toDouble(),
                                )
                                .toList() ??
                            <double>[];
                        final usageDocs = usageSnap.data?.docs ?? [];
                        final uses = usageDocs
                            .map<double>(
                              (d) => (d.data()['jumlahKg'] as num? ?? 0)
                                  .toDouble(),
                            )
                            .toList();
                        final totalUsed = uses.fold<double>(
                          0,
                          (sum, kg) => sum + kg,
                        );
                        final rawStock = buys.isEmpty
                            ? DemoData.stockBalance(
                                DemoData.feeds.map((e) => e.jumlahKg),
                                [
                                  ...DemoData.dailyUse.map((e) => e.toDouble()),
                                  totalUsed,
                                ],
                              )
                            : FeedStockCalculator.remainingKg(
                                purchases: feedSnap.data!.docs.map((d) =>
                                    FeedModel.fromFirestore(d)),
                                usage: usageDocs.map((d) => d.data()).toList(),
                              );
                        final stock = rawStock < 0 ? 0.0 : rawStock;
                        final dailyUsageRate =
                            FeedStockCalculator.latestDailyUsageKg(
                              usage: usageDocs.map((doc) => doc.data()),
                            );
                        final daysLeft = stock <= 0
                            ? 0
                            : (dailyUsageRate > 0
                                  ? (stock / dailyUsageRate).ceil()
                                  : 0);

                        return _buildCriticalBanner(
                          stock: stock,
                          dailyUsageRate: dailyUsageRate,
                          daysLeft: daysLeft,
                          onPressed: onOpenFeed,
                        );
                      },
                    ),
              ),
              const SizedBox(height: 20),

              // === 3. Section Ikhtisar Operasional & Tombol Catat Panen ===
              _buildOperationalSummaryHeader(context),
              const SizedBox(height: 16),

              // === 4. Grid 2x2 Metric Cards ===
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('productions')
                    .orderBy('tanggal', descending: true)
                    .snapshots(),
                builder: (context, prodSnap) {
                  final prodDocs = prodSnap.data?.docs ?? [];
                  final productions = prodDocs.isEmpty
                      ? DemoData.productions
                      : prodDocs.map(ProductionModel.fromFirestore).toList();
                  final todayProd = productions.isNotEmpty
                      ? productions.first
                      : DemoData.productions.first;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('feeds')
                        .snapshots(),
                    builder: (context, feedSnap) =>
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('feed_usage')
                              .snapshots(),
                          builder: (context, usageSnap) {
                            final buys =
                                feedSnap.data?.docs
                                    .map<double>(
                                      (d) => (d.data()['jumlahKg'] as num? ?? 0)
                                          .toDouble(),
                                    )
                                    .toList() ??
                                <double>[];
                            final usageDocs = usageSnap.data?.docs ?? [];
                            final uses = usageDocs
                                .map<double>(
                                  (d) => (d.data()['jumlahKg'] as num? ?? 0)
                                      .toDouble(),
                                )
                                .toList();
                            final totalUsed = uses.fold<double>(
                              0,
                              (sum, kg) => sum + kg,
                            );
                            final rawStock = buys.isEmpty
                                ? DemoData.stockBalance(
                                    DemoData.feeds.map((e) => e.jumlahKg),
                                    [
                                      ...DemoData.dailyUse.map(
                                        (e) => e.toDouble(),
                                      ),
                                      totalUsed,
                                    ],
                                  )
                                : FeedStockCalculator.remainingKg(
                                    purchases: feedSnap.data!.docs.map((d) =>
                                        FeedModel.fromFirestore(d)),
                                    usage: usageDocs
                                        .map((d) => d.data())
                                        .toList(),
                                  );
                            final stock = rawStock < 0 ? 0.0 : rawStock;
                            final dailyUsageRate =
                                FeedStockCalculator.latestDailyUsageKg(
                                  usage: usageDocs.map((doc) => doc.data()),
                                );
                            final daysLeft = stock <= 0
                                ? 0
                                : (dailyUsageRate > 0
                                      ? (stock / dailyUsageRate).ceil()
                                      : 0);

                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('transactions')
                                  .snapshots(),
                              builder: (context, txSnap) {
                                final txDocs = txSnap.data?.docs ?? [];
                                final txList = txDocs.isEmpty
                                    ? DemoData.transactions
                                    : txDocs
                                          .map(TransactionModel.fromFirestore)
                                          .toList();

                                final now = DateTime.now();
                                final monthTxs = txList
                                    .where(
                                      (e) =>
                                          e.tanggal.year == now.year &&
                                          e.tanggal.month == now.month,
                                    )
                                    .toList();
                                final totalIncome = monthTxs.isNotEmpty
                                    ? monthTxs
                                          .where(
                                            (e) =>
                                                e.tipe ==
                                                TransactionType.pemasukan,
                                          )
                                          .fold<double>(
                                            0,
                                            (s, e) => s + e.jumlah,
                                          )
                                    : 16350000.0;
                                final totalExpense = monthTxs.isNotEmpty
                                    ? monthTxs
                                          .where(
                                            (e) =>
                                                e.tipe ==
                                                TransactionType.pengeluaran,
                                          )
                                          .fold<double>(
                                            0,
                                            (s, e) => s + e.jumlah,
                                          )
                                    : 8200000.0;
                                final profit = totalIncome - totalExpense;

                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMetricCard(
                                            title: 'Produksi Hari Ini',
                                            icon: Icons.egg_outlined,
                                            iconColor: const Color(0xFFEA580C),
                                            iconBg: const Color(0xFFFFEDD5),
                                            value: thousandFmt.format(
                                              todayProd.totalButir,
                                            ),
                                            badgeText: '↗ 3.2%',
                                            badgePositive: true,
                                            subtitle:
                                                '${todayProd.tray} tray · ${todayProd.berat.toStringAsFixed(1)} kg',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildMetricCard(
                                            title: 'Sisa Stok Pakan',
                                            icon: Icons.inventory_2_outlined,
                                            iconColor: const Color(0xFFEF4444),
                                            iconBg: const Color(0xFFFEE2E2),
                                            value:
                                                '${stock.toStringAsFixed(0)} kg',
                                            subtitle:
                                                'Pemakaian ${dailyUsageRate.toStringAsFixed(0)} kg/hari · $daysLeft hari tersisa',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMetricCard(
                                            title: 'Total Pemasukan',
                                            icon: Icons.trending_up,
                                            iconColor: const Color(0xFF16A34A),
                                            iconBg: const Color(0xFFDCFCE7),
                                            value: currencyFmt.format(
                                              totalIncome,
                                            ),
                                            badgeText: '↗ 8.5%',
                                            badgePositive: true,
                                            subtitle: 'Bulan berjalan',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildMetricCard(
                                            title: 'Total Pengeluaran',
                                            icon: Icons.trending_down,
                                            iconColor: const Color(0xFFEF4444),
                                            iconBg: const Color(0xFFFEE2E2),
                                            value: currencyFmt.format(
                                              totalExpense,
                                            ),
                                            subtitle:
                                                'Laba: ${currencyFmt.format(profit)}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // === 5. Grafik Tren Hasil Panen Telur (7 Hari) ===
                                    _buildHarvestTrendChart(productions),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // === 6. Riwayat Panen Terakhir (Tabel) ===
              _buildSectionHeader(
                title: 'Riwayat Panen Terakhir',
                action: 'Lihat Semua',
                onPressed: onOpenHarvest,
              ),
              const SizedBox(height: 10),
              _buildHarvestTable(thousandFmt),
              const SizedBox(height: 24),

              // === 7. Transaksi Keuangan Terkini ===
              _buildSectionHeader(
                title: 'Transaksi Keuangan Terkini',
                action: 'Buku Kas Lengkap',
                onPressed: onOpenCashbook,
              ),
              const SizedBox(height: 10),
              _buildTransactionList(currencyFmt),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header Atas: [Logo] Beranda Peternakan [SU] ---
  Widget _buildTopHeader(BuildContext context) {
    return const AppPageHeader(title: 'Beranda Peternakan');
  }

  // --- Banner Peringatan Stok Pakan Kritis ---
  Widget _buildCriticalBanner({
    required double stock,
    required double dailyUsageRate,
    required int daysLeft,
    VoidCallback? onPressed,
  }) {
    final isSafe = daysLeft > 7;
    final heading = daysLeft <= 0
        ? 'Stok Pakan Habis'
        : daysLeft <= 2
        ? 'Perhatian: Stok Pakan Kritis'
        : daysLeft <= 7
        ? 'Stok Pakan Mulai Menipis'
        : 'Stok Pakan Aman';
    final accent = isSafe ? const Color(0xFF15803D) : const Color(0xFFE11D48);
    final background = isSafe
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFFF1F2);
    final border = isSafe ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isSafe
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cadangan pakan tersisa ${stock.toStringAsFixed(0)} kg. Dengan pemakaian terakhir ${dailyUsageRate.toStringAsFixed(0)} kg/hari, stok cukup untuk ±$daysLeft hari.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Kelola Stok'),
          ),
        ],
      ),
    );
  }

  // --- Subheading Ikhtisar Operasional & Tombol Catat Panen Baru ---
  Widget _buildOperationalSummaryHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ikhtisar Operasional',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Data panen telur hari ini, ketersediaan pakan, dan ringkasan arus kas',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: onOpenHarvest,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Catat Panen Baru'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Card Metrik 2x2 ---
  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    String? subtitle,
    String? badgeText,
    bool badgePositive = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgePositive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgePositive
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (subtitle != null)
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Grafik Tren Hasil Panen Telur (7 Hari) ---
  Widget _buildHarvestTrendChart(List<ProductionModel> productions) {
    final days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    final dataItems = productions.take(7).toList();
    while (dataItems.length < 7) {
      dataItems.add(
        DemoData.productions[dataItems.length % DemoData.productions.length],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Hasil Panen Telur (7 Hari)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Perbandingan butir utuh vs retak',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              InkWell(
                onTap: onOpenHarvest,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Panen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFFEA580C),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: 1600,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 400,
                      getTitlesWidget: (value, meta) {
                        if (value % 400 != 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              days[idx],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 400,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFFF1F5F9),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final item = dataItems[i];
                  final utuh = item.totalButir.toDouble();
                  final retak = (item.rusak * 3.5).toDouble().clamp(20.0, 50.0);

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: utuh,
                        color: const Color(0xFFEA580C),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: retak,
                        color: const Color(0xFFFDA4AF),
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Telur Rusak/Retak',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE11D48),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEA580C),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Telur Utuh (Baik)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Header Section dengan Link Arah Navigasi ---
  Widget _buildSectionHeader({
    required String title,
    required String action,
    VoidCallback? onPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              action,
              style: const TextStyle(
                color: Color(0xFFEA580C),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Tabel Riwayat Panen Terakhir (5 Baris) ---
  Widget _buildHarvestTable(NumberFormat thousandFmt) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('productions')
          .orderBy('tanggal', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final items = docs.isEmpty
            ? DemoData.productions.take(5).toList()
            : docs.map(ProductionModel.fromFirestore).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Row Tabel
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Tanggal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Tray',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Total Butir',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Berat',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Data Rows
              ...items.asMap().entries.map((entry) {
                final item = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          DateFormat('dd MMM').format(item.tanggal),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item.tray}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '${thousandFmt.format(item.totalButir)} butir',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${item.berat.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- List Transaksi Keuangan Terkini (5 Transaksi) ---
  Widget _buildTransactionList(NumberFormat currencyFmt) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('tanggal', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final items = docs.isEmpty
            ? DemoData.transactions.take(5).toList()
            : docs.map(TransactionModel.fromFirestore).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final tx = entry.value;
              final isIncome = tx.tipe == TransactionType.pemasukan;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: entry.key > 0
                      ? const Border(top: BorderSide(color: Color(0xFFF1F5F9)))
                      : null,
                ),
                child: Row(
                  children: [
                    // Badge Icon Panah Masuk/Keluar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isIncome
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isIncome
                            ? Icons.north_east_rounded
                            : Icons.south_east_rounded,
                        color: isIncome
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFEF4444),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Deskripsi & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.deskripsi,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('dd MMM').format(tx.tanggal)} · ${tx.kategori}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Jumlah Transaksi
                    Text(
                      '${isIncome ? '+' : '-'}${currencyFmt.format(tx.jumlah)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isIncome
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
