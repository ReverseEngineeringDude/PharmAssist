import 'package:drift/drift.dart' hide Batch;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/local/database_provider.dart';
import 'package:pharmassist/features/reports/models/report_models.dart';

class SelectedMonthFilterNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  set state(DateTime? value) => super.state = value;
}
final selectedMonthFilterProvider = NotifierProvider<SelectedMonthFilterNotifier, DateTime?>(SelectedMonthFilterNotifier.new);

final financialSummaryProvider = FutureProvider<FinancialSummaryModel>((ref) async {
  final db = ref.watch(databaseProvider);
  final selectedMonth = ref.watch(selectedMonthFilterProvider);

  // 1. Fetch all medicines and active batches
  final medicines = await db.select(db.medicines).get();
  final batches = await db.select(db.batches).get();
  final allPurchases = await db.select(db.purchaseInvoices).get();

  double totalMrpValue = 0.0;
  double totalPurchaseValue = 0.0;
  int totalUnitsCount = 0;

  for (final batch in batches) {
    if (batch.quantity > 0) {
      totalMrpValue += (batch.quantity * batch.mrp);
      totalPurchaseValue += (batch.quantity * batch.purchasePrice);
      totalUnitsCount += batch.quantity;
    }
  }

  final potentialProfit = (totalMrpValue - totalPurchaseValue).clamp(0.0, double.infinity);
  final profitMarginPercent = totalMrpValue > 0 ? (potentialProfit / totalMrpValue) * 100 : 0.0;

  // Filter purchases by selected month if active
  List<PurchaseInvoice> filteredPurchases = allPurchases;
  if (selectedMonth != null) {
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
    filteredPurchases = allPurchases.where((p) =>
      p.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
      p.date.isBefore(endOfMonth.add(const Duration(seconds: 1)))
    ).toList();
  }

  double totalPurchaseExpenses = 0.0;
  double totalGstPaid = 0.0;

  for (final purchase in filteredPurchases) {
    totalPurchaseExpenses += purchase.totalAmount;
    totalGstPaid += (purchase.totalAmount * 0.18);
  }

  return FinancialSummaryModel(
    totalMrpValue: totalMrpValue,
    totalPurchaseValue: totalPurchaseValue,
    potentialProfit: potentialProfit,
    profitMarginPercent: profitMarginPercent,
    totalPurchaseExpenses: totalPurchaseExpenses,
    totalGstPaid: totalGstPaid,
    totalMedicinesCount: medicines.length,
    totalBatchesCount: batches.length,
    totalUnitsCount: totalUnitsCount,
    selectedMonth: selectedMonth,
  );
});

final expiryAnalyticsProvider = FutureProvider<ExpiryAnalyticsModel>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final nearExpiryThreshold = now.add(const Duration(days: 90));

  final query = db.select(db.batches).join([
    innerJoin(db.medicines, db.medicines.id.equalsExp(db.batches.medicineId)),
  ]);

  final rows = await query.get();

  final List<ExpiredBatchItem> expiredList = [];
  final List<ExpiredBatchItem> nearExpiryList = [];

  double expiredValue = 0.0;
  double nearExpiryValue = 0.0;

  for (final row in rows) {
    final batch = row.readTable(db.batches);
    final med = row.readTable(db.medicines);

    if (batch.quantity <= 0) continue;

    final item = ExpiredBatchItem(
      medicineName: med.name,
      batchNo: batch.batchNo,
      expiryDate: batch.expiryDate,
      quantity: batch.quantity,
      mrp: batch.mrp,
      purchasePrice: batch.purchasePrice,
    );

    if (batch.expiryDate.isBefore(now)) {
      expiredList.add(item);
      expiredValue += item.totalMrpValue;
    } else if (batch.expiryDate.isBefore(nearExpiryThreshold)) {
      nearExpiryList.add(item);
      nearExpiryValue += item.totalMrpValue;
    }
  }

  return ExpiryAnalyticsModel(
    expiredBatchesCount: expiredList.length,
    expiredStockValue: expiredValue,
    nearExpiryBatchesCount: nearExpiryList.length,
    nearExpiryStockValue: nearExpiryValue,
    expiredList: expiredList,
    nearExpiryList: nearExpiryList,
  );
});

