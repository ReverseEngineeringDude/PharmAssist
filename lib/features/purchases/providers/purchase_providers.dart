import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/local/database_provider.dart';
import 'package:pharmassist/data/repositories/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PurchaseRepository(db);
});

final purchaseInvoicesProvider = StreamProvider<List<PurchaseInvoiceWithDetails>>((ref) {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.watchPurchaseInvoices();
});

final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.watchSuppliers();
});

class PurchaseSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  set state(String value) => super.state = value;
}
final purchaseSearchQueryProvider = NotifierProvider<PurchaseSearchQueryNotifier, String>(PurchaseSearchQueryNotifier.new);

final filteredPurchaseInvoicesProvider = Provider<List<PurchaseInvoiceWithDetails>>((ref) {
  final invoicesAsync = ref.watch(purchaseInvoicesProvider);
  final query = ref.watch(purchaseSearchQueryProvider).trim().toLowerCase();

  return invoicesAsync.when(
    data: (invoices) {
      if (query.isEmpty) return invoices;
      return invoices.where((inv) {
        final matchesInvoiceNo = inv.invoice.invoiceNo.toLowerCase().contains(query);
        final matchesSupplier = inv.supplier.name.toLowerCase().contains(query);
        return matchesInvoiceNo || matchesSupplier;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
