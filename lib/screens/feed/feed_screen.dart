import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/demo_data.dart';
import '../../models/feed_model.dart';
import '../../services/farm_data_service.dart';
import '../../services/feed_stock_calculator.dart';
import '../../services/receipt_image_service.dart';
import '../../services/export_service.dart';
import '../../widgets/app_page_header.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<List<FeedModel>>(
          stream: FarmDataService.instance.watchFeeds(),
          builder: (context, snap) {
            final actualFeeds = snap.data ?? [];
            final items = actualFeeds.isEmpty ? DemoData.feeds : actualFeeds;

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: FarmDataService.instance.watchFeedUsage(),
              builder: (context, usageSnap) {
                final usage = usageSnap.data ?? [];
                final totalPurchasedKg = items.fold<double>(
                  0,
                  (s, e) => s + e.jumlahKg,
                );
                final totalCost = items.fold<double>(0, (s, e) => s + e.harga);

                final actualUseKg = usage.fold<double>(
                  0,
                  (sum, r) => sum + ((r['jumlahKg'] as num?)?.toDouble() ?? 0),
                );

                final calculatedStock = actualFeeds.isEmpty
                    ? DemoData.stockBalance(
                        DemoData.feeds.map((e) => e.jumlahKg),
                        [
                          ...DemoData.dailyUse.map((e) => e.toDouble()),
                          actualUseKg,
                        ],
                      )
                    : FeedStockCalculator.remainingKg(
                        purchases: actualFeeds,
                        usage: usage,
                      );
                final stock = calculatedStock < 0 ? 0.0 : calculatedStock;

                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final firstDay = today.subtract(const Duration(days: 6));
                final recentUsage = usage.where((row) {
                  final value = row['tanggal'];
                  final date = value is Timestamp
                      ? value.toDate()
                      : value is DateTime
                          ? value
                          : null;
                  if (date == null) return false;
                  final day = DateTime(date.year, date.month, date.day);
                  return !day.isBefore(firstDay) && !day.isAfter(today);
                }).toList();
                final dailyUsageRate = FeedStockCalculator.latestDailyUsageKg(
                  usage: usage,
                  asOf: today,
                );
                final daysLeft = stock <= 0
                    ? 0
                    : (dailyUsageRate > 0
                          ? (stock / dailyUsageRate).ceil()
                          : 0);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _buildTopHeader(),
                    const SizedBox(height: 16),
                    _buildHeaderInfo(items, usage),
                    const SizedBox(height: 16),
                    _buildCriticalBanner(stock, daysLeft, dailyUsageRate),
                    const SizedBox(height: 16),
                    _buildMetricCards(
                      stock,
                      daysLeft,
                      items.length,
                      totalCost,
                      currency,
                      dailyUsageRate,
                    ),
                    const SizedBox(height: 14),
                    _buildConsumptionInfo(dailyUsageRate),
                    const SizedBox(height: 16),
                    _buildConsumptionChart(recentUsage),
                    const SizedBox(height: 16),
                    _buildPurchaseHistory(items, currency),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return const AppPageHeader(title: 'Stok & Inventaris Pakan');
  }

  Widget _buildHeaderInfo(
    List<FeedModel> items,
    List<Map<String, dynamic>> usage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inventaris & Manajemen Pakan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Pantau ketersediaan stok pakan ayam, laju konsumsi harian, dan proyeksi hari habis',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _export(items, false),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export Excel'),
              style: _actionBtnStyle(),
            ),
            OutlinedButton.icon(
              onPressed: () => _editUsageModal(usage),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Catat Konsumsi'),
              style: _actionBtnStyle(),
            ),
            ElevatedButton.icon(
              onPressed: () => _editFeed(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Beli Pakan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ButtonStyle _actionBtnStyle() => OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF334155),
    backgroundColor: const Color(0xFFF1F5F9),
    side: const BorderSide(color: Color(0xFFCBD5E1)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );

  Widget _buildCriticalBanner(
    double stock,
    int daysLeft,
    double dailyUsageRate,
  ) {
    final Color accent;
    final Color background;
    final Color border;
    final String heading;
    if (daysLeft <= 0) {
      accent = const Color(0xFFBE123C);
      background = const Color(0xFFFFE4E6);
      border = const Color(0xFFFECDD3);
      heading = 'Stok Pakan Habis';
    } else if (daysLeft <= 2) {
      accent = const Color(0xFFE11D48);
      background = const Color(0xFFFFF1F2);
      border = const Color(0xFFFECDD3);
      heading = 'Stok Pakan Sangat Kritis';
    } else if (daysLeft <= 7) {
      accent = const Color(0xFFB45309);
      background = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      heading = 'Stok Pakan Menipis';
    } else {
      accent = const Color(0xFF15803D);
      background = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      heading = 'Stok Pakan Aman';
    }
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
              daysLeft <= 7
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
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
                  'Sisa stok ${stock.toStringAsFixed(0)} kg. Dengan pemakaian terakhir ${dailyUsageRate.toStringAsFixed(0)} kg/hari, persediaan diperkirakan habis dalam $daysLeft hari.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(
    double stock,
    int daysLeft,
    int feedCount,
    double totalCost,
    NumberFormat currency,
    double dailyUsageRate,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricBox(
                title: 'Sisa Stok Pakan',
                value: '${stock.toStringAsFixed(0)} kg',
                subtitle: 'Total fisik di gudang',
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFEDD5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricBox(
                title: 'Estimasi Hari Habis',
                value: '$daysLeft Hari',
                subtitle:
                    'Terakhir ${dailyUsageRate.toStringAsFixed(0)} kg/hari',
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFEF4444),
                iconBg: const Color(0xFFFEE2E2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricBox(
                title: 'Total Pembelian',
                value: '$feedCount Pengadaan',
                subtitle: 'Faktur stok masuk',
                icon: Icons.trending_down_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFEDD5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricBox(
                title: 'Akumulasi Biaya Pa...',
                value: currency.format(totalCost),
                subtitle: 'Nilai persediaan masuk',
                icon: Icons.all_inbox_rounded,
                iconColor: const Color(0xFF3B82F6),
                iconBg: const Color(0xFFDBEAFE),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricBox({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
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
                  maxLines: 1,
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
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildConsumptionInfo(double dailyUsageRate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 18,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Estimasi memakai catatan konsumsi terbaru: ${dailyUsageRate.toStringAsFixed(1)} kg/hari. Catatan harian sebelumnya tetap tersimpan di riwayat.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          const Icon(
            Icons.autorenew_rounded,
            color: Color(0xFF2563EB),
            size: 19,
          ),
        ],
      ),
    );
  }

  Widget _buildConsumptionChart(List<Map<String, dynamic>> usage) {
    final recent = usage.reversed.toList();
    final dates = recent.map((row) {
      final value = row['tanggal'];
      return value is Timestamp ? value.toDate() : DateTime.now();
    }).toList();
    final rates = recent
        .map((row) => (row['jumlahKg'] as num?)?.toDouble() ?? 0)
        .toList();
    final maxRate = rates.isEmpty
        ? 100.0
        : rates.reduce((a, b) => a > b ? a : b) * 1.2;
    final chartMax = maxRate <= 0 ? 100.0 : maxRate;
    final chartInterval = (chartMax / 4).clamp(1, double.infinity).toDouble();

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
          const Text(
            'Konsumsi Pakan Harian (7 Hari Terakhir)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Fluktuasi pakan terpakai di kandang layer',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: rates.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada catatan konsumsi.\nCatat pemakaian harian untuk melihat grafik.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: chartMax,
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: chartInterval,
                            getTitlesWidget: (val, _) {
                              return Text(
                                val.toInt().toString(),
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
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < dates.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    DateFormat(
                                      'd MMM',
                                      'id_ID',
                                    ).format(dates[idx]),
                                    style: const TextStyle(
                                      fontSize: 10,
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
                        horizontalInterval: chartInterval,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFF1F5F9),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            rates.length,
                            (i) => FlSpot(i.toDouble(), rates[i]),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: const Color(0xFF2563EB),
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: const Color(0xFF2563EB),
                                  strokeWidth: 1.5,
                                  strokeColor: Colors.white,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseHistory(List<FeedModel> items, NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riwayat Pengadaan Pakan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.hasFotoNota)
                  GestureDetector(
                    onTap: () => _showImageDialog(e),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: Image(
                        image: _receiptImageProvider(e)!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 60,
                          color: const Color(0xFFFFF7ED),
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                height: 140,
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (!e.hasFotoNota)
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFFEA580C),
                            size: 20,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.jenisPakan} · ${e.jumlahKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${DateFormat('dd/MM/yyyy').format(e.tanggal)} · ${currency.format(e.harga)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (e.keterangan?.isNotEmpty == true)
                              Text(
                                e.keterangan!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (e.hasFotoNota)
                        GestureDetector(
                          onTap: () => _showImageDialog(e),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Lihat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (v) =>
                            v == 'edit' ? _editFeed(e) : _deleteFeed(e),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _export(List<FeedModel> items, bool pdf) async {
    final x = ExportService.instance;
    final data = ExportService.feeds(items);
    final headers = [
      'Tanggal',
      'Jenis Pakan',
      'Jumlah kg',
      'Harga / kg',
      'Biaya Rp',
      'Pemasok / Catatan',
      'Foto Nota',
    ];
    if (pdf) {
      await x.pdf('Pakan', headers, data);
    } else {
      await x.excel('pakan', headers, data);
    }
  }

  Future<void> _deleteFeed(FeedModel item) async {
    if (item.id == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus riwayat pakan?'),
        content: const Text(
          'Riwayat pembelian ini dan transaksi terkait akan dihapus. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      await FarmDataService.instance.deleteFeed(item.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  Future<void> _editUsageModal(List<Map<String, dynamic>> usage) async {
    final today = DateTime.now();
    final result = await showDialog<(DateTime, double)>(
      context: context,
      builder: (_) => _FeedUsageDialog(usage: usage, maxDate: today),
    );
    if (result != null) {
      final date = result.$1;
      final existing = usage.where((row) {
        final value = row['tanggal'];
        final rowDate = value is Timestamp
            ? value.toDate()
            : value is DateTime
                ? value
                : null;
        return rowDate != null &&
            rowDate.year == date.year &&
            rowDate.month == date.month &&
            rowDate.day == date.day;
      });
      final existingId = existing.isEmpty
          ? null
          : existing.first['id'] as String?;
      try {
        await FarmDataService.instance.saveFeedUsage(
          date,
          result.$2,
          id: existingId,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan konsumsi: $error')),
          );
        }
      }
    }
  }

  ImageProvider<Object>? _receiptImageProvider(FeedModel item) {
    final base64Image = item.fotoNotaBase64;
    if (base64Image != null && base64Image.isNotEmpty) {
      return MemoryImage(base64Decode(base64Image));
    }
    final url = item.fotoNotaUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  void _showImageDialog(FeedModel item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(
                image: _receiptImageProvider(item)!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Gambar tidak dapat dimuat',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editFeed([FeedModel? item]) async {
    final form = GlobalKey<FormState>();
    final date = ValueNotifier(item?.tanggal ?? DateTime.now());
    const predefinedKinds = [
      'Pakan Layer A',
      'Pakan Layer B',
      'Konsentrat',
      'Jagung',
      'Lainnya',
    ];
    // If saved kind is not in list, it's a custom value
    final savedKind = item?.jenisPakan ?? 'Pakan Layer A';
    final isCustomInitial = !predefinedKinds.contains(savedKind);
    String selectedDropdown = isCustomInitial ? 'Lainnya' : savedKind;
    bool useCustomKind = isCustomInitial;
    final customKindCtrl = TextEditingController(
      text: isCustomInitial ? savedKind : '',
    );
    // finalKind resolved at save time (see below)
    final kg = TextEditingController(
      text: item == null ? '' : '${item.jumlahKg}',
    );
    final pricePerKg = TextEditingController(
      text: item == null
          ? ''
          : '${item.hargaPerKg > 0 ? item.hargaPerKg : item.harga / (item.jumlahKg == 0 ? 1 : item.jumlahKg)}',
    );
    final vendor = TextEditingController(text: item?.keterangan ?? '');
    Uint8List? imageBytes;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(
            item == null
                ? 'Pencatatan Pembelian Stok Pakan'
                : 'Edit Pembelian Pakan',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: date,
                      builder: (_, d, __) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Tanggal: ${DateFormat('dd/MM/yyyy').format(d)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final x = await showDatePicker(
                            context: ctx,
                            initialDate: d,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (x != null) date.value = x;
                        },
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedDropdown,
                      decoration: const InputDecoration(
                        labelText: 'Jenis pakan',
                      ),
                      items: predefinedKinds
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setModal(() {
                        selectedDropdown = v ?? selectedDropdown;
                        useCustomKind = v == 'Lainnya';
                        if (!useCustomKind) customKindCtrl.clear();
                      }),
                    ),
                    if (useCustomKind)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          controller: customKindCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama jenis pakan (isi sendiri)',
                            hintText: 'Contoh: Vivo Layer 222',
                            prefixIcon: Icon(Icons.edit_outlined, size: 18),
                          ),
                          validator: (v) {
                            if (useCustomKind &&
                                (v == null || v.trim().isEmpty))
                              return 'Wajib diisi';
                            return null;
                          },
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    _field(
                      kg,
                      'Jumlah (kg)',
                      onChanged: (_) => setModal(() {}),
                    ),
                    _field(
                      pricePerKg,
                      'Harga beli / kg (Rp)',
                      onChanged: (_) => setModal(() {}),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Total biaya: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format((double.tryParse(kg.text) ?? 0) * (double.tryParse(pricePerKg.text) ?? 0))}',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _field(
                      vendor,
                      'Pemasok / Toko Pakan',
                      required: false,
                      numeric: false,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (kIsWeb) {
                          // Web: langsung buka picker tanpa pilih sumber
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                            maxWidth: ReceiptImageService.maxImageDimension
                                .toDouble(),
                            maxHeight: ReceiptImageService.maxImageDimension
                                .toDouble(),
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModal(() {
                              imageBytes = bytes;
                            });
                          }
                        } else {
                          final source =
                              await showModalBottomSheet<ImageSource>(
                                context: ctx,
                                builder: (sheetContext) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo_library_outlined,
                                        ),
                                        title: const Text('Pilih dari galeri'),
                                        onTap: () => Navigator.pop(
                                          sheetContext,
                                          ImageSource.gallery,
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo_camera_outlined,
                                        ),
                                        title: const Text(
                                          'Ambil foto dengan kamera',
                                        ),
                                        onTap: () => Navigator.pop(
                                          sheetContext,
                                          ImageSource.camera,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                          if (source == null) return;
                          final picked = await ImagePicker().pickImage(
                            source: source,
                            imageQuality: 80,
                            maxWidth: ReceiptImageService.maxImageDimension
                                .toDouble(),
                            maxHeight: ReceiptImageService.maxImageDimension
                                .toDouble(),
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModal(() {
                              imageBytes = bytes;
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.receipt),
                      label: Text(
                        imageBytes == null
                            ? (item?.hasFotoNota != true
                                  ? 'Unggah foto struk'
                                  : 'Ganti foto struk')
                            : '✓ Struk dipilih',
                      ),
                    ),
                    if (imageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            imageBytes!,
                            height: 110,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    if (imageBytes == null && item?.hasFotoNota == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: _receiptImageProvider(item!)!,
                            height: 110,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                const Text('Foto nota tidak dapat dimuat'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
              ),
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Simpan Pembelian'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    // Determine final kind value
    final finalKind = useCustomKind
        ? customKindCtrl.text.trim()
        : selectedDropdown;
    String? fotoNotaBase64 = item?.fotoNotaBase64;
    String? fotoNotaUrl = item?.fotoNotaUrl;
    var savingDialogOpen = false;
    try {
      if (imageBytes != null) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            title: Text('Menyimpan foto nota'),
            content: SizedBox(
              height: 32,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
        savingDialogOpen = true;
        fotoNotaBase64 = await ReceiptImageService.instance.encodeForFirestore(
          imageBytes!,
        );
        fotoNotaUrl = null;
      }
      await FarmDataService.instance.saveFeed(
        FeedModel(
          id: item?.id,
          tanggal: date.value,
          jenisPakan: finalKind,
          jumlahKg: double.parse(kg.text),
          hargaPerKg: double.parse(pricePerKg.text),
          harga: double.parse(kg.text) * double.parse(pricePerKg.text),
          keterangan: vendor.text.trim(),
          fotoNotaBase64: fotoNotaBase64,
          fotoNotaUrl: fotoNotaUrl,
        ),
        id: item?.id,
        vendor: vendor.text.trim(),
      );
      if (mounted && savingDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        savingDialogOpen = false;
      }
    } catch (e) {
      if (mounted && savingDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = true,
    bool numeric = true,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      controller: c,
      onChanged: onChanged,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
        if (!numeric) return null;
        return double.tryParse(v.replaceAll(',', '.')) == null
            ? 'Masukkan angka valid'
            : null;
      },
    ),
  );
}

class _FeedUsageDialog extends StatefulWidget {
  const _FeedUsageDialog({required this.usage, required this.maxDate});

  final List<Map<String, dynamic>> usage;
  final DateTime maxDate;

  @override
  State<_FeedUsageDialog> createState() => _FeedUsageDialogState();
}

class _FeedUsageDialogState extends State<_FeedUsageDialog> {
  late DateTime selectedDate;
  late TextEditingController controller;
  final inputFocus = FocusNode();
  final form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime(
      widget.maxDate.year,
      widget.maxDate.month,
      widget.maxDate.day,
    );
    controller = TextEditingController(
      text: _entryFor(selectedDate)?['jumlahKg']?.toString() ?? '',
    );
  }

  DateTime? _rowDate(Map<String, dynamic> row) {
    final value = row['tanggal'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic>? _entryFor(DateTime date) {
    for (final row in widget.usage) {
      final rowDate = _rowDate(row);
      if (rowDate != null &&
          rowDate.year == date.year &&
          rowDate.month == date.month &&
          rowDate.day == date.day) {
        return row;
      }
    }
    return null;
  }

  Future<void> _chooseDate() async {
    inputFocus.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        widget.maxDate.year,
        widget.maxDate.month,
        widget.maxDate.day,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedDate = DateTime(picked.year, picked.month, picked.day);
      controller.text = _entryFor(selectedDate)?['jumlahKg']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    inputFocus.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Catat Konsumsi Pakan'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Catat jumlah pakan yang benar-benar digunakan. Estimasi stok akan dihitung ulang otomatis.',
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Tanggal: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _chooseDate,
          ),
          TextFormField(
            controller: controller,
            focusNode: inputFocus,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Terpakai (kg)',
              suffixText: 'kg',
            ),
            validator: (value) {
              final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
              if (amount == null || amount <= 0) {
                return 'Masukkan jumlah lebih dari 0 kg';
              }
              return null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
        onPressed: () {
          if (!form.currentState!.validate()) return;
          final amount = double.parse(controller.text.replaceAll(',', '.'));
          Navigator.pop(context, (selectedDate, amount));
        },
        child: const Text('Simpan Konsumsi'),
      ),
    ],
  );
}
