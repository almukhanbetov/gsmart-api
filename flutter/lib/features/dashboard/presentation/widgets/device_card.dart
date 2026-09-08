import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/signal_bars.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../devices/models/device.dart';
import '../../models/device_totals.dart';

/// Современная карточка автомата на дашборде.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.totals,
    required this.onTap,
  });

  final Device device;
  final DeviceTotals totals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final quality = signalQuality(device.signalWifi);
    final online = device.status;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: AppRadius.rMd,
                ),
                child: Icon(Icons.point_of_sale_rounded,
                    size: 21, color: c.accent),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text('№ ${device.account}',
                        style: text.bodySmall?.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 22),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusBadge(
                label: online ? 'Online' : 'Offline',
                tone: online ? BadgeTone.online : BadgeTone.offline,
                dense: true,
              ),
              const Spacer(),
              SignalBars(quality: quality, showLabel: true, size: 15),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: c.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Сегодня',
                      style: text.labelSmall?.copyWith(color: c.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    formatTenge(totals.total),
                    style: text.titleMedium?.copyWith(
                      color: c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _MiniStat(
                  icon: Icons.receipt_long_rounded,
                  value: totals.payMoneyToday),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(
                  icon: Icons.toll_rounded, value: totals.payCoinToday),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(
                  icon: Icons.contactless_rounded,
                  value: totals.paymentsToday.round()),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});
  final IconData icon;
  final num value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, size: 15, color: c.textMuted),
        const SizedBox(height: 3),
        Text(
          formatMoney(value),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: c.textSecondary, fontSize: 11.5),
        ),
      ],
    );
  }
}
