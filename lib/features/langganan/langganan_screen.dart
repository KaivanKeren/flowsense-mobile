import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../domain/app_mode.dart';
import '../../domain/subscription.dart';
import '../../state/app_mode_providers.dart';
import '../../state/providers.dart';
import '../../widgets/widgets.dart';
import '../tentang/tentang_screen.dart';

/// Which intersections are worth being interrupted for, and when.
///
/// Everything here stays on the device. There is no account to attach it to
/// and no endpoint that receives it.
class LanggananScreen extends ConsumerWidget {
  const LanggananScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final settings = ref.watch(subscriptionProvider);
    final intersections = ref.watch(intersectionsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      appBar: AppBar(title: const Text('Langganan'), titleSpacing: FlowSpace.lg),
      body: MaxWidth448(
        child: ListView(
          padding: const EdgeInsets.only(bottom: FlowSpace.xl),
          children: [
            const SectionHeader(
              title: 'Simpang yang dipantau',
              padding: EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.xl,
                FlowSpace.lg,
                FlowSpace.sm,
              ),
            ),
            if (intersections == null)
              const SkeletonList(rows: 3)
            else
              for (final intersection in intersections)
                _SwitchRow(
                  label: intersection.name,
                  value: settings.isSubscribed(intersection.id),
                  onChanged: (_) => unawaited(
                    ref
                        .read(subscriptionProvider.notifier)
                        .toggle(intersection.id),
                  ),
                ),

            const SectionHeader(
              title: 'Beri tahu saat',
              padding: EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.xl,
                FlowSpace.lg,
                FlowSpace.sm,
              ),
            ),
            for (final threshold in AlertThreshold.values)
              _RadioRow(
                label: _thresholdLabel(threshold),
                selected: settings.threshold == threshold,
                onTap: () => unawaited(
                  ref
                      .read(subscriptionProvider.notifier)
                      .setThreshold(threshold),
                ),
              ),

            const SectionHeader(
              title: 'Jam aktif',
              padding: EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.xl,
                FlowSpace.lg,
                FlowSpace.sm,
              ),
            ),
            for (var i = 0; i < settings.activeHours.length; i++)
              _RangeRow(
                index: i,
                range: settings.activeHours[i],
                onEdit: () => _editRange(context, ref, settings, i),
                onRemove: () => unawaited(
                  ref.read(subscriptionProvider.notifier).setActiveHours(
                        [...settings.activeHours]..removeAt(i),
                      ),
                ),
              ),
            _AddRangeRow(
              onTap: () => _editRange(context, ref, settings, null),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.sm,
                FlowSpace.lg,
                0,
              ),
              child: Text(
                'Di luar jam ini, notifikasi tidak dikirim.',
                style: FlowTypography.of(context)
                    .caption
                    .copyWith(color: colors.textMuted),
              ),
            ),

            const SizedBox(height: FlowSpace.xl),
            Divider(color: colors.borderSubtle, height: 1),
            _LinkRow(
              label: 'Tentang dan sumber data',
              onTap: () => unawaited(Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TentangScreen(),
                ),
              )),
            ),

            // The way into the console, and the only one — the citizen tabs
            // carry no other mention of it. Down here rather than in the tab
            // bar or an app bar: it is a door for the few people who work at
            // the dinas, not a fourth destination for everyone else. Pressing
            // it proves nothing; `OperatorGate` still asks for a password.
            _LinkRow(
              key: const ValueKey('switch-to-operator'),
              label: 'Masuk sebagai operator',
              icon: Icons.shield_outlined,
              onTap: () => unawaited(
                ref.read(appModeProvider.notifier).switchTo(AppMode.operator),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The threshold copy reads as a full sentence on its own in the spec, but as
  /// a radio option under a "Beri tahu saat" heading it would stutter. Trimmed
  /// to the part that varies.
  String _thresholdLabel(AlertThreshold threshold) => switch (threshold) {
        AlertThreshold.macetSaja => 'Macet saja',
        AlertThreshold.padatDanMacet => 'Padat dan macet',
      };

  Future<void> _editRange(
    BuildContext context,
    WidgetRef ref,
    SubscriptionSettings settings,
    int? index,
  ) async {
    final existing =
        index == null ? const TimeRange.hours(6, 9) : settings.activeHours[index];

    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: existing.startMinute ~/ 60,
        minute: existing.startMinute % 60,
      ),
      helpText: 'Mulai',
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: existing.endMinute ~/ 60,
        minute: existing.endMinute % 60,
      ),
      helpText: 'Sampai',
    );
    if (end == null) return;

    final range = TimeRange(
      startMinute: start.hour * 60 + start.minute,
      endMinute: end.hour * 60 + end.minute,
    );

    final hours = [...settings.activeHours];
    if (index == null) {
      hours.add(range);
    } else {
      hours[index] = range;
    }
    await ref.read(subscriptionProvider.notifier).setActiveHours(hours);
  }
}

/// Rows never fix their height: they size to their content so a large
/// `textScaler` grows them instead of clipping the label.
class _Row extends StatelessWidget {
  const _Row({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: FlowTouch.minTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.lg,
            vertical: FlowSpace.md,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Row(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: FlowTypography.of(context).sectionTitle),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _Row(
      onTap: onTap,
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: FlowIconSize.md,
              color: selected ? colors.textPrimary : colors.statusUnknown,
            ),
            const SizedBox(width: FlowSpace.md),
            Expanded(
              child: Text(label,
                  style: FlowTypography.of(context).sectionTitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.index,
    required this.range,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final TimeRange range;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final type = FlowTypography.of(context);
    return _Row(
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Text('Rentang ${index + 1}', style: type.sectionTitle),
          ),
          Text(range.label, style: type.sectionTitle),
          const SizedBox(width: FlowSpace.xs),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: FlowIconSize.sm),
            tooltip: 'Hapus rentang',
          ),
        ],
      ),
    );
  }
}

class _AddRangeRow extends StatelessWidget {
  const _AddRangeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Row(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.add, size: FlowIconSize.md),
            const SizedBox(width: FlowSpace.md),
            Text('Tambah rentang waktu',
                style: FlowTypography.of(context).sectionTitle),
          ],
        ),
      );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;

  /// A leading icon, for a row that goes somewhere unlike the others around it.
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _Row(
        onTap: onTap,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: FlowIconSize.md),
              const SizedBox(width: FlowSpace.md),
            ],
            Expanded(
              child: Text(label,
                  style: FlowTypography.of(context).sectionTitle),
            ),
            const Icon(Icons.chevron_right, size: FlowIconSize.md),
          ],
        ),
      );
}
