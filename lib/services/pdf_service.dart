import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class PdfService {
  static Future<String> generateEStatement({
    required String period,
    required String houseName,
    required double totalIncome,
    required double totalExpense,
    required double netProfit,
    required List<dynamic> transactions,
    required String type, // 'bulanan' or 'tahunan'
  }) async {
    final pdf = pw.Document();


    String formatCurrency(double amount) {
      return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          )}';
    }


    String formatDate(DateTime date) {
      final months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }


    Map<String, double> incomeByCategory = {};
    Map<String, double> expenseByCategory = {};

    for (var transaction in transactions) {
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      final type = transaction['type']?.toString() ?? '';
      final description = transaction['description']?.toString() ?? 'Transaksi';


      if (type == 'income') {
        incomeByCategory[description] =
            (incomeByCategory[description] ?? 0) + amount;
      } else if (type == 'expense') {
        expenseByCategory[description] =
            (expenseByCategory[description] ?? 0) + amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [

            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    'Financial Statement',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Smartlet Management System',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 16),


            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Periode: $period',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Kandang: $houseName',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tanggal Cetak: ${formatDate(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Tipe: ${type == 'bulanan' ? 'Bulanan' : 'Tahunan'}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Total Transaksi: ${transactions.length}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),


            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Akun Jenis Pendapatan',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (incomeByCategory.isEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '- Tidak ada pendapatan',
                        style: const pw.TextStyle(
                            fontSize: 11, color: PdfColors.grey600),
                      ),
                    )
                  else
                    ...incomeByCategory.entries.map((entry) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                '- ${entry.key}',
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ),
                            pw.Text(
                              formatCurrency(entry.value),
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.green200),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Pendapatan:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        formatCurrency(totalIncome),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),


            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Akun Jenis Pengeluaran',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (expenseByCategory.isEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '- Tidak ada pengeluaran',
                        style: const pw.TextStyle(
                            fontSize: 11, color: PdfColors.grey600),
                      ),
                    )
                  else
                    ...expenseByCategory.entries.map((entry) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                '- ${entry.key}',
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ),
                            pw.Text(
                              formatCurrency(entry.value),
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.red200),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Pengeluaran:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        formatCurrency(totalExpense),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),


            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: netProfit >= 0 ? PdfColors.amber50 : PdfColors.red100,
                border: pw.Border.all(
                  color: netProfit >= 0 ? PdfColors.amber700 : PdfColors.red700,
                  width: 2,
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Laba/Rugi (Pendapatan - Pengeluaran):',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    formatCurrency(netProfit),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: netProfit >= 0
                          ? PdfColors.amber900
                          : PdfColors.red900,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 32),


            pw.Text(
              'Detail Transaksi',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),


            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [

                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Tanggal',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Kategori',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Keterangan',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Jumlah',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),

                ...transactions.map((transaction) {
                  final type = transaction['type']?.toString() ?? '';
                  final isIncome = type == 'income';
                  final dateStr = transaction['transaction_date']?.toString() ?? '';
                  final date = dateStr.isNotEmpty ? dateStr.split('T')[0] : '-';
                  final note = transaction['description']?.toString() ?? '-';
                  final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                  final categoryName = isIncome ? 'Pendapatan' : 'Pengeluaran';

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          date,
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          categoryName,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          note,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          formatCurrency(amount),
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: isIncome
                                ? PdfColors.green700
                                : PdfColors.red700,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 24),


            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Dokumen ini dibuat secara otomatis oleh Smartlet Management System',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );


    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
    final filename =
        'Financial_Statement_${houseName.replaceAll(' ', '_')}_${period.replaceAll(' ', '_')}_$dateStr.pdf';

    try {

      Directory? directory;
      try {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getTemporaryDirectory();
        }
      } catch (e) {
        directory = await getTemporaryDirectory();
      }

      final filePath = '${directory.path}/$filename';


      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      print('PDF saved to: $filePath');


      return filePath;
    } catch (e) {
      print('Error saving PDF: $e');
      rethrow;
    }
  }


  static Future<bool> openPdfFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      print('Error opening PDF: $e');
      return false;
    }
  }


  static Future<void> sharePdfFile(String filePath, String text) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: text,
      );
    } catch (e) {
      print('Error sharing PDF: $e');
      rethrow;
    }
  }
}
