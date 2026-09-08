import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/transaction_history_screen.dart';
import '../data/transactions_repository.dart';

/// Экран «Безналичные» — GET /api/payments/:account
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key, required this.account, this.deviceName});

  final String account;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final repo = TransactionsRepository();
    return TransactionHistoryScreen(
      title: 'Безналичные',
      subtitle: deviceName?.isNotEmpty == true
          ? '${deviceName!} · № $account'
          : '№ $account',
      accent: context.colors.accentAlt,
      rowIcon: Icons.contactless_rounded,
      loader: () async {
        final result = await repo.payments(account);
        return result.items
            .map((e) => TxnRow(id: e.id, date: e.created, amount: e.sum))
            .toList();
      },
    );
  }
}
