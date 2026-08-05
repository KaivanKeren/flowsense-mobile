import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../domain/subscription.dart';
import '../../state/providers.dart';
import '../tentang/tentang_screen.dart';

/// Which intersections are worth being interrupted for, and when.
///
/// Everything here stays on the device. There is no account to attach it to
/// and no endpoint that receives it.
class LanggananScreen extends ConsumerWidget {
  const LanggananScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = FlowSurfaces.of(context);
    final settings = ref.watch(subscriptionProvider);
    final intersections = ref.watch(intersectionsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: surfaces.page,
      appBar: AppBar(title: const Text('Langganan')),
      body: MaxWidth448(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _SectionLabel('Simpang yang dipantau'),
            if (intersections == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
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

            _SectionLabel('Beri tahu saat'),
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

            _SectionLabel('Jam aktif'),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Di luar jam ini, notifikasi tidak dikirim.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: surfaces.textFaint),
              ),
            ),

            const SizedBox(height: 20),
            Divider(color: surfaces.roadLine, height: 1),
            _LinkRow(
              label: 'Tentang dan sumber data',
              onTap: () => unawaited(Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TentangScreen(),
                ),
              )),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: surfaces.textSecondary),
      ),
    );
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
    final surfaces = FlowSurfaces.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.roadLine)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  style: Theme.of(context).textTheme.titleMedium),
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
    final surfaces = FlowSurfaces.of(context);
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
              size: 20,
              color: selected ? surfaces.textPrimary : surfaces.faintInk,
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
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
    final text = Theme.of(context).textTheme;
    return _Row(
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Text('Rentang ${index + 1}', style: text.titleMedium),
          ),
          Text(range.label, style: text.titleMedium),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
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
            const Icon(Icons.add, size: 18),
            const SizedBox(width: 12),
            Text('Tambah rentang waktu',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Row(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      );
}
