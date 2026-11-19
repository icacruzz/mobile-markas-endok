import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/demo_data.dart';
import '../../models/transaction_model.dart';
import '../../services/farm_data_service.dart';
import '../../services/export_service.dart';
import '../../widgets/app_page_header.dart';

class CashBookScreen extends StatefulWidget {
  const CashBookScreen({super.key});
  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  String filter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<List<TransactionModel>>(
          stream: FarmDataService.instance.watchTransactions(),
          builder: (context, snap) {
            final actual = snap.data ?? [];
            // Demo records are presentation-only; never write them to Firestore.
            final all = actual.isEmpty ? DemoData.transactions : actual;
            final items = all
                .where(
                  (e) =>
                      filter == 'Semua' ||
                      (filter == 'Pemasukan'
                          ? e.tipe == TransactionType.pemasukan
                          : e.tipe == TransactionType.pengeluaran),
                )
                .toList();
            final inc = all
                .where((e) => e.tipe == TransactionType.pemasukan)
                .fold<double>(0, (s, e) => s + e.jumlah);
            final out = all
                .where((e) => e.tipe == TransactionType.pengeluaran)
                .fold<double>(0, (s, e) => s + e.jumlah);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _topHeader(),
                const SizedBox(height: 18),
                const Text(
                  'Laporan Keuangan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pantau arus kas, pemasukan, dan pengeluaran peternakan',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          ExportService.instance.excel('buku_kas', [
                            'Tanggal',
                            'Jenis',
                            'Kategori',
                            'Deskripsi',
                            'Jumlah Rp',
                          ], ExportService.transactions(all)),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export Excel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _edit,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Catat Transaksi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'Pemasukan',
                        fmt.format(inc),
                        Icons.trending_up,
                        const Color(0xFF16A34A),
                        const Color(0xFFDCFCE7),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _summaryCard(
                        'Pengeluaran',
                        fmt.format(out),
                        Icons.trending_down,
                        const Color(0xFFEA580C),
                        const Color(0xFFFFEDD5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _summaryCard(
                  'Saldo Bersih',
                  fmt.format(inc - out),
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF2563EB),
                  const Color(0xFFDBEAFE),
                ),
                const SizedBox(height: 16),
                _cashflowChart(all),
                const SizedBox(height: 16),
                _transactions(items, all, fmt, snap),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topHeader() {
    return const AppPageHeader(title: 'Buku Kas');
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _cashflowChart(List<TransactionModel> all) {
    final monthly = List.generate(6, (i) {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month - (5 - i));
      var income = 0.0, expense = 0.0;
      for (final tx in all) {
        if (tx.tanggal.year == date.year && tx.tanggal.month == date.month) {
          if (tx.tipe == TransactionType.pemasukan) {
            income += tx.jumlah;
          } else {
            expense += tx.jumlah;
          }
        }
      }
      return (date, income, expense);
    });
    final peak = monthly.fold<double>(
      0,
      (maxValue, month) =>
          [maxValue, month.$2, month.$3].reduce((a, b) => a > b ? a : b),
    );
    final chartMax = peak == 0 ? 1000000.0 : peak * 1.2;
    final chartInterval = chartMax / 4;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arus Kas Bulanan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Pemasukan dibanding pengeluaran',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 185,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: chartMax,
                barGroups: List.generate(
                  monthly.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: monthly[i].$2,
                        color: const Color(0xFF16A34A),
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                      BarChartRodData(
                        toY: monthly[i].$3,
                        color: const Color(0xFFEA580C),
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
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
                      reservedSize: 38,
                      interval: chartInterval,
                      getTitlesWidget: (v, _) => Text(
                        v == 0 ? '0' : '${(v / 1000000).toStringAsFixed(1)}jt',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 23,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= monthly.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            DateFormat('MMM', 'id_ID').format(monthly[i].$1),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        );
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
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFF16A34A), 'Pemasukan'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFEA580C), 'Pengeluaran'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      ),
    ],
  );

  Widget _transactions(
    List<TransactionModel> items,
    List<TransactionModel> all,
    NumberFormat fmt,
    AsyncSnapshot<List<TransactionModel>> snap,
  ) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 8, 7),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Transaksi Terakhir',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filter,
                  isDense: true,
                  items: const ['Semua', 'Pemasukan', 'Pengeluaran']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, style: const TextStyle(fontSize: 11)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => filter = v ?? 'Semua'),
                ),
              ),
            ],
          ),
        ),
        if (snap.hasError)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Gagal memuat transaksi. Periksa koneksi dan aturan Firestore.',
            ),
          ),
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        if (items.isEmpty && !snap.hasError)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Belum ada transaksi.'),
          ),
        ...items.map((e) {
          final income = e.tipe == TransactionType.pemasukan;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: income
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    income
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 17,
                    color: income
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.deskripsi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(e.tanggal)} · ${e.kategori}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${income ? '+' : '−'}${fmt.format(e.jumlah)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: income
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? _edit(e) : _delete(e),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${items.length} dari ${all.length} transaksi',
                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
              ),
              TextButton.icon(
                onPressed: () => ExportService.instance.pdf('Buku Kas', [
                  'Tanggal',
                  'Jenis',
                  'Kategori',
                  'Deskripsi',
                  'Jumlah Rp',
                ], ExportService.transactions(all)),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                label: const Text('Export PDF', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _delete(TransactionModel e) async {
    if (e.id != null) await FarmDataService.instance.deleteTransaction(e.id!);
  }

  Future<void> _edit([TransactionModel? old]) async {
    final form = GlobalKey<FormState>();
    final date = ValueNotifier(old?.tanggal ?? DateTime.now());
    var type = old?.tipe ?? TransactionType.pemasukan;
    final category = TextEditingController(text: old?.kategori ?? '');
    final desc = TextEditingController(text: old?.deskripsi ?? '');
    final amount = TextEditingController(
      text: old == null ? '' : '${old.jumlah}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(old == null ? 'Catat Transaksi' : 'Edit Transaksi'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<TransactionType>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Jenis transaksi',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TransactionType.pemasukan,
                          child: Text('Pemasukan'),
                        ),
                        DropdownMenuItem(
                          value: TransactionType.pengeluaran,
                          child: Text('Pengeluaran'),
                        ),
                      ],
                      onChanged: (v) => update(() => type = v ?? type),
                    ),
                    ValueListenableBuilder<DateTime>(
                      valueListenable: date,
                      builder: (context, d, child) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Tanggal: ${DateFormat('dd/MM/yyyy').format(d)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: d,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) date.value = picked;
                        },
                      ),
                    ),
                    _field(category, 'Kategori'),
                    _field(desc, 'Deskripsi'),
                    _field(amount, 'Jumlah (Rp)', numeric: true),
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
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await FarmDataService.instance.saveTransaction(
          TransactionModel(
            id: old?.id,
            tanggal: date.value,
            tipe: type,
            kategori: category.text.trim(),
            deskripsi: desc.text.trim(),
            jumlah: double.parse(amount.text),
          ),
          id: old?.id,
        );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
          );
      }
    }
    date.dispose();
    category.dispose();
    desc.dispose();
    amount.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      controller: c,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Wajib diisi'
          : numeric && double.tryParse(v) == null
          ? 'Masukkan angka valid'
          : null,
    ),
  );
}
