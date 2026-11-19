import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/demo_data.dart';
import '../../models/production_model.dart';
import '../../services/farm_data_service.dart';
import '../../services/export_service.dart';
import '../../widgets/app_page_header.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});
  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  String query = '';
  DateTime? filterDate;

  @override
  Widget build(BuildContext context) {
    final thousandFmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<List<ProductionModel>>(
          stream: FarmDataService.instance.watchProductions(),
          builder: (context, snap) {
            final actual = snap.data ?? [];
            final all = actual.isEmpty ? DemoData.productions : actual;

            final rows = all.where((e) {
              final dateStr = DateFormat('dd/MM/yyyy').format(e.tanggal);
              final matchesQuery =
                  query.isEmpty ||
                  '$dateStr ${e.totalButir}'.toLowerCase().contains(
                    query.toLowerCase(),
                  );
              final matchesDate =
                  filterDate == null ||
                  (e.tanggal.year == filterDate!.year &&
                      e.tanggal.month == filterDate!.month &&
                      e.tanggal.day == filterDate!.day);
              return matchesQuery && matchesDate;
            }).toList();

            final totalTelur = rows.fold<int>(
              0,
              (sum, e) => sum + e.totalButir,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _buildTopHeader(),
                const SizedBox(height: 16),
                _buildHeaderInfo(),
                const SizedBox(height: 16),
                _buildProductionChart(all),
                const SizedBox(height: 16),
                _buildSearchAndFilter(),
                const SizedBox(height: 14),
                _buildTable(rows, thousandFmt, totalTelur),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return const AppPageHeader(title: 'Produksi Telur');
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Produksi Telur',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Catatan panen telur harian, perhitungan tray, butir rusak, dan total berat',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _export(DemoData.productions, false),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export Excel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                backgroundColor: const Color(0xFFF1F5F9),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Catat Panen'),
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

  Widget _buildProductionChart(List<ProductionModel> items) {
    final days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    final data = items.take(7).toList();
    while (data.length < 7) {
      data.add(DemoData.productions[data.length % DemoData.productions.length]);
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
          const Text(
            'Tren Produksi Telur (7 Hari Terakhir)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Total butir utuh vs rusak per hari',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: 1600,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
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
                      reservedSize: 32,
                      interval: 400,
                      getTitlesWidget: (val, _) => val % 400 == 0
                          ? Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
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
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFF1F5F9),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final row = data[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: row.totalButir.toDouble(),
                        color: const Color(0xFFEA580C),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: (row.rusak * 4).toDouble().clamp(20.0, 60.0),
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
          const SizedBox(height: 10),
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
                'Telur Rusak',
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
                'Telur Baik',
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

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
              hintText: 'Cari berdasarkan tanggal atau jumlah butir...',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.filter_alt_outlined,
              size: 20,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filterDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                setState(() => filterDate = picked);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filterDate == null
                          ? 'dd/mm/yyyy'
                          : DateFormat('dd/MM/yyyy').format(filterDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: filterDate == null
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            if (filterDate != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => filterDate = null),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTable(
    List<ProductionModel> rows,
    NumberFormat thousandFmt,
    int totalTelur,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header tabel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
                    textAlign: TextAlign.center,
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
                    'Lepas',
                    textAlign: TextAlign.center,
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
                    'Rusak',
                    textAlign: TextAlign.center,
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
                    'Total Butir',
                    textAlign: TextAlign.center,
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
                    'Berat (kg)',
                    textAlign: TextAlign.right,
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
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tidak ada data produksi.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else
            ...rows.map(
              (e) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        DateFormat('d MMM yyyy').format(e.tanggal),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${e.tray}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${e.lepas}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${e.rusak}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        thousandFmt.format(e.totalButir),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        e.berat.toStringAsFixed(1),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Footer tabel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Menampilkan ${rows.length} dari ${rows.length} catatan',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    text: 'Total Telur Terdata: ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    children: [
                      TextSpan(
                        text: thousandFmt.format(totalTelur),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const TextSpan(
                        text: ' butir',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(List<ProductionModel> items, bool pdf) async {
    final x = ExportService.instance;
    final data = ExportService.productions(items);
    final headers = [
      'Tanggal',
      'Tray',
      'Lepas',
      'Rusak',
      'Total Butir',
      'Berat kg',
      'Catatan',
    ];
    if (pdf) {
      await x.pdf('Panen', headers, data);
    } else {
      await x.excel('panen', headers, data);
    }
  }

  Future<void> _edit([ProductionModel? item]) async {
    final form = GlobalKey<FormState>();
    final date = ValueNotifier(item?.tanggal ?? DateTime.now());
    final tray = TextEditingController(
      text: item == null ? '' : '${item.tray}',
    );
    final lepas = TextEditingController(
      text: item == null ? '' : '${item.lepas}',
    );
    final rusak = TextEditingController(
      text: item == null ? '' : '${item.rusak}',
    );
    final berat = TextEditingController(
      text: item == null ? '' : '${item.berat}',
    );
    final note = TextEditingController(text: item?.catatan ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Catat Panen Baru' : 'Edit Catatan Panen'),
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
                  _field(tray, 'Jumlah tray (30 butir/tray)', integer: true),
                  _field(lepas, 'Butir telur lepas', integer: true),
                  _field(rusak, 'Butir rusak / retak', integer: true),
                  _field(berat, 'Berat total (kg)'),
                  _field(
                    note,
                    'Catatan tambahan (opsional)',
                    required: false,
                    numeric: false,
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
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await FarmDataService.instance.saveProduction(
          ProductionModel(
            id: item?.id,
            tanggal: date.value,
            tray: int.parse(tray.text),
            lepas: int.parse(lepas.text),
            rusak: int.parse(rusak.text),
            berat: double.parse(berat.text),
            catatan: note.text.trim(),
          ),
          id: item?.id,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
        }
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool integer = false,
    bool required = true,
    bool numeric = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      controller: c,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(decimal: !integer)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (!required && (v == null || v.isEmpty)) return null;
        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
        return (integer ? int.tryParse(v) : double.tryParse(v)) == null
            ? 'Masukkan angka yang valid'
            : null;
      },
    ),
  );
}
