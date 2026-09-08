import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/transaction_history_screen.dart';
import '../data/transactions_repository.dart';

/// Экран «Купюры» — GET /api/money/:account
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key, required this.account, this.deviceName});

  final String account;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final repo = TransactionsRepository();
    return TransactionHistoryScreen(
      title: 'Купюры',
      subtitle: deviceName?.isNotEmpty == true
          ? '${deviceName!} · № $account'
          : '№ $account',
      accent: context.colors.accent,
      rowIcon: Icons.receipt_long_rounded,
      loader: () async {
        final result = await repo.money(account);
        return result.items
            .map((e) => TxnRow(id: e.id, date: e.createdAt, amount: e.payMoney))
            .toList();
      },
    );
  }
}
