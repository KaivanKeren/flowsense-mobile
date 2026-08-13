# Prompt untuk Claude Code — Refactor UI FlowSENSE + Theme Switching

> Tempel seluruh isi file ini sebagai satu pesan pertama ke Claude Code.
> Lampirkan juga 2 screenshot arah desain (overview operator & detail simpang).

---

## KONTEKS PROYEK

Ini aplikasi Flutter bernama FlowSENSE — konsol pemantauan lalu lintas persimpangan berbasis AI. Ada dua flavor:

- **Flavor warga**: peta GIS, daftar simpang, pengaturan notifikasi. Pengguna umum, termasuk lansia. Tanpa login.
- **Flavor operator**: login, Overview, detail simpang, peta, peringatan, analitik, kalibrasi lajur. Untuk petugas Dinas Perhubungan.

Batasan yang TIDAK boleh dilanggar:

1. Mobile-first, lebar kontainer maksimum **448px**. Bukan aplikasi desktop.
2. Konsol operator bersifat **read-only** — tidak ada kendali langsung ke lampu lalu lintas. Semua keluaran adalah *rekomendasi* yang bisa ditinjau dan dikonfirmasi, bukan perintah. Jangan pernah membuat tombol yang terkesan mengubah durasi lampu secara langsung.
3. Jangan ubah layer data, repository, model, atau state management. Refactor ini **khusus lapisan presentasi**.
4. Jangan ubah nama route dan signature widget publik tanpa memberitahu saya lebih dulu.

## ARAH DESAIN

Lihat screenshot terlampir. Bahasa visualnya: **operations console** bertema gelap, latar hampir hitam, aksen cyan, aksen kuning untuk peringatan, merah untuk darurat, hijau untuk status normal. Label kategori memakai huruf kapital berspasi lebar dengan font monospace, sedangkan angka metrik berukuran besar dan tebal. Kartu berlatar sedikit lebih terang dari kanvas, sudut membulat, tanpa bayangan berat.

Yang harus dipertahankan dari arah itu: hierarki angka yang kuat, status yang langsung terbaca, dan kesan teknis-terpercaya.

Yang harus diperbaiki: keterbacaan, konsistensi jarak, dan aksesibilitas.

---

## CARA KERJA

Kerjakan **satu tahap per waktu**. Setelah setiap tahap: jalankan `flutter analyze`, tunjukkan ringkasan perubahan, lalu **BERHENTI dan tunggu persetujuan saya** sebelum lanjut ke tahap berikutnya. Jangan menggabungkan beberapa tahap dalam satu jalan.

Buat satu commit per tahap dengan pesan yang deskriptif.

---

## TAHAP 0 — Audit (tanpa mengubah file apa pun)

Baca seluruh `lib/` dan laporkan:

1. Daftar screen dan widget beserta path-nya, dikelompokkan per flavor.
2. Semua nilai visual yang hardcoded: warna, ukuran font, padding, radius. Sebutkan file dan barisnya.
3. Widget yang duplikat atau nyaris sama dan layak dijadikan komponen bersama.
4. Setiap tempat yang berisiko overflow horizontal.
5. Masalah aksesibilitas: kontras rendah, target sentuh di bawah 48dp, teks yang tidak ikut `textScaler`, widget interaktif tanpa `Semantics`.

Keluarkan sebagai tabel ringkas + usulan urutan pengerjaan. **Jangan tulis kode di tahap ini.**

---

## TAHAP 1 — Design system & dukungan tema

Buat fondasi di `lib/theme/` sebelum menyentuh layar mana pun.

**Token semantik**, bukan nama warna literal. Contoh penamaan yang saya mau: `surfaceCanvas`, `surfaceCard`, `surfaceElevated`, `borderSubtle`, `textPrimary`, `textSecondary`, `textMuted`, `accentPrimary`, `statusNormal`, `statusWarning`, `statusCritical`, `statusEmergency`, `dataInk`. Alasannya: token semantik memungkinkan tema terang tanpa membalik warna secara membabi buta.

Isi yang diperlukan:

- `AppColors` sebagai `ThemeExtension` dengan dua varian: `dark` (sesuai screenshot) dan `light`.
- Skala jarak kelipatan 4 (4, 8, 12, 16, 24, 32) — tidak ada angka padding lain di seluruh aplikasi.
- Radius: `sm 8`, `md 12`, `lg 16`.
- `TextTheme` dengan peran jelas: `metricLarge` (angka besar), `metricUnit`, `sectionTitle`, `labelMono` (monospace kapital berspasi), `body`, `caption`.
- `ThemeMode` yang bisa diganti pengguna: system / light / dark. Simpan pilihannya secara persisten, dan sediakan toggle di layar pengaturan masing-masing flavor.

