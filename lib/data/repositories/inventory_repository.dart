import 'package:drift/drift.dart' hide Batch;
import 'package:pharmassist/core/services/notification_service.dart';
import 'package:pharmassist/data/local/app_database.dart';

class MedicineWithStock {
  final Medicine medicine;
  final int totalQuantity;
  final int batchCount;
  final bool hasNearExpiry;
  final bool hasExpired;

  MedicineWithStock({
    required this.medicine,
    required this.totalQuantity,
    required this.batchCount,
    this.hasNearExpiry = false,
    this.hasExpired = false,
  });
}

class BatchWithMedicine {
  final Batch batch;
  final Medicine medicine;

  BatchWithMedicine({
    required this.batch,
    required this.medicine,
  });
}

class BulkImportItem {
  final String name;
  final String? genericName;
  final String? category;
  final String? manufacturer;
  final String? hsnCode;
  final double gstRate;
  final String scheduleFlag;
  final String unit;
  final int reorderLevel;

  // Optional initial batch details
  final String? batchNo;
  final DateTime? expiryDate;
  final double? mrp;
  final double? purchasePrice;
  final int? quantity;

  BulkImportItem({
    required this.name,
    this.genericName,
    this.category,
    this.manufacturer,
    this.hsnCode,
    this.gstRate = 12.0,
    this.scheduleFlag = 'NONE',
    this.unit = 'Strip',
    this.reorderLevel = 10,
    this.batchNo,
    this.expiryDate,
    this.mrp,
    this.purchasePrice,
    this.quantity,
  });
}

class InventoryRepository {
  final AppDatabase _db;

  InventoryRepository(this._db);

  // --- MEDICINE CRUD ---

  Stream<List<MedicineWithStock>> watchMedicinesWithStock() {
    final query = _db.select(_db.medicines).join([
      leftOuterJoin(_db.batches, _db.batches.medicineId.equalsExp(_db.medicines.id)),
    ]);

    return query.watch().map((rows) {
      final Map<int, List<Batch>> medicineBatchesMap = {};
      final Map<int, Medicine> medicineMap = {};

      final now = DateTime.now();
      final nearExpiryDate = now.add(const Duration(days: 90));

      for (final row in rows) {
        final medicine = row.readTable(_db.medicines);
        final batch = row.readTableOrNull(_db.batches);

        medicineMap[medicine.id] = medicine;
        if (!medicineBatchesMap.containsKey(medicine.id)) {
          medicineBatchesMap[medicine.id] = [];
        }
        if (batch != null) {
          medicineBatchesMap[medicine.id]!.add(batch);
        }
      }

      return medicineMap.values.map((med) {
        final batches = medicineBatchesMap[med.id] ?? [];
        final totalQty = batches.fold<int>(0, (sum, b) => sum + b.quantity);
        final hasExpired = batches.any((b) => b.quantity > 0 && b.expiryDate.isBefore(now));
        final hasNearExpiry = batches.any((b) =>
            b.quantity > 0 &&
            b.expiryDate.isAfter(now) &&
            b.expiryDate.isBefore(nearExpiryDate));

        return MedicineWithStock(
          medicine: med,
          totalQuantity: totalQty,
          batchCount: batches.length,
          hasNearExpiry: hasNearExpiry,
          hasExpired: hasExpired,
        );
      }).toList();
    });
  }

  Future<int> addMedicine(MedicinesCompanion companion) async {
    final id = await _db.into(_db.medicines).insert(companion);
    await _db.into(_db.activityLogs).insert(
      ActivityLogsCompanion.insert(
        userId: 1, // Default system/user
        action: 'CREATE_MEDICINE',
        entity: 'Medicine',
        entityId: Value(id.toString()),
      ),
    );
    return id;
  }

  Future<bool> updateMedicine(Medicine medicine) async {
    final updated = await _db.update(_db.medicines).replace(medicine);
    if (updated) {
      await _db.into(_db.activityLogs).insert(
        ActivityLogsCompanion.insert(
          userId: 1,
          action: 'UPDATE_MEDICINE',
          entity: 'Medicine',
          entityId: Value(medicine.id.toString()),
        ),
      );
    }
    return updated;
  }

  Future<int> deleteMedicine(int id) async {
    int count = 0;
    await _db.transaction(() async {
      // 1. Find all batch IDs belonging to this medicine
      final batches = await (_db.select(_db.batches)..where((b) => b.medicineId.equals(id))).get();
      final batchIds = batches.map((b) => b.id).toList();

      if (batchIds.isNotEmpty) {
        // 2. Remove related stock adjustment audit entries
        await (_db.delete(_db.stockAdjustments)..where((s) => s.batchId.isIn(batchIds))).go();

        // 3. Remove related purchase invoice items
        await (_db.delete(_db.purchaseInvoiceItems)..where((p) => p.batchId.isIn(batchIds))).go();

        // 4. Remove related sale line items
        await (_db.delete(_db.saleItems)..where((s) => s.batchId.isIn(batchIds))).go();

        // 5. Delete all batches for this medicine
        await (_db.delete(_db.batches)..where((b) => b.medicineId.equals(id))).go();
      }

      // 6. Delete the medicine record
      count = await (_db.delete(_db.medicines)..where((m) => m.id.equals(id))).go();

      if (count > 0) {
        await _db.into(_db.activityLogs).insert(
          ActivityLogsCompanion.insert(
            userId: 1,
            action: 'DELETE_MEDICINE',
            entity: 'Medicine',
            entityId: Value(id.toString()),
          ),
        );
      }
    });

    return count;
  }

