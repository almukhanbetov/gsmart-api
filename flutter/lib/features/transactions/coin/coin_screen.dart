import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/transaction_history_screen.dart';
import '../data/transactions_repository.dart';

/// Экран «Монеты» — GET /api/coin/:account
class CoinScreen extends StatelessWidget {
  const CoinScreen({super.key, required this.account, this.deviceName});

  final String account;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final repo = TransactionsRepository();
    return TransactionHistoryScreen(
      title: 'Монеты',
      subtitle: deviceName?.isNotEmpty == true
          ? '${deviceName!} · № $account'
          : '№ $account',
      accent: AppColors.cyan,
      rowIcon: Icons.toll_rounded,
      loader: () async {
        final result = await repo.coin(account);
        return result.items
            .map((e) => TxnRow(id: e.id, date: e.createdAt, amount: e.payCoin))
            .toList();
      },
    );
  }
}
