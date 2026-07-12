import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'credit_repository.dart';

final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  return CreditRepository(
    ref.watch(databaseProvider),
    ref.watch(shopIdProvider),
  );
});

final creditSalesProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(creditRepositoryProvider).watchCreditSales();
});

final repaymentsProvider = StreamProvider<List<CreditPayment>>((ref) {
  return ref.watch(creditRepositoryProvider).watchRepayments();
});

/// Per-customer outstanding balances (customers who still owe, largest first).
final creditCustomersProvider = Provider<List<CreditCustomer>>((ref) {
  final sales = ref.watch(creditSalesProvider).valueOrNull ?? const [];
  final repayments = ref.watch(repaymentsProvider).valueOrNull ?? const [];
  return CreditRepository.aggregate(sales, repayments);
});

/// Total credit outstanding across all customers.
final creditOutstandingTotalProvider = Provider<int>((ref) {
  return ref
      .watch(creditCustomersProvider)
      .fold(0, (sum, c) => sum + c.outstanding);
});
