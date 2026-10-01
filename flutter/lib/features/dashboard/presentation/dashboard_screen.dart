import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/storage/session_storage.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/refresh_status.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/dashboard_summary.dart';
import '../models/device_totals.dart';
import 'widgets/device_card.dart';
import 'widgets/revenue_hero_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  /// Обновление запущено жестом — свой индикатор уже показывает RefreshIndicator.
  bool _pulling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // обновление при открытии главной (после первого кадра — не во время build)
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SessionStore.instance.refresh(force: false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // главная всегда в стеке после входа — ловим возврат из фона здесь
    if (state == AppLifecycleState.resumed) {
      SessionStore.instance.refresh(force: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pullToRefresh() async {
    setState(() => _pulling = true);
    try {
      await SessionStore.instance.refresh();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await SessionStore.instance.signOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionStore.instance,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final c = context.colors;
    final store = SessionStore.instance;
    final session = store.session;

    if (session == null) {
      return const Scaffold(body: SafeArea(child: DashboardSkeleton()));
    }

    final user = session.user;
    final devices = session.devices;
    final summary = DashboardSummary.of(session);

    final refreshError = store.refreshError;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _pullToRefresh,
              color: c.accent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: [
                  FadeSlideIn(
                    child: _Header(
                      name: user.fullname.isNotEmpty ? user.fullname : user.phone,
                      onLogout: () => _logout(context),
                    ),
                  ),
                  if (refreshError != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    RefreshErrorBanner(
                      message: refreshError,
                      updatedAt: store.updatedAt,
                      onRetry: () => store.refresh(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: RevenueHeroCard(summary: summary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: _SummaryGrid(summary: summary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const SectionHeader(
                      title: 'Автоматы', icon: Icons.dashboard_rounded),
                  if (devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xxl),
                      child: EmptyState(
                        icon: Icons.point_of_sale_outlined,
                        title: 'Автоматы не найдены',
                        message: 'К вашему аккаунту пока не привязан ни один автомат',
                      ),
                    )
                  else
                    for (var i = 0; i < devices.length; i++) ...[
                      FadeSlideIn(
                        delay: Duration(milliseconds: 150 + i * 55),
                        child: DeviceCard(
                          device: devices[i],
                          totals: DeviceTotals.forDevice(devices[i], session),
                          onTap: () => context.go(
                            '/dashboard/${Uri.encodeComponent(devices[i].account)}',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RefreshProgressBar(
                visible: store.isRefreshing && !_pulling,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onLogout});
  final String name;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final firstName = name.split(' ').first;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: AppRadius.rMd,
          ),
          child: Text(
            initialsOf(name, 'S'),
            style: text.titleMedium?.copyWith(color: c.accent),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${greeting()}, $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: c.textPrimary)),
              Text('Обзор сети автоматов',
                  style: text.bodySmall?.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        _RoundButton(
          icon: ThemeController.instance.icon,
          onTap: () => ThemeController.instance.cycle(),
        ),
        const SizedBox(width: AppSpacing.sm),
        _RoundButton(icon: Icons.logout_rounded, onTap: onLogout),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 19, color: c.textPrimary),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = [
      MetricCard(
        icon: Icons.point_of_sale_rounded,
        value: '${summary.deviceCount}',
        label: 'Автоматов',
        tint: c.accent,
      ),
      MetricCard(
        icon: Icons.wifi_rounded,
        value: '${summary.onlineCount}',
        label: 'Online',
        tint: c.success,
      ),
      MetricCard(
        icon: Icons.wifi_off_rounded,
        value: '${summary.offlineCount}',
        label: 'Offline',
        tint: c.offline,
      ),
      MetricCard(
        icon: Icons.network_cell_rounded,
        value: summary.avgSignal == null ? '—' : '${summary.avgSignal}%',
        label: 'Средний сигнал',
        tint: AppColors.cyan,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: 84,
      ),
      itemBuilder: (context, i) => items[i],
    );
  }
}