  Future<int> bulkImportMedicines(List<BulkImportItem> items) async {
    int importedCount = 0;
    await _db.transaction(() async {
      for (final item in items) {
        final medId = await _db.into(_db.medicines).insert(
          MedicinesCompanion.insert(
            name: item.name,
            genericName: Value(item.genericName),
            category: Value(item.category ?? 'General'),
            manufacturer: Value(item.manufacturer),
            hsnCode: Value(item.hsnCode),
            gstRate: Value(item.gstRate),
            scheduleFlag: Value(item.scheduleFlag),
            unit: Value(item.unit),
            reorderLevel: Value(item.reorderLevel),
          ),
        );

        if (item.batchNo != null && item.batchNo!.isNotEmpty && item.expiryDate != null) {
          await _db.into(_db.batches).insert(
            BatchesCompanion.insert(
              medicineId: medId,
              batchNo: item.batchNo!,
              expiryDate: item.expiryDate!,
              mrp: item.mrp ?? 0.0,
              purchasePrice: item.purchasePrice ?? 0.0,
              quantity: Value(item.quantity ?? 0),
            ),
          );
        }

        await _db.into(_db.activityLogs).insert(
          ActivityLogsCompanion.insert(
            userId: 1,
            action: 'BULK_IMPORT_MEDICINE',
            entity: 'Medicine',
            entityId: Value(medId.toString()),
          ),
        );

        importedCount++;
      }
    });
    return importedCount;
  }

  // --- BATCH MANAGEMENT ---

  Stream<List<Batch>> watchBatchesForMedicine(int medicineId) {
    return (_db.select(_db.batches)
          ..where((b) => b.medicineId.equals(medicineId))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .watch();
  }

  Future<List<Batch>> getBatchesForMedicine(int medicineId) async {
    return await (_db.select(_db.batches)
          ..where((b) => b.medicineId.equals(medicineId))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  /// FEFO (First Expiry First Out) Auto-Selection Algorithm
  Future<Batch?> getFEFOBatchForMedicine(int medicineId) async {
    final now = DateTime.now();
    final query = _db.select(_db.batches)
      ..where((b) =>
          b.medicineId.equals(medicineId) &
          b.quantity.isBiggerThan(const Constant(0)) &
          b.expiryDate.isBiggerThan(Variable(now)))
      ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)])
      ..limit(1);

    return await query.getSingleOrNull();
  }

  Future<int> addBatch(BatchesCompanion companion) async {
    final id = await _db.into(_db.batches).insert(companion);
    await _db.into(_db.activityLogs).insert(
      ActivityLogsCompanion.insert(
        userId: 1,
        action: 'CREATE_BATCH',
        entity: 'Batch',
        entityId: Value(id.toString()),
      ),
    );
    return id;
  }

  Future<bool> updateBatch(Batch batch) async {
    return await _db.update(_db.batches).replace(batch);
  }

  // --- CENTRAL STOCK ADJUSTMENT METHOD ---
  /// All stock adjustments (sales, returns, adjustments) MUST flow through this central method
  Future<void> adjustStock({
    required int batchId,
    required int qtyChange,
    required String reason,
    required int userId,
  }) async {
    await _db.transaction(() async {
      final batch = await (_db.select(_db.batches)..where((b) => b.id.equals(batchId)))
          .getSingleOrNull();

      if (batch == null) {
        throw Exception('Batch with ID $batchId not found.');
      }

      final newQty = batch.quantity + qtyChange;
      if (newQty < 0) {
        throw Exception('Stock cannot be negative. Current: ${batch.quantity}, Change: $qtyChange');
      }

      // 1. Update Batch Quantity
      await (_db.update(_db.batches)..where((b) => b.id.equals(batchId))).write(
        BatchesCompanion(quantity: Value(newQty)),
      );

      // 2. Record Stock Adjustment Entry
      await _db.into(_db.stockAdjustments).insert(
        StockAdjustmentsCompanion.insert(
          batchId: batchId,
          qtyChange: qtyChange,
          reason: reason,
          date: DateTime.now(),
          userId: userId,
        ),
      );

      // 3. Record Audit Log
      await _db.into(_db.activityLogs).insert(
        ActivityLogsCompanion.insert(
          userId: userId,
          action: 'STOCK_ADJUSTMENT',
          entity: 'Batch',
          entityId: Value(batchId.toString()),
        ),
      );
    });
  }

