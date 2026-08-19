import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/local/database_provider.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/data/repositories/sales_repository.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SalesRepository(db);
});

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return repo.watchSales();
});

class PosCartState {
  final Customer? selectedCustomer;
  final List<SaleCartItemData> cartItems;
  final double overallDiscount;
  final String paymentMode; // 'cash', 'card', 'upi', 'credit'
  final String searchQuery;
  final bool isProcessing;

  PosCartState({
    this.selectedCustomer,
    this.cartItems = const [],
    this.overallDiscount = 0.0,
    this.paymentMode = 'cash',
    this.searchQuery = '',
    this.isProcessing = false,
  });

  double get subtotal => cartItems.fold(0.0, (sum, item) => sum + item.taxableAmount);
  double get totalTax => cartItems.fold(0.0, (sum, item) => sum + item.taxAmount);
  double get grandTotal => (subtotal + totalTax - overallDiscount).clamp(0.0, double.infinity);
  int get totalItemCount => cartItems.fold(0, (sum, item) => sum + item.qty);

  PosCartState copyWith({
    Customer? Function()? selectedCustomer,
    List<SaleCartItemData>? cartItems,
    double? overallDiscount,
    String? paymentMode,
    String? searchQuery,
    bool? isProcessing,
  }) {
    return PosCartState(
      selectedCustomer: selectedCustomer != null ? selectedCustomer() : this.selectedCustomer,
      cartItems: cartItems ?? this.cartItems,
      overallDiscount: overallDiscount ?? this.overallDiscount,
      paymentMode: paymentMode ?? this.paymentMode,
      searchQuery: searchQuery ?? this.searchQuery,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class PosCartNotifier extends StateNotifier<PosCartState> {
  final Ref _ref;

  PosCartNotifier(this._ref) : super(PosCartState());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCustomer(Customer? customer) {
    state = state.copyWith(selectedCustomer: () => customer);
  }

  void setPaymentMode(String mode) {
    state = state.copyWith(paymentMode: mode);
  }

  void setOverallDiscount(double discount) {
    state = state.copyWith(overallDiscount: discount);
  }

  /// Add medicine to cart (automatically selects earliest expiring active batch if not supplied)
  Future<void> addMedicineToCart(MedicineWithStock medWithStock, {Batch? specificBatch, int qty = 1}) async {
    if (medWithStock.totalQuantity <= 0 && specificBatch == null) {
      throw Exception('${medWithStock.medicine.name} is currently OUT OF STOCK!');
    }

    final repo = _ref.read(inventoryRepositoryProvider);

    Batch? targetBatch = specificBatch;
    targetBatch ??= await repo.getFEFOBatchForMedicine(medWithStock.medicine.id);

    if (targetBatch == null || targetBatch.quantity <= 0) {
      throw Exception('No valid available batch found for ${medWithStock.medicine.name}');
    }

    // Check if item already in cart with same batch
    final existingIndex = state.cartItems.indexWhere(
      (item) => item.medicine.id == medWithStock.medicine.id && item.batch.id == targetBatch!.id,
    );

    if (existingIndex >= 0) {
      final existingItem = state.cartItems[existingIndex];
      final newQty = existingItem.qty + qty;

      if (newQty > targetBatch.quantity) {
        throw Exception('Cannot exceed available batch stock (${targetBatch.quantity} ${medWithStock.medicine.unit}s available).');
      }

      final updatedList = List<SaleCartItemData>.from(state.cartItems);
      updatedList[existingIndex] = SaleCartItemData(
        medicine: existingItem.medicine,
        batch: existingItem.batch,
        qty: newQty,
        rate: existingItem.rate,
        discountPercent: existingItem.discountPercent,
      );

      state = state.copyWith(cartItems: updatedList);
    } else {
      if (qty > targetBatch.quantity) {
        throw Exception('Cannot exceed available batch stock (${targetBatch.quantity} ${medWithStock.medicine.unit}s available).');
      }

      final newItem = SaleCartItemData(
        medicine: medWithStock.medicine,
        batch: targetBatch,
        qty: qty,
        rate: targetBatch.mrp,
        discountPercent: 0.0,
      );

      state = state.copyWith(cartItems: [...state.cartItems, newItem]);
    }
  }

  void updateItemQty(int index, int newQty) {
    if (index < 0 || index >= state.cartItems.length) return;
    if (newQty <= 0) {
      removeItem(index);
      return;
    }

    final item = state.cartItems[index];
    if (newQty > item.batch.quantity) {
      throw Exception('Cannot exceed available batch stock (${item.batch.quantity} available).');
    }

    final updatedList = List<SaleCartItemData>.from(state.cartItems);
    updatedList[index] = SaleCartItemData(
      medicine: item.medicine,
      batch: item.batch,
      qty: newQty,
      rate: item.rate,
      discountPercent: item.discountPercent,
    );
    state = state.copyWith(cartItems: updatedList);
  }

  void updateItemDiscount(int index, double discountPercent) {
    if (index < 0 || index >= state.cartItems.length) return;

    final item = state.cartItems[index];
    final updatedList = List<SaleCartItemData>.from(state.cartItems);
    updatedList[index] = SaleCartItemData(
      medicine: item.medicine,
      batch: item.batch,
      qty: item.qty,
      rate: item.rate,
      discountPercent: discountPercent.clamp(0.0, 100.0),
    );
    state = state.copyWith(cartItems: updatedList);
  }

  void updateItemBatch(int index, Batch newBatch) {
    if (index < 0 || index >= state.cartItems.length) return;

    final item = state.cartItems[index];
    final newQty = item.qty.clamp(1, newBatch.quantity);

    final updatedList = List<SaleCartItemData>.from(state.cartItems);
    updatedList[index] = SaleCartItemData(
      medicine: item.medicine,
      batch: newBatch,
      qty: newQty,
      rate: newBatch.mrp,
      discountPercent: item.discountPercent,
    );
    state = state.copyWith(cartItems: updatedList);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.cartItems.length) return;
    final updatedList = List<SaleCartItemData>.from(state.cartItems)..removeAt(index);
    state = state.copyWith(cartItems: updatedList);
  }

  void clearCart() {
    state = state.copyWith(
      cartItems: [],
      overallDiscount: 0.0,
      paymentMode: 'cash',
      selectedCustomer: () => null,
    );
  }

  Future<int> checkout(int userId) async {
    if (state.cartItems.isEmpty) {
      throw Exception('Cannot checkout with an empty cart.');
    }

    state = state.copyWith(isProcessing: true);
    try {
      final repo = _ref.read(salesRepositoryProvider);
      final saleId = await repo.checkoutPOS(
        customerId: state.selectedCustomer?.id,
        cartItems: state.cartItems,
        overallDiscount: state.overallDiscount,
        paymentMode: state.paymentMode,
        userId: userId,
      );

      clearCart();
      return saleId;
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }
}

final posCartProvider = StateNotifierProvider<PosCartNotifier, PosCartState>((ref) {
  return PosCartNotifier(ref);
});
