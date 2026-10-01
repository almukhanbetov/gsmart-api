import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/storage/session_storage.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/refresh_status.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/signal_bars.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../dashboard/models/device_totals.dart';
import '../models/device.dart';

/// Детали автомата + переходы к истории (Купюры / Монеты / Безналичные).
///
/// Данные — из общего [SessionStore]: при открытии экрана запрашивается
/// свежая копия, и главная с характеристиками показывают одно и то же.
class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({super.key, required this.account});

  final String account;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SessionStore.instance.refresh(force: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionStore.instance,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final store = SessionStore.instance;
    final session = store.session;
    final account = widget.account;
    Device? device;
    if (session != null) {
      for (final d in session.devices) {
        if (d.account == account) {
          device = d;
          break;
        }
      }
    }

    if (device == null || session == null) {
      return Scaffold(
        appBar: const AppTopBar(title: 'Автомат'),
        body: Stack(
          children: [
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Автомат не найден',
            ),
            RefreshProgressBar(visible: store.isRefreshing),
          ],
        ),
      );
    }

    final refreshError = store.refreshError;

    final d = device;
    final c = context.colors;
    final quality = signalQuality(d.signalWifi);
    final totals = DeviceTotals.forDevice(d, session);

    final specs = <(IconData, String, String)>[
      (
        Icons.dns_rounded,
        'Сервер',
        d.serverStatus ? 'на связи' : 'нет связи'
      ),
      (
        Icons.developer_board_rounded,
        'Устройство',
        d.deviceStatus ? 'включено' : 'выключено'
      ),
      if (d.gruppa.isNotEmpty)
        (Icons.folder_open_rounded, 'Группа', d.gruppa),
      if (d.bin.isNotEmpty) (Icons.badge_outlined, 'БИН', d.bin),
      (Icons.account_balance_wallet_outlined, 'Тариф', formatTenge(d.summa)),
      if (d.abonTime != null && d.abonTime!.isNotEmpty)
        (Icons.event_repeat_rounded, 'Абон. плата до', d.abonTime!),
      if (d.dataInkas != null && d.dataInkas!.isNotEmpty)
        (
          Icons.local_atm_rounded,
          'Инкассация',
          formatDateTime(DateTime.tryParse(d.dataInkas!))
        ),
      if (d.dataStatus != null && d.dataStatus!.isNotEmpty)
        (
          Icons.schedule_rounded,
          'Обновлён',
          formatDateTime(DateTime.tryParse(d.dataStatus!))
        ),
    ];

    return Scaffold(
      appBar: AppTopBar(
        title: d.deviceName.isNotEmpty ? d.deviceName : 'Автомат',
        subtitle: '№ ${d.account}',
      ),
      body: Stack(
        children: [
          ListView(
            padding: AppSpacing.page,
            children: [
              if (refreshError != null) ...[
                RefreshErrorBanner(
                  message: refreshError,
                  updatedAt: store.updatedAt,
                  onRetry: () => store.refresh(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              FadeSlideIn(child: _DeviceHero(device: d, quality: quality)),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(
                  title: 'Характеристики', icon: Icons.tune_rounded),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                  child: _SpecTable(specs: specs),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(
                  title: 'Финансы · сегодня', icon: Icons.savings_rounded),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: _FinanceTile(
                  icon: Icons.receipt_long_rounded,
                  tint: c.accent,
                  label: 'Купюры',
                  amount: totals.payMoneyToday,
                  onTap: () => context.go(
                      '/dashboard/${Uri.encodeComponent(d.account)}/money'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: _FinanceTile(
                  icon: Icons.toll_rounded,
                  tint: AppColors.cyan,
                  label: 'Монеты',
                  amount: totals.payCoinToday,
                  onTap: () => context.go(
                      '/dashboard/${Uri.encodeComponent(d.account)}/coin'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _FinanceTile(
                  icon: Icons.contactless_rounded,
                  tint: c.accentAlt,
                  label: 'Безналичные',
                  amount: totals.paymentsToday,
                  onTap: () => context.go(
                      '/dashboard/${Uri.encodeComponent(d.account)}/payments'),
                ),
              ),
            ],
          ),
          RefreshProgressBar(visible: store.isRefreshing),
        ],
      ),
    );
  }
}

class _DeviceHero extends StatelessWidget {
  const _DeviceHero({required this.device, required this.quality});
  final Device device;
  final int? quality;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final online = device.status;

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: AppRadius.rMd,
                ),
                child: Icon(Icons.point_of_sale_rounded,
                    color: c.accent, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName.isNotEmpty
                          ? device.deviceName
                          : 'G_smart.kz #${device.account}',
                      style: text.titleLarge?.copyWith(color: c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('Account № ${device.account}',
                        style: text.bodySmall?.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              StatusBadge(
                label: online ? 'Online' : 'Offline',
                tone: online ? BadgeTone.online : BadgeTone.offline,
              ),
              const Spacer(),
              Icon(Icons.wifi_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              SignalBars(quality: quality, showLabel: true, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

/// Таблица характеристик: слева иконка + название (ширина по самой длинной
/// подписи), справа значения — все от одной вертикальной линии.
class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.specs});

  final List<(IconData, String, String)> specs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    const cellPadding = EdgeInsets.symmetric(vertical: AppSpacing.md);

    return Table(
      // Подписи — по самой длинной, но не шире половины: значениям всегда
      // хватает места, слова и даты не разрываются.
      columnWidths: const {
        0: MinColumnWidth(IntrinsicColumnWidth(), FractionColumnWidth(0.5)),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (var i = 0; i < specs.length; i++)
          TableRow(
            decoration: i == 0
                ? null
                : BoxDecoration(
                    border: Border(top: BorderSide(color: c.border)),
                  ),
            children: [
              Padding(
                padding: cellPadding.copyWith(right: AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(specs[i].$1, size: 17, color: c.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Text(
                        specs[i].$2,
                        style:
                            text.bodyMedium?.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: cellPadding,
                child: Text(
                  specs[i].$3,
                  textAlign: TextAlign.left,
                  style: text.bodyMedium?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _FinanceTile extends StatelessWidget {
  const _FinanceTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.amount,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final num amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: c.isDark ? 0.18 : 0.12),
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: text.titleSmall?.copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(formatTenge(amount),
                    style: text.bodySmall?.copyWith(color: c.textMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
