import 'package:drift/drift.dart' hide Batch;
import 'package:pharmassist/data/local/app_database.dart';

class SaleCartItemData {
  final Medicine medicine;
  final Batch batch;
  final int qty;
  final double rate;
  final double discountPercent;

  SaleCartItemData({
    required this.medicine,
    required this.batch,
    required this.qty,
    required this.rate,
    this.discountPercent = 0.0,
  });

  double get subtotal => qty * rate;
  double get discountAmount => subtotal * (discountPercent / 100);
  double get taxableAmount => subtotal - discountAmount;
  double get gstRate => medicine.gstRate;
  double get taxAmount => taxableAmount * (gstRate / 100);
  double get total => taxableAmount + taxAmount;
}

class SaleWithItems {
  final Sale sale;
  final Customer? customer;
  final List<SaleItemDetail> items;

  SaleWithItems({
    required this.sale,
    this.customer,
    required this.items,
  });
}

class SaleItemDetail {
  final SaleItem item;
  final Medicine medicine;
  final Batch batch;

  SaleItemDetail({
    required this.item,
    required this.medicine,
    required this.batch,
  });
}

class SalesRepository {
  final AppDatabase _db;

  SalesRepository(this._db);

  Stream<List<Sale>> watchSales() {
    return (_db.select(_db.sales)..orderBy([(s) => OrderingTerm.desc(s.date)])).watch();
  }

  Future<List<Sale>> getSales() async {
    return await (_db.select(_db.sales)..orderBy([(s) => OrderingTerm.desc(s.date)])).get();
  }

  Future<SaleWithItems?> getSaleDetails(int saleId) async {
    final sale = await (_db.select(_db.sales)..where((s) => s.id.equals(saleId))).getSingleOrNull();
    if (sale == null) return null;

    Customer? customer;
    if (sale.customerId != null) {
      customer = await (_db.select(_db.customers)..where((c) => c.id.equals(sale.customerId!))).getSingleOrNull();
    }

    final rawItems = await (_db.select(_db.saleItems)..where((si) => si.saleId.equals(saleId))).get();
    final List<SaleItemDetail> itemDetails = [];

    for (final item in rawItems) {
      final batch = await (_db.select(_db.batches)..where((b) => b.id.equals(item.batchId))).getSingleOrNull();
      if (batch != null) {
        final medicine = await (_db.select(_db.medicines)..where((m) => m.id.equals(batch.medicineId))).getSingleOrNull();
        if (medicine != null) {
          itemDetails.add(SaleItemDetail(item: item, medicine: medicine, batch: batch));
        }
      }
    }

    return SaleWithItems(sale: sale, customer: customer, items: itemDetails);
  }

  /// Execute POS Checkout Sale Transaction
  Future<int> checkoutPOS({
    required int? customerId,
    required List<SaleCartItemData> cartItems,
    required double overallDiscount,
    required String paymentMode, // 'cash', 'card', 'upi', 'credit'
    required int userId,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Cart cannot be empty for checkout.');
    }

    int createdSaleId = 0;

    await _db.transaction(() async {
      // 1. Calculate Totals
      double subtotal = 0.0;
      double totalTax = 0.0;

      for (final item in cartItems) {
        subtotal += item.taxableAmount;
        totalTax += item.taxAmount;
      }

      final cgst = totalTax / 2;
      final sgst = totalTax / 2;
      final grandTotal = (subtotal + totalTax - overallDiscount).clamp(0.0, double.infinity);

      // Generate Invoice Number
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final randomSuffix = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final invoiceNo = 'INV-$dateStr-$randomSuffix';

      // 2. Insert Sales Record
      createdSaleId = await _db.into(_db.sales).insert(
        SalesCompanion.insert(
          customerId: Value(customerId),
          invoiceNo: invoiceNo,
          date: now,
          subtotal: subtotal,
          discount: Value(overallDiscount),
          taxCgst: Value(cgst),
          taxSgst: Value(sgst),
          taxIgst: const Value(0.0),
          total: grandTotal,
          paymentMode: Value(paymentMode),
        ),
      );

      // 3. Insert SaleItems and Deduct Batch Stock
      for (final item in cartItems) {
        // Verify current stock
        final currentBatch = await (_db.select(_db.batches)..where((b) => b.id.equals(item.batch.id))).getSingleOrNull();
        if (currentBatch == null || currentBatch.quantity < item.qty) {
          throw Exception('Insufficient stock for ${item.medicine.name} (Batch: ${item.batch.batchNo}). Available: ${currentBatch?.quantity ?? 0}');
        }

        // Insert Sale Item
        await _db.into(_db.saleItems).insert(
          SaleItemsCompanion.insert(
            saleId: createdSaleId,
            batchId: item.batch.id,
            qty: item.qty,
            rate: item.rate,
            discount: Value(item.discountAmount),
            taxAmount: Value(item.taxAmount),
          ),
        );

        // Deduct Batch Quantity
        final newBatchQty = currentBatch.quantity - item.qty;
        await (_db.update(_db.batches)..where((b) => b.id.equals(item.batch.id))).write(
          BatchesCompanion(quantity: Value(newBatchQty)),
        );

        // Record Audit Log for Stock Reduction
        await _db.into(_db.stockAdjustments).insert(
          StockAdjustmentsCompanion.insert(
            batchId: item.batch.id,
            qtyChange: -item.qty,
            reason: 'POS Sale ($invoiceNo)',
            date: now,
            userId: userId,
          ),
        );
      }

      // 4. Update Customer Credit Balance if Payment Mode is 'credit'
      if (paymentMode == 'credit' && customerId != null) {
        final cust = await (_db.select(_db.customers)..where((c) => c.id.equals(customerId))).getSingleOrNull();
        if (cust != null) {
          final newCreditBalance = cust.creditBalance + grandTotal;
          await (_db.update(_db.customers)..where((c) => c.id.equals(customerId))).write(
            CustomersCompanion(creditBalance: Value(newCreditBalance)),
          );
        }
      }

      // 5. Activity Log for Sale
      await _db.into(_db.activityLogs).insert(
        ActivityLogsCompanion.insert(
          userId: userId,
          action: 'POS_CHECKOUT',
          entity: 'Sale',
          entityId: Value(createdSaleId.toString()),
        ),
      );
    });

    return createdSaleId;
  }
}
