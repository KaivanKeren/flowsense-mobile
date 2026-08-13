import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/app_version.dart';
import '../../core/max_width.dart';
import '../../widgets/widgets.dart';

/// Where the numbers come from, and how far to trust them.
///
/// Not filler. An examiner will ask where the data originates, and having a
/// screen for it is more convincing than answering out loud — but the real
/// reason it exists is the last section: an automatic count that can be wrong
/// should say so, in the app, where the person relying on it can read it.
class TentangScreen extends StatelessWidget {
  const TentangScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'Sumber peta',
      'Peta dan data jalan berasal dari OpenStreetMap, dipakai sesuai lisensi '
          'ODbL.',
    ),
    (
      'Sumber citra',
      'Citra kamera berasal dari portal CCTV Pemerintah Kabupaten Kudus.',
    ),
    (
      'Cara status dihitung',
      'Kendaraan pada tiap lajur dihitung otomatis dari citra kamera, lalu '
          'dibandingkan dengan kapasitas lajur tersebut. Status simpang '
          'mengikuti lajur yang paling padat, bukan rata-ratanya.',
    ),
    (
      'Batasan',
      'Angka yang ditampilkan adalah estimasi otomatis dan dapat meleset, '
          'terutama pada malam hari dan saat hujan. Simpang tanpa data '
          'ditandai abu-abu, tidak pernah ditandai lancar.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      appBar: AppBar(title: const Text('Tentang'), titleSpacing: FlowSpace.lg),
      body: MaxWidth448(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.lg,
            FlowSpace.sm,
            FlowSpace.lg,
            FlowSpace.xxl,
          ),
          children: [
            for (final (heading, body) in _sections) ...[
              const SizedBox(height: FlowSpace.lg),
              SectionHeader(title: heading),
              const SizedBox(height: FlowSpace.sm),
              Text(body, style: FlowTypography.of(context).body),
              const SizedBox(height: FlowSpace.lg),
              Divider(color: colors.borderSubtle, height: 1),
            ],
            const SizedBox(height: FlowSpace.xl),
            Text(
              'FlowSense versi $kAppVersion',
              style: FlowTypography.of(context)
                  .caption
                  .copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: FlowSpace.xs),
            Text(
              'Universitas Muria Kudus',
              style: FlowTypography.of(context)
                  .caption
                  .copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
