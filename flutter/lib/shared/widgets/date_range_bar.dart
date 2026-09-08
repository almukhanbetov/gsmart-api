import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum DateRangePreset { today, week, month, custom }

class DateRange {
  const DateRange(this.from, this.to, this.preset);

  final DateTime from;
  final DateTime to;
  final DateRangePreset preset;

  static DateRange forPreset(DateRangePreset preset, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final endOfDay = DateTime(today.year, today.month, today.day);
    switch (preset) {
      case DateRangePreset.today:
        return DateRange(endOfDay, endOfDay, preset);
      case DateRangePreset.week:
        return DateRange(
            endOfDay.subtract(const Duration(days: 6)), endOfDay, preset);
      case DateRangePreset.month:
        return DateRange(
            DateTime(today.year, today.month, 1), endOfDay, preset);
      case DateRangePreset.custom:
        return DateRange(DateTime(today.year, today.month, 1), endOfDay, preset);
    }
  }
}

/// Фильтр по датам: пресеты-чипы + произвольный диапазон.
/// Фильтрация — на клиенте (как в mobile), backend не меняется.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateRange value;
  final ValueChanged<DateRange> onChanged;

  static const _labels = {
    DateRangePreset.today: 'Сегодня',
    DateRangePreset.week: 'Неделя',
    DateRangePreset.month: 'Месяц',
    DateRangePreset.custom: 'Период',
  };

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: value.from, end: value.to),
    );
    if (picked != null) {
      onChanged(DateRange(picked.start, picked.end, DateRangePreset.custom));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: DateRangePreset.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final preset = DateRangePreset.values[i];
              final selected = value.preset == preset;
              return GestureDetector(
                onTap: () {
                  if (preset == DateRangePreset.custom) {
                    _pickCustom(context);
                  } else {
                    onChanged(DateRange.forPreset(preset));
                  }
                },
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : c.surface,
                    borderRadius: AppRadius.rPill,
                    border: Border.all(
                        color: selected ? c.accent : c.border),
                  ),
                  child: Row(
                    children: [
                      if (preset == DateRangePreset.custom) ...[
                        Icon(Icons.calendar_month_rounded,
                            size: 14,
                            color: selected ? Colors.white : c.textSecondary),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        _labels[preset]!,
                        style: text.labelMedium?.copyWith(
                          color: selected ? Colors.white : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(Icons.date_range_rounded, size: 14, color: c.textMuted),
            const SizedBox(width: 6),
            Text(
              '${formatDateShort(value.from)} — ${formatDateShort(value.to)}',
              style: text.bodySmall?.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
