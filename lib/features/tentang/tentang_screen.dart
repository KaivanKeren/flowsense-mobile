import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/app_version.dart';
import '../../core/max_width.dart';

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
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: surfaces.page,
      appBar: AppBar(title: const Text('Tentang')),
      body: MaxWidth448(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final (heading, body) in _sections) ...[
              const SizedBox(height: 16),
              Text(
                heading,
                style: text.bodySmall?.copyWith(color: surfaces.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(body, style: text.bodyMedium),
              const SizedBox(height: 16),
              Divider(color: surfaces.roadLine, height: 1),
            ],
            const SizedBox(height: 24),
            Text(
              'FlowSense versi $kAppVersion',
              style: text.bodySmall?.copyWith(color: surfaces.textFaint),
            ),
            const SizedBox(height: 2),
            Text(
              'Universitas Muria Kudus',
              style: text.bodySmall?.copyWith(color: surfaces.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
