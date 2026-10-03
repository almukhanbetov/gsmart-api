import 'dart:async';

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
import 'widgets/finance_card.dart';

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
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SessionStore.instance.refresh(force: false),
    );
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    super.dispose();
  }

  /// В полночь по Алматы плитки «· сегодня» пересчитываются: иначе до
  /// следующей перерисовки они показывали бы вчерашние суммы.
  void _scheduleMidnight() {
    _midnight?.cancel();
    _midnight = Timer(untilProjectMidnight(), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnight();
    });
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

    // «Тариф» и «Абон. плата до» — в верхнем блоке (_DeviceHero)
    final specs = <(IconData, String, String)>[
      if (d.gruppa.isNotEmpty)
        (Icons.folder_open_rounded, 'Группа', d.gruppa),
      if (d.dataInkas != null && d.dataInkas!.isNotEmpty)
        (
          Icons.local_atm_rounded,
          'Инкассация',
          formatDateTime(DateTime.tryParse(d.dataInkas!))
        ),
    ];

    return Scaffold(
      appBar: AppTopBar(
        title: d.displayTitle,
        subtitle: '№ ${d.account}',
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            // свежие данные сессии → плитки; FinanceCard сам перезагрузит
            // историю после обновления сессии
            onRefresh: () => store.refresh(),
            color: c.accent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                // пустую секцию не показываем вместе с заголовком и отступом
                if (specs.isNotEmpty) ...[
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
                ],
                const SizedBox(height: AppSpacing.xxl),
                // карточка «Финансы»: итог и разбивка за выбранный период;
                // плитки ниже — отдельно, по-прежнему за сегодня
                FinanceCard(account: d.account),
                const SizedBox(height: AppSpacing.lg),
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
    final abon = formatDateFull(device.abonTime);

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // иконка только рядом с заголовком — колонки ниже на всю ширину
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: AppRadius.rMd,
                ),
                child: Icon(Icons.local_car_wash_rounded,
                    color: c.accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  device.displayTitle,
                  style: text.titleLarge?.copyWith(color: c.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoTable(rows: [
            ('Аккаунт №', device.account),
            ('Тариф', formatTenge(device.summa)),
            if (abon != null) ('Абон. плата до', abon),
          ]),
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

/// Две колонки: подписи слева (по одному краю, приглушённые), значения
/// справа (по правому краю, полужирные). Ширина подписей — по самой длинной,
/// но не больше половины: длинное значение переносится в своей колонке,
/// оставаясь в одной строке таблицы со своей подписью.
class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    const cell = EdgeInsets.symmetric(vertical: AppSpacing.xs);

    return Table(
      columnWidths: const {
        0: MinColumnWidth(IntrinsicColumnWidth(), FractionColumnWidth(0.5)),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final (label, value) in rows)
          TableRow(
            children: [
              Padding(
                padding: cell.copyWith(right: AppSpacing.md),
                child: Text(
                  label,
                  style: text.bodyMedium?.copyWith(color: c.textMuted),
                ),
              ),
              Padding(
                padding: cell,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
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
                Text('${formatTenge(amount)} · сегодня',
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
