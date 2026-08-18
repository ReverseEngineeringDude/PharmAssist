import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pharmassist/features/reports/models/report_models.dart';

class ReportPdfService {
  static final currencyFormat = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2, locale: 'en_IN');
  static final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static Future<void> printExecutiveReport({
    required FinancialSummaryModel financial,
    required ExpiryAnalyticsModel expiry,
    required List<CategoryAnalyticsModel> categories,
  }) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document();
    final monthHeader = financial.selectedMonth != null
        ? DateFormat('MMMM yyyy').format(financial.selectedMonth!)
        : 'All Time Overview';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PHARM ASSIST ERP', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700)),
                    pw.Text('Executive Report - $monthHeader', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated On:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.Text(dateFormat.format(DateTime.now()), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // Financial Summary Block
            pw.Text('1. Financial & Valuation Overview ($monthHeader)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Amount (INR)', 'Details / Note'],
              data: [
                ['Total Stock MRP Valuation', currencyFormat.format(financial.totalMrpValue), '${financial.totalUnitsCount} Total Units'],
                ['Total Stock Purchase Valuation', currencyFormat.format(financial.totalPurchaseValue), 'Base Cost Value'],
                ['Potential Gross Profit', currencyFormat.format(financial.potentialProfit), '${financial.profitMarginPercent.toStringAsFixed(1)}% Est. Margin'],
                ['Purchase Expenses ($monthHeader)', currencyFormat.format(financial.totalPurchaseExpenses), 'Invoices Recorded'],
                ['Input GST Paid ($monthHeader)', currencyFormat.format(financial.totalGstPaid), 'CGST + SGST + IGST'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),

            pw.SizedBox(height: 20),

            // Expiry Risk Summary Block
            pw.Text('2. Expiry Risk & Inventory Health', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['Alert Status', 'Batch Count', 'Total MRP Exposure'],
              data: [
                ['Expired Stock (Action Required)', '${expiry.expiredBatchesCount} batches', currencyFormat.format(expiry.expiredStockValue)],
                ['Near Expiry (Next 90 Days)', '${expiry.nearExpiryBatchesCount} batches', currencyFormat.format(expiry.nearExpiryStockValue)],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),

            pw.SizedBox(height: 20),

            // Category Valuation Table
            pw.Text('3. Stock Distribution by Category', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['Category Name', 'Medicines Count', 'Total Stock Qty', 'Total MRP Valuation'],
              data: categories.map((cat) => [
                cat.category,
                '${cat.itemCount}',
                '${cat.totalQuantity}',
                currencyFormat.format(cat.totalValue),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),

            pw.SizedBox(height: 24),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),

            pw.Center(
              child: pw.Text(
                'End of Executive Report - Confidential Internal Document',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'PharmAssist_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
