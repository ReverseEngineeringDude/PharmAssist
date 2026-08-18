import 'package:drift/drift.dart';
import 'package:pharmassist/data/local/app_database.dart';

class CustomerRepository {
  final AppDatabase _db;

  CustomerRepository(this._db);

  Stream<List<Customer>> watchCustomers() {
    return (_db.select(_db.customers)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
  }

  Future<List<Customer>> getCustomers() async {
    return await (_db.select(_db.customers)..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
  }

  Future<Customer?> getCustomerById(int id) async {
    return await (_db.select(_db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<int> addCustomer(CustomersCompanion companion) async {
    final id = await _db.into(_db.customers).insert(companion);
    await _db.into(_db.activityLogs).insert(
      ActivityLogsCompanion.insert(
        userId: 1,
        action: 'CREATE_CUSTOMER',
        entity: 'Customer',
        entityId: Value(id.toString()),
      ),
    );
    return id;
  }

  Future<bool> updateCustomer(Customer customer) async {
    return await _db.update(_db.customers).replace(customer);
  }

  Future<int> deleteCustomer(int id) async {
    return await (_db.delete(_db.customers)..where((c) => c.id.equals(id))).go();
  }

  Future<void> recordCreditPayment({
    required int customerId,
    required double paymentAmount,
    required String paymentMode,
    String? note,
  }) async {
    await _db.transaction(() async {
      final customer = await getCustomerById(customerId);
      if (customer == null) throw Exception('Customer not found');

      final newCreditBalance = (customer.creditBalance - paymentAmount).clamp(0.0, double.infinity);

      await (_db.update(_db.customers)..where((c) => c.id.equals(customerId))).write(
        CustomersCompanion(creditBalance: Value(newCreditBalance)),
      );

      await _db.into(_db.activityLogs).insert(
        ActivityLogsCompanion.insert(
          userId: 1,
          action: 'CREDIT_PAYMENT',
          entity: 'Customer',
          entityId: Value('$customerId (Paid ₹$paymentAmount via $paymentMode${note != null ? " - $note" : ""})'),
        ),
      );
    });
  }
}