final categoryAnalyticsProvider = FutureProvider<List<CategoryAnalyticsModel>>((ref) async {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.medicines).join([
    leftOuterJoin(db.batches, db.batches.medicineId.equalsExp(db.medicines.id)),
  ]);

  final rows = await query.get();

  final Map<String, List<Map<String, dynamic>>> catMap = {};

  for (final row in rows) {
    final med = row.readTable(db.medicines);
    final batch = row.readTableOrNull(db.batches);
    final cat = med.category ?? 'General';

    if (!catMap.containsKey(cat)) {
      catMap[cat] = [];
    }

    catMap[cat]!.add({
      'medicineId': med.id,
      'qty': batch?.quantity ?? 0,
      'value': (batch != null && batch.quantity > 0) ? (batch.quantity * batch.mrp) : 0.0,
    });
  }

  final List<CategoryAnalyticsModel> result = [];

  catMap.forEach((category, items) {
    final uniqueMeds = items.map((e) => e['medicineId'] as int).toSet().length;
    final totalQty = items.fold<int>(0, (sum, e) => sum + (e['qty'] as int));
    final totalVal = items.fold<double>(0.0, (sum, e) => sum + (e['value'] as double));

    result.add(CategoryAnalyticsModel(
      category: category,
      itemCount: uniqueMeds,
      totalQuantity: totalQty,
      totalValue: totalVal,
    ));
  });

  result.sort((a, b) => b.totalValue.compareTo(a.totalValue));
  return result;
});

final stockMovementLogsProvider = FutureProvider<List<StockMovementLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  final selectedMonth = ref.watch(selectedMonthFilterProvider);

  final query = db.select(db.stockAdjustments).join([
    innerJoin(db.batches, db.batches.id.equalsExp(db.stockAdjustments.batchId)),
    innerJoin(db.medicines, db.medicines.id.equalsExp(db.batches.medicineId)),
  ])..orderBy([OrderingTerm.desc(db.stockAdjustments.date)]);

  final rows = await query.get();

  final logs = rows.map((row) {
    final adj = row.readTable(db.stockAdjustments);
    final batch = row.readTable(db.batches);
    final med = row.readTable(db.medicines);

    return StockMovementLog(
      id: adj.id,
      medicineName: med.name,
      batchNo: batch.batchNo,
      qtyChange: adj.qtyChange,
      reason: adj.reason,
      date: adj.date,
    );
  }).toList();

  if (selectedMonth == null) return logs;

  final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);

  return logs.where((l) =>
    l.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
    l.date.isBefore(endOfMonth.add(const Duration(seconds: 1)))
  ).toList();
});

final supplierSummaryProvider = FutureProvider<List<SupplierSummaryModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  final selectedMonth = ref.watch(selectedMonthFilterProvider);

  final query = db.select(db.purchaseInvoices).join([
    innerJoin(db.suppliers, db.suppliers.id.equalsExp(db.purchaseInvoices.supplierId)),
  ]);

  final rows = await query.get();

  final Map<String, List<PurchaseInvoice>> suppMap = {};

  for (final row in rows) {
    final invoice = row.readTable(db.purchaseInvoices);
    final supplier = row.readTable(db.suppliers);

    if (selectedMonth != null) {
      final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
      if (invoice.date.isBefore(startOfMonth) || invoice.date.isAfter(endOfMonth)) {
        continue;
      }
    }

    final suppName = supplier.name.trim().isEmpty ? 'Unknown Supplier' : supplier.name;

    if (!suppMap.containsKey(suppName)) {
      suppMap[suppName] = [];
    }
    suppMap[suppName]!.add(invoice);
  }

  final List<SupplierSummaryModel> result = [];

  suppMap.forEach((supp, list) {
    final totalAmt = list.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
    final totalTax = totalAmt * 0.18;

    result.add(SupplierSummaryModel(
      supplierName: supp,
      totalInvoices: list.length,
      totalAmount: totalAmt,
      totalTax: totalTax,
    ));
  });

  result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  return result;
});

/// Computes monthly spending & stock movement trends over the last 6 months
final monthlyTrendsProvider = FutureProvider<List<MonthlyTrendModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  final purchases = await db.select(db.purchaseInvoices).get();
  final adjustments = await db.select(db.stockAdjustments).get();

  final now = DateTime.now();
  final List<MonthlyTrendModel> trends = [];
  final monthFormat = DateFormat('MMM yyyy');

  // Last 6 months (from 5 months ago to current month)
  for (int i = 5; i >= 0; i--) {
    final date = DateTime(now.year, now.month - i, 1);
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

    final monthPurchases = purchases.where((p) => p.date.isAfter(start.subtract(const Duration(seconds: 1))) && p.date.isBefore(end.add(const Duration(seconds: 1))));
    final monthAdjustments = adjustments.where((a) => a.date.isAfter(start.subtract(const Duration(seconds: 1))) && a.date.isBefore(end.add(const Duration(seconds: 1))));

    final purchaseAmount = monthPurchases.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
    final stockDeductionsQty = monthAdjustments
        .where((a) => a.qtyChange < 0)
        .fold<int>(0, (sum, a) => sum + a.qtyChange.abs());

    trends.add(MonthlyTrendModel(
      monthLabel: monthFormat.format(date),
      monthDate: date,
      purchaseAmount: purchaseAmount,
      stockDeductionsQty: stockDeductionsQty,
    ));
  }

  return trends;
});
