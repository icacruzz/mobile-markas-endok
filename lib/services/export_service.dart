import 'dart:io';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/production_model.dart';
import '../models/feed_model.dart';
import '../models/transaction_model.dart';

class ExportService {
  ExportService._();
  static final instance = ExportService._();

  Future<void> excel(
    String title,
    List<String> headers,
    List<List<Object?>> rows,
  ) async {
    final book = Excel.createExcel();
    final sheet = book['Catatan'];
    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());
    for (final row in rows) {
      sheet.appendRow(
        row
            .map((e) => e == null ? TextCellValue('') : TextCellValue('$e'))
            .toList(),
      );
    }
    final bytes = book.save();
    if (bytes == null) throw Exception('Gagal membuat file Excel');
    final file = File('${Directory.systemTemp.path}/$title.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Ekspor $title Markas Endog');
  }

  Future<void> pdf(
    String title,
    List<String> headers,
    List<List<Object?>> rows,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Markas Endog — $title',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows.map((r) => r.map((e) => '$e').toList()).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.orange100,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(5),
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: '$title.pdf');
  }

  static List<List<Object?>> productions(List<ProductionModel> items) => items
      .map(
        (e) => <Object?>[
          e.tanggal.toIso8601String().substring(0, 10),
          e.tray,
          e.lepas,
          e.rusak,
          e.totalButir,
          e.berat,
          e.catatan ?? '',
        ],
      )
      .toList();
  static List<List<Object?>> feeds(List<FeedModel> items) => items
      .map(
        (e) => <Object?>[
          e.tanggal.toIso8601String().substring(0, 10),
          e.jenisPakan,
          e.jumlahKg,
          e.hargaPerKg,
          e.harga,
          e.keterangan ?? '',
          e.hasFotoNota ? 'Tersimpan di Firestore' : '',
        ],
      )
      .toList();
  static List<List<Object?>> transactions(List<TransactionModel> items) => items
      .map(
        (e) => <Object?>[
          e.tanggal.toIso8601String().substring(0, 10),
          e.tipe.name,
          e.kategori,
          e.deskripsi,
          e.jumlah,
        ],
      )
      .toList();
}