**Aturan penting untuk tema terang**: jangan sekadar membalik tema gelap. Latar hitam dengan aksen neon tidak bisa dipindahkan apa adanya ke latar putih — cyan terang di atas putih gagal kontras. Untuk tema terang, gelapkan aksen sampai rasio kontras terhadap latar minimal 4.5:1 untuk teks dan 3:1 untuk elemen grafis. Semua status harus tetap terbedakan di kedua tema.

Terakhir, tulis satu test yang memverifikasi bahwa setiap pasangan token teks/latar di kedua tema memenuhi kontras 4.5:1. Kalau ada yang gagal, sesuaikan nilainya dan laporkan.

---

## TAHAP 2 — Komponen bersama

Buat di `lib/widgets/` — semuanya harus mengambil nilai dari token Tahap 1, tanpa warna hardcoded:

- `MetricCard` — label monospace, angka besar, satuan, tren opsional, ikon opsional.
- `StatusChip` — level kepadatan dan status sistem. **Status tidak boleh dibedakan hanya lewat warna**; selalu sertakan ikon atau teks pendamping agar pengguna buta warna tetap bisa membacanya.
- `SectionHeader`, `AppCard`, `LiveIndicator` (titik + "Diperbarui N detik lalu").
- `AlertBanner` untuk override darurat.
- State kosong, error, memuat (skeleton), dan data basi.
- `RecommendationCard` — kepercayaan model, alasan, dampak yang diharapkan, tombol tinjau. Gunakan kata kerja "Tinjau", "Konfirmasi", "Catat" — bukan "Terapkan", "Kirim ke lampu", atau "Ubah durasi".

---

## TAHAP 3 — Perbaikan tata letak yang rusak

Ada bug nyata di UI sekarang yang terlihat di screenshot. Perbaiki lebih dulu sebelum polesan visual:

1. **Baris kartu metrik terpotong di tepi kanan.** Baris "PERSIMPANGAN AKTIF / RATA-RATA ANTREAN / PREDIKSI" dan "VOL / ANTREAN / KECEPATAN" terpotong. Pilih salah satu: `ListView` horizontal dengan padding tepi yang benar dan indikator geser yang jelas, atau grid 2 kolom yang membungkus ke bawah. Jangan biarkan kartu terpotong separuh tanpa petunjuk bahwa masih ada isi di kanan.
2. **Label bottom navigation terpangkas** menjadi "Ove", "Int", "Ale". Perpendek labelnya, kecilkan ukuran font satu tingkat, atau kurangi jumlah tab. Label yang terpotong tidak boleh lolos.
3. **Teks bertabrakan** — "RATA-RATA ANTREAN" menimpa "Baru saja"; chip "Diperbarui 8 dtk lalu" pecah dua baris di dalam kotak sempit. Perbaiki dengan constraint yang benar, bukan dengan mengecilkan font sampai tidak terbaca.

Setelah selesai, uji setiap layar pada lebar 320, 360, 414, dan 448 logical pixel, serta pada `textScaleFactor` 1.0 dan 1.3. Laporkan layar mana yang masih overflow.

---

## TAHAP 4 — Refactor layar, satu per satu

Urutan: Overview operator → Detail simpang → Peringatan → Analitik → Peta → lalu semua layar flavor warga.

Untuk setiap layar, terapkan token dan komponen dari tahap sebelumnya, dan pastikan ada keempat state: memuat, kosong, error, data basi.

**Khusus flavor warga**: bahasa visualnya harus lebih tenang dan lapang daripada konsol operator. Ukuran teks lebih besar, informasi per layar lebih sedikit, istilah teknis diganti bahasa sehari-hari. Sebagian penggunanya lansia. Jangan pakai label monospace kapital di sisi warga — itu identitas visual konsol operator, bukan aplikasi publik.

Kerjakan **satu layar per commit**, dan berhenti untuk saya tinjau setelah dua layar pertama.

---

## TAHAP 5 — Aksesibilitas & pemeriksaan akhir

- Tambahkan `Semantics` label pada semua kartu metrik, status, dan tombol utama. Contoh: chip status harus terbaca screen reader sebagai "Status simpang: macet", bukan sekadar warna.
- Pastikan seluruh target sentuh minimal 48x48dp.
- Uji ulang seluruh layar di tema terang dan gelap, pada `textScaleFactor` 1.0 dan 1.3.
- Jalankan `flutter analyze` dan `flutter test`. Laporkan hasilnya.
- Tulis ringkasan singkat: apa yang berubah, file apa yang disentuh, dan apa yang masih perlu perhatian.

---

## MULAI SEKARANG

Kerjakan **Tahap 0 saja**, lalu berhenti dan tunggu persetujuan saya.
