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
    final count = await (_db.delete(_db.medicines)..where((m) => m.id.equals(id))).go();
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
    return count;
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
