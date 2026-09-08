import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/devices/presentation/device_detail_screen.dart';
import '../../features/transactions/coin/coin_screen.dart';
import '../../features/transactions/money/money_screen.dart';
import '../../features/transactions/payments/payments_screen.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/empty_state.dart';
import '../storage/session_storage.dart';

/// Навигация приложения.
///
///   старт → есть сессия? ── нет → /            (Login)
///                        └─ да  → /dashboard   (Dashboard)
///   /dashboard → /dashboard/:account (детали) → .../money | .../coin | .../payments
class AppRouter {
  const AppRouter._();

  static String? _deviceName(String account) {
    final session = SessionStore.instance.session;
    if (session == null) return null;
    for (final d in session.devices) {
      if (d.account == account) return d.deviceName;
    }
    return null;
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: SessionStore.instance,
    redirect: (context, state) {
      if (!SessionStore.instance.isLoaded) return null;

      final loggedIn = SessionStore.instance.isLoggedIn;
      final atLogin = state.matchedLocation == '/';

      if (!loggedIn) return atLogin ? null : '/';
      if (loggedIn && atLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: ':account',
            builder: (context, state) => DeviceDetailScreen(
              account: Uri.decodeComponent(state.pathParameters['account']!),
            ),
            routes: [
              GoRoute(
                path: 'money',
                builder: (context, state) {
                  final account =
                      Uri.decodeComponent(state.pathParameters['account']!);
                  return MoneyScreen(
                      account: account, deviceName: _deviceName(account));
                },
              ),
              GoRoute(
                path: 'coin',
                builder: (context, state) {
                  final account =
                      Uri.decodeComponent(state.pathParameters['account']!);
                  return CoinScreen(
                      account: account, deviceName: _deviceName(account));
                },
              ),
              GoRoute(
                path: 'payments',
                builder: (context, state) {
                  final account =
                      Uri.decodeComponent(state.pathParameters['account']!);
                  return PaymentsScreen(
                      account: account, deviceName: _deviceName(account));
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      appBar: AppTopBar(title: 'Ошибка'),
      body: EmptyState(
        icon: Icons.explore_off_rounded,
        title: 'Страница не найдена',
      ),
    ),
  );
}
