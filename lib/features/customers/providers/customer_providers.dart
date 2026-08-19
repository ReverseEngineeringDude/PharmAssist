import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/local/database_provider.dart';
import 'package:pharmassist/data/repositories/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CustomerRepository(db);
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.watchCustomers();
});

class CustomerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  set state(String value) => super.state = value;
}
final customerSearchQueryProvider = NotifierProvider<CustomerSearchQueryNotifier, String>(CustomerSearchQueryNotifier.new);

class CreditOnlyFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set state(bool value) => super.state = value;
}
final creditOnlyFilterProvider = NotifierProvider<CreditOnlyFilterNotifier, bool>(CreditOnlyFilterNotifier.new);

final filteredCustomersProvider = Provider<List<Customer>>((ref) {
  final customersAsync = ref.watch(customersStreamProvider);
  final query = ref.watch(customerSearchQueryProvider).trim().toLowerCase();
  final creditOnly = ref.watch(creditOnlyFilterProvider);

  return customersAsync.when(
    data: (customers) {
      return customers.where((c) {
        final matchesQuery = query.isEmpty ||
            c.name.toLowerCase().contains(query) ||
            (c.phone != null && c.phone!.contains(query));
        final matchesCredit = !creditOnly || c.creditBalance > 0;

        return matchesQuery && matchesCredit;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
