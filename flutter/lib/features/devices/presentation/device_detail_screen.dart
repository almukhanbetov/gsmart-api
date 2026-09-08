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
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/signal_bars.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../dashboard/models/device_totals.dart';
import '../models/device.dart';

/// Детали автомата + переходы к истории (Купюры / Монеты / Безналичные).
class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key, required this.account});

  final String account;

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.instance.session;
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
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Автомат не найден',
        ),
      );
    }

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
      (Icons.account_balance_wallet_outlined, 'Баланс', formatTenge(d.summa)),
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
      body: ListView(
        padding: AppSpacing.page,
        children: [
          FadeSlideIn(child: _DeviceHero(device: d, quality: quality)),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
              title: 'Характеристики', icon: Icons.tune_rounded),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              child: Column(
                children: [
                  for (var i = 0; i < specs.length; i++) ...[
                    if (i != 0) Divider(color: c.border, height: 1),
                    _SpecRow(
                      icon: specs[i].$1,
                      label: specs[i].$2,
                      value: specs[i].$3,
                    ),
                  ],
                ],
              ),
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
                          : 'Smart24 #${device.account}',
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

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.textMuted),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: text.bodyMedium?.copyWith(color: c.textSecondary)),
          const Spacer(),
          Flexible(
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
