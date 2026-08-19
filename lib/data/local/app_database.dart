import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pharmassist/core/utils/hash_utils.dart';

part 'app_database.g.dart';

// 1. Medicine Table
class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get genericName => text().nullable()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get hsnCode => text().nullable()();
  RealColumn get gstRate => real().withDefault(const Constant(18.0))();
  TextColumn get unit => text().withDefault(const Constant('Strip'))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(10))();
  TextColumn get scheduleFlag => text().withDefault(const Constant('none'))(); // H, H1, X, none
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 2. Batch Table
@DataClassName('Batch')
class Batches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicineId => integer().references(Medicines, #id, onDelete: KeyAction.cascade)();
  TextColumn get batchNo => text()();
  DateTimeColumn get mfgDate => dateTime().nullable()();
  DateTimeColumn get expiryDate => dateTime()();
  RealColumn get purchasePrice => real()();
  RealColumn get mrp => real()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 3. Supplier Table
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get gstin => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get balanceDue => real().withDefault(const Constant(0.0))();
}

// 4. PurchaseInvoice Table
class PurchaseInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get invoiceNo => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get totalAmount => real()();
}

// 5. PurchaseInvoiceItem Table
class PurchaseInvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseInvoiceId => integer().references(PurchaseInvoices, #id, onDelete: KeyAction.cascade)();
  IntColumn get batchId => integer().references(Batches, #id)();
  IntColumn get qty => integer()();
  RealColumn get rate => real()();
}

// 6. Customer Table
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get creditBalance => real().withDefault(const Constant(0.0))();
}

// 7. Sale Table
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get invoiceNo => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get taxCgst => real().withDefault(const Constant(0.0))();
  RealColumn get taxSgst => real().withDefault(const Constant(0.0))();
  RealColumn get taxIgst => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))(); // cash, card, upi, credit
}

// 8. SaleItem Table
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get batchId => integer().references(Batches, #id)();
  IntColumn get qty => integer()();
  RealColumn get rate => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
}

// 9. User Table
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get role => text()(); // admin, pharmacist, cashier
  TextColumn get pinHash => text()();
}

// 10. StockAdjustment Table
class StockAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get batchId => integer().references(Batches, #id)();
  IntColumn get qtyChange => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get userId => integer().references(Users, #id)();
}

// 11. ActivityLog Table
class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get action => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pharmassist.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}

@DriftDatabase(
  tables: [
    Medicines,
    Batches,
    Suppliers,
    PurchaseInvoices,
    PurchaseInvoiceItems,
    Customers,
    Sales,
    SaleItems,
    Users,
    StockAdjustments,
    ActivityLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      
      // Create Indexes
      await customStatement('CREATE INDEX IF NOT EXISTS idx_medicines_name ON medicines (name);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_batches_expiry ON batches (expiry_date);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_sales_date ON sales (date);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_sales_invoice ON sales (invoice_no);');

      // Seed Default Users
      await into(users).insert(
        UsersCompanion.insert(
          name: 'Admin User',
          role: 'admin',
          pinHash: HashUtils.hashPin('1234'),
        ),
      );
      await into(users).insert(
        UsersCompanion.insert(
          name: 'Pharmacist User',
          role: 'pharmacist',
          pinHash: HashUtils.hashPin('1111'),
        ),
      );
      await into(users).insert(
        UsersCompanion.insert(
          name: 'Cashier User',
          role: 'cashier',
          pinHash: HashUtils.hashPin('0000'),
        ),
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  /// Completely wipes all local inventory, purchase, customer, and sales records.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(saleItems).go();
      await delete(sales).go();
      await delete(purchaseInvoiceItems).go();
      await delete(purchaseInvoices).go();
      await delete(stockAdjustments).go();
      await delete(batches).go();
      await delete(medicines).go();
      await delete(suppliers).go();
      await delete(customers).go();
      await delete(activityLogs).go();
    });
  }
}