  /// Quick Dispense / Sale stock reduction using FEFO (First Expiry First Out)
  Future<void> quickReduceStockFEFO({
    required int medicineId,
    required int reduceQty,
    required int userId,
    String reason = 'Quick Dispense / OTC Sale',
  }) async {
    if (reduceQty <= 0) return;

    await _db.transaction(() async {
      final now = DateTime.now();
      // Fetch available batches ordered by expiry date (FEFO)
      final batches = await (_db.select(_db.batches)
            ..where((b) =>
                b.medicineId.equals(medicineId) &
                b.quantity.isBiggerThan(const Constant(0)) &
                b.expiryDate.isBiggerThan(Variable(now)))
            ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
          .get();

      int remainingToDeduct = reduceQty;
      final totalAvailable = batches.fold<int>(0, (sum, b) => sum + b.quantity);

      if (totalAvailable < reduceQty) {
        throw Exception('Insufficient unexpired stock available! Required: $reduceQty, Available: $totalAvailable');
      }

      for (final batch in batches) {
        if (remainingToDeduct <= 0) break;

        final deductFromThisBatch = batch.quantity >= remainingToDeduct ? remainingToDeduct : batch.quantity;
        final newBatchQty = batch.quantity - deductFromThisBatch;

        // 1. Update Batch
        await (_db.update(_db.batches)..where((b) => b.id.equals(batch.id))).write(
          BatchesCompanion(quantity: Value(newBatchQty)),
        );

        // 2. Insert Stock Adjustment record
        await _db.into(_db.stockAdjustments).insert(
          StockAdjustmentsCompanion.insert(
            batchId: batch.id,
            qtyChange: -deductFromThisBatch,
            reason: reason,
            date: DateTime.now(),
            userId: userId,
          ),
        );

        remainingToDeduct -= deductFromThisBatch;
      }

      // Log activity
      await _db.into(_db.activityLogs).insert(
        ActivityLogsCompanion.insert(
          userId: userId,
          action: 'QUICK_DISPENSE',
          entity: 'Medicine',
          entityId: Value('$medicineId (Deducted $reduceQty units)'),
        ),
      );
    });
  }

  // --- ALERTS & NOTIFICATIONS ---

  Future<List<Batch>> getNearExpiryBatches({int daysThreshold = 90}) async {
    final now = DateTime.now();
    final thresholdDate = now.add(Duration(days: daysThreshold));

    return await (_db.select(_db.batches)
          ..where((b) =>
              b.quantity.isBiggerThan(const Constant(0)) &
              b.expiryDate.isBiggerThan(Variable(now)) &
              b.expiryDate.isSmallerOrEqual(Variable(thresholdDate)))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  Future<List<Batch>> getExpiredBatches() async {
    final now = DateTime.now();
    return await (_db.select(_db.batches)
          ..where((b) =>
              b.quantity.isBiggerThan(const Constant(0)) &
              b.expiryDate.isSmallerThan(Variable(now)))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  Stream<List<BatchWithMedicine>> watchExpiredBatches() {
    final now = DateTime.now();
    final query = _db.select(_db.batches).join([
      innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.batches.medicineId)),
    ])
      ..where(_db.batches.quantity.isBiggerThan(const Constant(0)) &
          _db.batches.expiryDate.isSmallerThan(Variable(now)))
      ..orderBy([OrderingTerm.asc(_db.batches.expiryDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return BatchWithMedicine(
          batch: row.readTable(_db.batches),
          medicine: row.readTable(_db.medicines),
        );
      }).toList();
    });
  }

  Stream<List<BatchWithMedicine>> watchNearExpiryBatches({int daysThreshold = 90}) {
    final now = DateTime.now();
    final thresholdDate = now.add(Duration(days: daysThreshold));
    final query = _db.select(_db.batches).join([
      innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.batches.medicineId)),
    ])
      ..where(_db.batches.quantity.isBiggerThan(const Constant(0)) &
          _db.batches.expiryDate.isBiggerThan(Variable(now)) &
          _db.batches.expiryDate.isSmallerOrEqual(Variable(thresholdDate)))
      ..orderBy([OrderingTerm.asc(_db.batches.expiryDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return BatchWithMedicine(
          batch: row.readTable(_db.batches),
          medicine: row.readTable(_db.medicines),
        );
      }).toList();
    });
  }

  Future<void> checkAndTriggerAlerts() async {
    final nearExpiry = await getNearExpiryBatches();
    for (final batch in nearExpiry) {
      final medicine = await (_db.select(_db.medicines)
            ..where((m) => m.id.equals(batch.medicineId)))
          .getSingleOrNull();

      if (medicine != null) {
        NotificationService.showExpiryAlert(
          medicineName: medicine.name,
          batchNo: batch.batchNo,
          expiryDateStr: batch.expiryDate.toString().split(' ')[0],
          isExpired: false,
        );
      }
    }
  }
}
