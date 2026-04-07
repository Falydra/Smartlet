// Web stub for PdfService — PDF generation requires dart:io and is not
// supported on web. All methods throw UnsupportedError so callers can
// handle them gracefully.

class PdfService {
  static Future<String> generateEStatement({
    required String period,
    required String houseName,
    required double totalIncome,
    required double totalExpense,
    required double netProfit,
    required List<dynamic> transactions,
    required String type,
  }) async {
    throw UnsupportedError('PDF generation is not supported on web.');
  }

  static Future<bool> openPdfFile(String filePath) async {
    throw UnsupportedError('Opening PDF files is not supported on web.');
  }

  static Future<void> sharePdfFile(String filePath, String text) async {
    throw UnsupportedError('Sharing PDF files is not supported on web.');
  }
}
