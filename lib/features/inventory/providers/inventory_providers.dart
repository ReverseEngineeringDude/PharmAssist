import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/local/database_provider.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InventoryRepository(db);
});

final medicinesWithStockProvider = StreamProvider<List<MedicineWithStock>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchMedicinesWithStock();
});

final lowStockMedicinesProvider = Provider<List<MedicineWithStock>>((ref) {
  final medicinesAsync = ref.watch(medicinesWithStockProvider);
  return medicinesAsync.when(
    data: (list) => list.where((item) => item.totalQuantity <= item.medicine.reorderLevel).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final expiredBatchesStreamProvider = StreamProvider<List<BatchWithMedicine>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchExpiredBatches();
});

final nearExpiryBatchesStreamProvider = StreamProvider<List<BatchWithMedicine>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchNearExpiryBatches();
});

final batchesForMedicineProvider = StreamProvider.family<List<Batch>, int>((ref, medicineId) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchBatchesForMedicine(medicineId);
});

final allBatchesStreamProvider = StreamProvider<List<Batch>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchAllBatches();
});

class MedicineSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  set state(String value) => super.state = value;
}
final medicineSearchQueryProvider = NotifierProvider<MedicineSearchQueryNotifier, String>(MedicineSearchQueryNotifier.new);

class SelectedCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  set state(String? value) => super.state = value;
}
final selectedCategoryFilterProvider = NotifierProvider<SelectedCategoryFilterNotifier, String?>(SelectedCategoryFilterNotifier.new);

class SelectedScheduleFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  set state(String? value) => super.state = value;
}
final selectedScheduleFilterProvider = NotifierProvider<SelectedScheduleFilterNotifier, String?>(SelectedScheduleFilterNotifier.new);

final filteredMedicinesProvider = Provider<List<MedicineWithStock>>((ref) {
  final medicinesAsync = ref.watch(medicinesWithStockProvider);
  final searchQuery = ref.watch(medicineSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedCategoryFilterProvider);
  final schedule = ref.watch(selectedScheduleFilterProvider);

  return medicinesAsync.when(
    data: (list) {
      return list.where((item) {
        final med = item.medicine;
        final matchesSearch = searchQuery.isEmpty ||
            med.name.toLowerCase().contains(searchQuery) ||
            (med.genericName?.toLowerCase().contains(searchQuery) ?? false) ||
            (med.manufacturer?.toLowerCase().contains(searchQuery) ?? false) ||
            (med.hsnCode?.toLowerCase().contains(searchQuery) ?? false);

        final matchesCategory = category == null || category.isEmpty || med.category == category;
        final matchesSchedule = schedule == null || schedule.isEmpty || med.scheduleFlag == schedule;

        return matchesSearch && matchesCategory && matchesSchedule;
      }).toList();
    },
    loading: () => [],
    error: (err, stack) => [],
  );
});
