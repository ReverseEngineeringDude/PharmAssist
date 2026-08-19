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

  Future<bool> deleteSupplier(int id) async {
    bool success = false;
    await _db.transaction(() async {
      // 1. Delete all purchase invoices associated with this supplier
      final invoices = await (_db.select(_db.purchaseInvoices)..where((p) => p.supplierId.equals(id))).get();
      for (final inv in invoices) {
        await deletePurchaseInvoice(inv.id);
      }

      // 2. Delete supplier record from database
      final count = await (_db.delete(_db.suppliers)..where((s) => s.id.equals(id))).go();
      success = count > 0;

      if (success) {
        await _db.into(_db.activityLogs).insert(
          ActivityLogsCompanion.insert(
            userId: 1,
            action: 'DELETE_SUPPLIER',
            entity: 'Supplier',
            entityId: Value(id.toString()),
          ),
        );
      }
    });

    return success;
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

  // --- DELETE PURCHASE INVOICE ---

  Future<bool> deletePurchaseInvoice(int invoiceId) async {
    bool success = false;
    await _db.transaction(() async {
      final invoice = await (_db.select(_db.purchaseInvoices)..where((p) => p.id.equals(invoiceId))).getSingleOrNull();
      if (invoice == null) return;

      // 1. Get all invoice items
      final items = await (_db.select(_db.purchaseInvoiceItems)..where((pi) => pi.purchaseInvoiceId.equals(invoiceId))).get();
      final batchIds = items.map((i) => i.batchId).toList();

      // 2. Delete invoice items
      await (_db.delete(_db.purchaseInvoiceItems)..where((pi) => pi.purchaseInvoiceId.equals(invoiceId))).go();

      // 3. Remove stock adjustments & batches if no sales recorded for them
      if (batchIds.isNotEmpty) {
        await (_db.delete(_db.stockAdjustments)..where((s) => s.batchId.isIn(batchIds))).go();

        for (final bId in batchIds) {
          final saleCount = await (_db.select(_db.saleItems)..where((s) => s.batchId.equals(bId))).get();
          if (saleCount.isEmpty) {
            await (_db.delete(_db.batches)..where((b) => b.id.equals(bId))).go();
          }
        }
      }

      // 4. Delete the purchase invoice record
      final count = await (_db.delete(_db.purchaseInvoices)..where((p) => p.id.equals(invoiceId))).go();
      success = count > 0;

      if (success) {
        await _db.into(_db.activityLogs).insert(
          ActivityLogsCompanion.insert(
            userId: 1,
            action: 'DELETE_PURCHASE_INVOICE',
            entity: 'PurchaseInvoice',
            entityId: Value(invoiceId.toString()),
          ),
        );
      }
    });

    return success;
  }

  // --- CLOUD BACKUP & RESTORE HELPERS ---

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getPurchasesForBackup() async {
    final query = _db.select(_db.purchaseInvoices).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchaseInvoices.supplierId)),
    ]);

    final rows = await query.get();
    final List<Map<String, dynamic>> backupData = [];

    for (final row in rows) {
      final invoice = row.readTable(_db.purchaseInvoices);
      final supplier = row.readTable(_db.suppliers);

      final itemsQuery = _db.select(_db.purchaseInvoiceItems).join([
        innerJoin(_db.batches, _db.batches.id.equalsExp(_db.purchaseInvoiceItems.batchId)),
        innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.batches.medicineId)),
      ])..where(_db.purchaseInvoiceItems.purchaseInvoiceId.equals(invoice.id));

      final itemRows = await itemsQuery.get();
      final List<Map<String, dynamic>> itemsData = itemRows.map((itemRow) {
        final item = itemRow.readTable(_db.purchaseInvoiceItems);
        final batch = itemRow.readTable(_db.batches);
        final medicine = itemRow.readTable(_db.medicines);

        return {
          'medicineName': medicine.name,
          'batchNo': batch.batchNo,
          'mfgDate': batch.mfgDate?.toIso8601String(),
          'expiryDate': batch.expiryDate.toIso8601String(),
          'purchasePrice': item.rate,
          'mrp': batch.mrp,
          'quantity': item.qty,
        };
      }).toList();

      backupData.add({
        'invoiceId': invoice.id,
        'invoiceNo': invoice.invoiceNo,
        'invoiceDate': invoice.date.toIso8601String(),
        'totalAmount': invoice.totalAmount,
        'supplierName': supplier.name,
        'supplierGstin': supplier.gstin,
        'supplierPhone': supplier.phone,
        'supplierAddress': supplier.address,
        'items': itemsData,
      });
    }

    return backupData;
  }

  Future<Map<String, int>> restorePurchasesFromFirestore(List<Map<String, dynamic>> cloudPurchases) async {
    int restoredInvoices = 0;
    int restoredSuppliers = 0;

    await _db.transaction(() async {
      for (final item in cloudPurchases) {
        final String? invoiceNo = item['invoiceNo']?.toString();
        final String? supplierName = item['supplierName']?.toString();

        if (invoiceNo == null || invoiceNo.isEmpty || supplierName == null || supplierName.isEmpty) {
          continue;
        }

        // 1. Ensure supplier exists or create
        final existingSuppliers = await (_db.select(_db.suppliers)..where((s) => s.name.equals(supplierName))).get();
        int supplierId;
        if (existingSuppliers.isNotEmpty) {
          supplierId = existingSuppliers.first.id;
        } else {
          supplierId = await _db.into(_db.suppliers).insert(
            SuppliersCompanion.insert(
              name: supplierName,
              gstin: Value(item['supplierGstin']?.toString()),
              phone: Value(item['supplierPhone']?.toString()),
              address: Value(item['supplierAddress']?.toString()),
            ),
          );
          restoredSuppliers++;
        }

        // Parse date and amount
        DateTime invoiceDate = DateTime.now();
        if (item['invoiceDate'] is DateTime) {
          invoiceDate = item['invoiceDate'] as DateTime;
        } else if (item['invoiceDate'] != null) {
          invoiceDate = DateTime.tryParse(item['invoiceDate'].toString()) ?? DateTime.now();
        }

        final double totalAmount = _parseDouble(item['totalAmount']);

        // Check if invoice exists
        final existingInvoices = await (_db.select(_db.purchaseInvoices)..where((p) => p.invoiceNo.equals(invoiceNo))).get();
        int invoiceId;
        if (existingInvoices.isNotEmpty) {
          invoiceId = existingInvoices.first.id;
          await (_db.update(_db.purchaseInvoices)..where((p) => p.id.equals(invoiceId))).write(
            PurchaseInvoicesCompanion(
              supplierId: Value(supplierId),
              date: Value(invoiceDate),
              totalAmount: Value(totalAmount),
            ),
          );
        } else {
          invoiceId = await _db.into(_db.purchaseInvoices).insert(
            PurchaseInvoicesCompanion.insert(
              supplierId: supplierId,
              invoiceNo: invoiceNo,
              date: invoiceDate,
              totalAmount: totalAmount,
            ),
          );
        }
        restoredInvoices++;

        // Restore items
        final List<dynamic> rawItems = item['items'] as List<dynamic>? ?? [];
        for (final rawItem in rawItems) {
          if (rawItem is Map) {
            final medName = rawItem['medicineName']?.toString();
            final batchNo = rawItem['batchNo']?.toString();
            if (medName == null || batchNo == null) continue;

            // Find medicine
            final existingMeds = await (_db.select(_db.medicines)..where((m) => m.name.equals(medName))).get();
            int medId;
            if (existingMeds.isNotEmpty) {
              medId = existingMeds.first.id;
            } else {
              medId = await _db.into(_db.medicines).insert(
                MedicinesCompanion.insert(
                  name: medName,
                ),
              );
            }

            final double purchasePrice = _parseDouble(rawItem['purchasePrice']);
            final double mrp = _parseDouble(rawItem['mrp']);
            final int quantity = _parseInt(rawItem['quantity']);

            DateTime expiryDate = DateTime.now().add(const Duration(days: 365));
            if (rawItem['expiryDate'] is DateTime) {
              expiryDate = rawItem['expiryDate'] as DateTime;
            } else if (rawItem['expiryDate'] != null) {
              expiryDate = DateTime.tryParse(rawItem['expiryDate'].toString()) ?? expiryDate;
            }

            // Find or create batch
            final existingBatches = await (_db.select(_db.batches)
                  ..where((b) => b.medicineId.equals(medId) & b.batchNo.equals(batchNo)))
                .get();

            int batchId;
            if (existingBatches.isNotEmpty) {
              batchId = existingBatches.first.id;
            } else {
              batchId = await _db.into(_db.batches).insert(
                BatchesCompanion.insert(
                  medicineId: medId,
                  batchNo: batchNo,
                  purchasePrice: purchasePrice,
                  mrp: mrp,
                  quantity: Value(quantity),
                  expiryDate: expiryDate,
                ),
              );
            }

            // Check if purchase invoice item exists
            final existingPiItems = await (_db.select(_db.purchaseInvoiceItems)
                  ..where((pi) => pi.purchaseInvoiceId.equals(invoiceId) & pi.batchId.equals(batchId)))
                .get();

            if (existingPiItems.isEmpty) {
              await _db.into(_db.purchaseInvoiceItems).insert(
                PurchaseInvoiceItemsCompanion.insert(
                  purchaseInvoiceId: invoiceId,
                  batchId: batchId,
                  qty: quantity,
                  rate: purchasePrice,
                ),
              );
            }
          }
        }
      }

      await _db.into(_db.activityLogs).insert(
        ActivityLogsCompanion.insert(
          userId: 1,
          action: 'RESTORE_PURCHASES_CLOUD',
          entity: 'PurchaseInvoice',
          entityId: Value('CLOUD_${DateTime.now().millisecondsSinceEpoch}'),
        ),
      );
    });

    return {'invoices': restoredInvoices, 'suppliers': restoredSuppliers};
  }

  /// Format suppliers master data for Cloud Firestore backup
  Future<List<Map<String, dynamic>>> getSuppliersForBackup() async {
    final suppliers = await getSuppliers();
    return suppliers.map((sup) => {
      'id': sup.id,
      'name': sup.name,
      'gstin': sup.gstin,
      'phone': sup.phone,
      'address': sup.address,
      'balanceDue': sup.balanceDue,
    }).toList();
  }

  /// Restore suppliers master data from Cloud Firestore
  Future<int> restoreSuppliersFromFirestore(List<Map<String, dynamic>> cloudSuppliers) async {
    int restoredCount = 0;
    await _db.transaction(() async {
      for (final item in cloudSuppliers) {
        final String? name = item['name']?.toString();
        if (name == null || name.trim().isEmpty) continue;

        final gstin = item['gstin']?.toString();
        final phone = item['phone']?.toString();
        final address = item['address']?.toString();
        final double balanceDue = _parseDouble(item['balanceDue']);

        final existing = await (_db.select(_db.suppliers)..where((s) => s.name.equals(name))).get();
        if (existing.isNotEmpty) {
          await (_db.update(_db.suppliers)..where((s) => s.id.equals(existing.first.id))).write(
            SuppliersCompanion(
              gstin: Value(gstin),
              phone: Value(phone),
              address: Value(address),
              balanceDue: Value(balanceDue),
            ),
          );
        } else {
          await _db.into(_db.suppliers).insert(
            SuppliersCompanion.insert(
              name: name,
              gstin: Value(gstin),
              phone: Value(phone),
              address: Value(address),
              balanceDue: Value(balanceDue),
            ),
          );
        }
        restoredCount++;
      }
    });

    return restoredCount;
  }
}
