import 'package:drift/drift.dart' hide Batch;
import 'package:pharmassist/data/local/app_database.dart';

class PurchaseInvoiceItemDetail {
  final Medicine medicine;
  final Batch batch;
  final int qty;
  final double rate;

  PurchaseInvoiceItemDetail({
    required this.medicine,
    required this.batch,
    required this.qty,
    required this.rate,
  });

  double get total => qty * rate;
}

class PurchaseInvoiceWithDetails {
  final PurchaseInvoice invoice;
  final Supplier supplier;
  final List<PurchaseInvoiceItemDetail> items;

  PurchaseInvoiceWithDetails({
    required this.invoice,
    required this.supplier,
    required this.items,
  });
}

class PurchaseItemInput {
  final int medicineId;
  final String batchNo;
  final DateTime? mfgDate;
  final DateTime expiryDate;
  final double purchasePrice;
  final double mrp;
  final int quantity;

  PurchaseItemInput({
    required this.medicineId,
    required this.batchNo,
    this.mfgDate,
    required this.expiryDate,
    required this.purchasePrice,
    required this.mrp,
    required this.quantity,
  });
}

class PurchaseRepository {
  final AppDatabase _db;

  PurchaseRepository(this._db);

  // --- SUPPLIERS ---

  Stream<List<Supplier>> watchSuppliers() {
    return (_db.select(_db.suppliers)..orderBy([(s) => OrderingTerm.asc(s.name)])).watch();
  }

  Future<List<Supplier>> getSuppliers() async {
    return await (_db.select(_db.suppliers)..orderBy([(s) => OrderingTerm.asc(s.name)])).get();
  }

  Future<int> addSupplier(SuppliersCompanion companion) async {
    final id = await _db.into(_db.suppliers).insert(companion);
    await _db.into(_db.activityLogs).insert(
      ActivityLogsCompanion.insert(
        userId: 1,
        action: 'CREATE_SUPPLIER',
        entity: 'Supplier',
        entityId: Value(id.toString()),
      ),
    );
    return id;
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    return await _db.update(_db.suppliers).replace(supplier);
  }

  Future<int> deleteSupplier(int id) async {
    return await (_db.delete(_db.suppliers)..where((s) => s.id.equals(id))).go();
  }

  // --- PURCHASE INVOICES ---

  Stream<List<PurchaseInvoiceWithDetails>> watchPurchaseInvoices() {
    final query = _db.select(_db.purchaseInvoices).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchaseInvoices.supplierId)),
    ])..orderBy([OrderingTerm.desc(_db.purchaseInvoices.date)]);

    return query.watch().asyncMap((rows) async {
      final List<PurchaseInvoiceWithDetails> result = [];

      for (final row in rows) {
        final invoice = row.readTable(_db.purchaseInvoices);
        final supplier = row.readTable(_db.suppliers);

        final itemsQuery = _db.select(_db.purchaseInvoiceItems).join([
          innerJoin(_db.batches, _db.batches.id.equalsExp(_db.purchaseInvoiceItems.batchId)),
          innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.batches.medicineId)),
        ])..where(_db.purchaseInvoiceItems.purchaseInvoiceId.equals(invoice.id));

        final itemRows = await itemsQuery.get();
        final List<PurchaseInvoiceItemDetail> itemDetails = itemRows.map((itemRow) {
          final item = itemRow.readTable(_db.purchaseInvoiceItems);
          final batch = itemRow.readTable(_db.batches);
          final medicine = itemRow.readTable(_db.medicines);

          return PurchaseInvoiceItemDetail(
            medicine: medicine,
            batch: batch,
            qty: item.qty,
            rate: item.rate,
          );
        }).toList();

        result.add(
          PurchaseInvoiceWithDetails(
            invoice: invoice,
            supplier: supplier,
            items: itemDetails,
          ),
        );
      }

      return result;
    });
  }

  Future<int> createPurchaseInvoice({
    required int supplierId,
    required String invoiceNo,
    required DateTime invoiceDate,
    required List<PurchaseItemInput> items,
    double paidAmount = 0.0,
  }) async {
    int invoiceId = 0;

    await _db.transaction(() async {
      double totalInvoiceAmount = 0.0;

      // Calculate total invoice amount
      for (final item in items) {
        totalInvoiceAmount += (item.purchasePrice * item.quantity);
      }

      // 1. Insert Purchase Invoice
      invoiceId = await _db.into(_db.purchaseInvoices).insert(
        PurchaseInvoicesCompanion.insert(
          supplierId: supplierId,
          invoiceNo: invoiceNo,
          date: invoiceDate,
          totalAmount: totalInvoiceAmount,
        ),
      );

      // 2. Process each item (insert batch + invoice item + stock adjustment)
      for (final item in items) {
        // Create batch for the medicine
        final batchId = await _db.into(_db.batches).insert(
          BatchesCompanion.insert(
            medicineId: item.medicineId,
            batchNo: item.batchNo,
            mfgDate: Value(item.mfgDate),
            expiryDate: item.expiryDate,
            purchasePrice: item.purchasePrice,
            mrp: item.mrp,
            quantity: Value(item.quantity),
          ),
        );

        // Insert purchase item detail
        await _db.into(_db.purchaseInvoiceItems).insert(
          PurchaseInvoiceItemsCompanion.insert(
            purchaseInvoiceId: invoiceId,
            batchId: batchId,
            qty: item.quantity,
            rate: item.purchasePrice,
          ),
        );

        // Record stock adjustment entry
        await _db.into(_db.stockAdjustments).insert(
          StockAdjustmentsCompanion.insert(
            batchId: batchId,
            qtyChange: item.quantity,
            reason: 'PURCHASE_INVOICE #$invoiceNo',
            date: DateTime.now(),
            userId: 1,
          ),
        );
      }

      // 3. Update supplier balance due if unpaid
      final creditAmount = totalInvoiceAmount - paidAmount;
      if (creditAmount > 0) {
        final supplier = await (_db.select(_db.suppliers)..where((s) => s.id.equals(supplierId))).getSingleOrNull();
        if (supplier != null) {
          final newBalance = supplier.balanceDue + creditAmount;
          await (_db.update(_db.suppliers)..where((s) => s.id.equals(supplierId))).write(
            SuppliersCompanion(balanceDue: Value(newBalance)),
          );
        }
      }

      // 4. Audit Log
      await _db.into(_db.activityLogs).insert(
        ActivityLogsCompanion.insert(
          userId: 1,
          action: 'CREATE_PURCHASE_INVOICE',
          entity: 'PurchaseInvoice',
          entityId: Value(invoiceId.toString()),
        ),
      );
    });

    return invoiceId;
  }
}
