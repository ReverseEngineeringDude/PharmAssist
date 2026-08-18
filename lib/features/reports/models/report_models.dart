class FinancialSummaryModel {
  final double totalMrpValue;
  final double totalPurchaseValue;
  final double potentialProfit;
  final double profitMarginPercent;
  final double totalPurchaseExpenses;
  final double totalGstPaid;
  final int totalMedicinesCount;
  final int totalBatchesCount;
  final int totalUnitsCount;
  final DateTime? selectedMonth;

  FinancialSummaryModel({
    required this.totalMrpValue,
    required this.totalPurchaseValue,
    required this.potentialProfit,
    required this.profitMarginPercent,
    required this.totalPurchaseExpenses,
    required this.totalGstPaid,
    required this.totalMedicinesCount,
    required this.totalBatchesCount,
    required this.totalUnitsCount,
    this.selectedMonth,
  });
}

class ExpiryAnalyticsModel {
  final int expiredBatchesCount;
  final double expiredStockValue;
  final int nearExpiryBatchesCount;
  final double nearExpiryStockValue;
  final List<ExpiredBatchItem> expiredList;
  final List<ExpiredBatchItem> nearExpiryList;

  ExpiryAnalyticsModel({
    required this.expiredBatchesCount,
    required this.expiredStockValue,
    required this.nearExpiryBatchesCount,
    required this.nearExpiryStockValue,
    required this.expiredList,
    required this.nearExpiryList,
  });
}

class ExpiredBatchItem {
  final String medicineName;
  final String batchNo;
  final DateTime expiryDate;
  final int quantity;
  final double mrp;
  final double purchasePrice;

  ExpiredBatchItem({
    required this.medicineName,
    required this.batchNo,
    required this.expiryDate,
    required this.quantity,
    required this.mrp,
    required this.purchasePrice,
  });

  double get totalMrpValue => quantity * mrp;
  double get totalPurchaseValue => quantity * purchasePrice;
}

class CategoryAnalyticsModel {
  final String category;
  final int itemCount;
  final int totalQuantity;
  final double totalValue;

  CategoryAnalyticsModel({
    required this.category,
    required this.itemCount,
    required this.totalQuantity,
    required this.totalValue,
  });
}

class StockMovementLog {
  final int id;
  final String medicineName;
  final String batchNo;
  final int qtyChange;
  final String reason;
  final DateTime date;

  StockMovementLog({
    required this.id,
    required this.medicineName,
    required this.batchNo,
    required this.qtyChange,
    required this.reason,
    required this.date,
  });
}

class SupplierSummaryModel {
  final String supplierName;
  final int totalInvoices;
  final double totalAmount;
  final double totalTax;

  SupplierSummaryModel({
    required this.supplierName,
    required this.totalInvoices,
    required this.totalAmount,
    required this.totalTax,
  });
}

class MonthlyTrendModel {
  final String monthLabel;
  final DateTime monthDate;
  final double purchaseAmount;
  final int stockDeductionsQty;

  MonthlyTrendModel({
    required this.monthLabel,
    required this.monthDate,
    required this.purchaseAmount,
    required this.stockDeductionsQty,
  });
}
