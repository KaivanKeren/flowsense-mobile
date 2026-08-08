# FlowSense — Aplikasi Warga: Spesifikasi Layout

Dokumen ini adalah acuan implementasi UI untuk flavor `warga`. Pasangannya adalah `2026-08-02-flowsense-mobile-flutter.md` (rencana teknis, task-by-task) dan `docs/api-contract.md` (kontrak data). Kalau ada pertentangan, **dokumen teknis menang untuk perilaku, dokumen ini menang untuk tata letak dan teks.**

---

## Referensi visual

Letakkan hasil ekspor Stitch di `assets/design/`. Nama berkas di bawah dipakai sebagai acuan sepanjang dokumen ini.

| Berkas | Layar |
|---|---|
| `assets/design/warga-01-peta.png` | Halaman utama, peta + sheet ringkas |
| `assets/design/warga-02-sheet-penuh.png` | Sheet ditarik penuh (lajur, riwayat, kamera) |
| `assets/design/warga-03-data-basi.png` | Simpang tanpa data masuk |
| `assets/design/warga-04-simpang.png` | Daftar simpang |
| `assets/design/warga-05-langganan.png` | Langganan dan notifikasi |
| `assets/design/warga-06-tentang.png` | Tentang dan sumber data |

**Cara memakai gambar-gambar ini:** ambil proporsi, hierarki, dan rasa spasinya. Jangan ambil angka piksel mentahnya — Stitch menggambar di 360×800 tanpa memperhitungkan area aman, dan hasilnya sering menyisipkan bayangan atau gradasi yang dilarang di bagian Token di bawah. Kalau gambar dan dokumen ini berbeda, ikuti dokumen ini.

Marker peta pada ekspor Stitch kemungkinan besar salah — cincin empat segmennya tidak akan tergambar benar. Anatominya ditulis lengkap di bawah; implementasikan dari teks, bukan dari gambar.

---

## Token

Sumber tunggal ada di `lib/app/theme.dart` sebagai `ThemeExtension` bernama `CongestionColors`. Jangan pernah menulis hex langsung di widget.

```
Latar halaman      #F7F7F5
Permukaan kartu    #FFFFFF
Latar peta         #EEF0ED
Garis jalan        #E3E5E2
Teks utama         #1A1D1C
Teks sekunder      #6B706E
Teks samar         #9AA0A0

Lancar             #1F9D62
Padat              #E0A32E
Macet              #D64541
Tidak diketahui    #9AA0A0
```

Tipografi: Plus Jakarta Sans. Dua bobot saja — 400 dan 500. Ukuran: 28 (angka utama), 18 (judul layar), 15 (judul baris), 13 (isi), 11 (keterangan). Tidak ada di bawah 11.

Aturan yang mengikat:

- Lebar konten maksimum 448 px, dibungkus `MaxWidth448`.
- Empat warna kepadatan **hanya** dipakai untuk menyatakan kepadatan. Tidak untuk tombol, tautan, aksen, atau ikon dekoratif.
- Rata dan bersih. Tanpa gradasi, tanpa bayangan, tanpa efek kaca. Garis pembatas rambut saja.
- Sentence case di semua tempat. Tanpa tanda seru. Tanpa emoji.
- Radius 8 untuk kontrol, 12 untuk kartu, 16 untuk sudut atas sheet.
- Target sentuh minimum 44×44. Kalau elemen visualnya lebih kecil (batang grafik), perluas area sentuhnya, jangan perbesar elemennya.

---

## Peta rute

```
/                 PetaScreen        halaman utama
/simpang          SimpangScreen     daftar simpang
/langganan        LanggananScreen   simpang yang dipantau
/tentang          TentangScreen     sumber data dan atribusi
```

Tanpa login. Tanpa akun. Langganan disimpan di perangkat (`shared_preferences`), tidak dikirim ke server.

Navigasi utama: bilah bawah **tiga tab — Peta, Simpang, Langganan.** Tentang dijangkau dari dalam Langganan, bukan dari bilah.

Tab aktif ditandai kapsul abu lembut `#EEF0ED` di belakang ikon dan labelnya, dengan ikon dan label `#1A1D1C`. Tab tidak aktif `#9AA0A0` tanpa kapsul. Ikon bergaya garis, label di bawah ikon.

**Tidak ada tab `Laporan` dan tidak ada tab `Profil`.** Keduanya sempat muncul di keluaran Stitch sebagai isian otomatis. Alasan penolakannya ada di bagian "Yang sengaja tidak dibuat".

---

## 1. PetaScreen

Peta mengisi seluruh layar sebagai kanvas. Bukan salah satu tab di antara konten lain.

**Susunan dari atas:**

- Kolom pencarian mengambang, `Cari simpang`, latar putih, radius 12, garis rambut, tanpa bayangan. Menyaring marker dan membuka sheet saat hasil dipilih.
- `FlutterMap` dengan lapisan ubin OpenStreetMap.
- `RichAttributionWidget` — **wajib**, ini kewajiban lisensi OSM, bukan pilihan gaya.
- `MarkerLayer`, satu marker per simpang.
- `DraggableScrollableSheet` di bagian bawah.

### Anatomi marker

Ini elemen tanda tangan aplikasi. Implementasikan sebagai `CustomPainter`.

- Lingkaran inti berisi angka `total_vehicles`. Diameter 38–46 px, berskala terhadap jumlah kendaraan relatif ke simpang terpadat yang sedang tampil.
- Cincin luar dibagi empat busur sama besar, satu per lajur, dengan celah kecil antar busur. Tiap busur diwarnai menurut level lajurnya sendiri.
- Warna isi inti mengikuti **level lajur terparah**, bukan level dari total. Ini sengaja: satu pendekat yang tersumbat harus terbaca merah walau total kendaraannya kecil.
- Keadaan tanpa data: inti kosong berlatar putih, garis tepi abu, tanda tanya menggantikan angka, keempat busur abu.
- Marker terpilih tampil penuh; marker lain diredupkan ke opasitas 0,55.

`Semantics` label: `"Simpang DPRD, macet, 18 kendaraan"`.

### Sheet tiga tahap

`DraggableScrollableSheet` dengan `snapSizes: [0.28, 0.55, 0.92]`. Gagang seret abu di tengah atas.

**Tahap ringkas (0.28)** — cukup untuk menjawab pertanyaan utama tanpa gestur tambahan:

- Nama simpang, 18 px, bobot 500
- Pil status di kanan: `Lancar` / `Padat` / `Macet` / `Data basi`
- `18 kendaraan · 7 detik lalu`, 13 px, teks sekunder
- `Arah kota paling padat`, 13 px, teks sekunder

**Tahap setengah (0.55)** — menambah:

- Empat baris lajur. Tiap baris: label arah (13 px, sekunder) · batang 8 px radius 4 · angka di kanan. Lebar isi batang = `count / capacity`, dipotong di 100%. Warna batang mengikuti level lajur itu.
- Bagian riwayat 60 menit (lihat bagian 2).

**Tahap penuh (0.92)** — menambah:

- Panel kamera, lebar penuh, rasio 16:9.
- Baris `Simpang terdekat`, satu baris geser mendatar berisi kartu kecil (nama + titik status). Bukan grid.

**Kamera diletakkan paling bawah dan itu disengaja.** Ini elemen paling menarik tapi paling tidak bisa ditindaklanjuti — pengendara tidak bisa membaca kepadatan dari video resolusi rendah lebih cepat daripada dari satu batang berwarna. Keterangan di bawah panel, 11 px, teks samar: `Diperbarui tiap 20 detik`.

---

## 2. Riwayat 60 menit

Muncul di dalam sheet, bukan layar terpisah.

- 60 batang tegak, satu per menit, jarak 1 px, sudut atas membulat 2 px.
- **Tinggi = jumlah kendaraan. Warna = level lajur terparah.** Dua encoding dari sumber berbeda, dan ini benar — kalau warna diambil dari total, layar akan menampilkan hijau saat satu pendekat tersumbat total. Baris pembacaan di atas grafik menyebutkan lajur penyebabnya supaya kombinasi ini tidak membingungkan.
- **Menit tanpa data digambar sebagai garis tipis abu setinggi 3 px di dasar. Jangan diinterpolasi.** Grafik yang mulus melewati periode connector mati adalah kebohongan, dan itu pertanyaan pertama yang akan diajukan penguji kalau demo sempat terputus.
- Tanpa sumbu Y. Label waktu di bawah: jam awal, jam tengah, `sekarang`.
- Legenda satu baris: Lancar · Padat · Macet · Data hilang.
- Mengetuk batang mengubah baris pembacaan di atas menjadi menit itu. Area sentuh setinggi grafik penuh, bukan setinggi batang.
- Chip pemilih arah di bawah grafik: `Semua arah` plus empat arah. Saat satu arah dipilih, tinggi batang memakai hitungan lajur itu dan levelnya dihitung terhadap kapasitas lajur tersebut.

Ringkasan di bawah grafik, maksimal tiga baris, hanya yang berlaku:

- `Padat sejak 16:05, belum ada tanda reda`
- `Tertinggi 20 kendaraan pukul 16:27`
- `Data tidak masuk 3 menit pukul 16:02`

Data berasal dari `GET /v1/intersections/{id}/history` dengan bucket 1 menit — 60 titik. **Agregasi di server, bukan di perangkat.** Jangan pernah menarik 1800 record mentah ke HP.

---

## 3. SimpangScreen

Setara dengan peta, bukan pelengkap. Ini yang menyelamatkan aplikasi saat peta gagal dimuat, saat izin lokasi ditolak, dan saat penggunanya memakai pembaca layar. Peta tidak bisa dibaca TalkBack; daftar bisa.

Baris bordered, bukan kartu membulat. Tiap baris: nama simpang · pil status · `18 kendaraan` · `1,2 km` · `7 detik lalu`.

Pengurutan bisa dipilih: terparah dulu (bawaan) atau terdekat dulu. Kalau izin lokasi ditolak, opsi terdekat disembunyikan dan daftar tetap jalan.

---

## 4. LanggananScreen

- Daftar simpang yang dipantau, sakelar per simpang.
- Ambang: `Beri tahu saat macet` atau `Beri tahu saat padat dan macet`.
- Jam aktif, bawaan 06.00–09.00 dan 15.00–19.00. **Jangan hilangkan ini.** Memberi tahu orang bahwa Simpang DPRD macet pukul dua pagi adalah cara tercepat membuat aplikasi dicopot.
- Tautan ke Tentang.

Aturan pemicunya ada di `lib/domain/alerts.dart` dan sudah diuji terpisah: menyala hanya setelah macet bertahan tiga siklus berturut-turut, tidak menyala ulang saat sudah aktif, dan **tidak pernah menyala dari data basi** — connector mati bukan kemacetan.

---

## 5. TentangScreen

Bukan basa-basi. Penguji hampir pasti menanyakan asal data, dan punya layarnya lebih meyakinkan daripada menjawab lisan.

- Atribusi OpenStreetMap.
- Sumber citra: portal CCTV Pemerintah Kabupaten Kudus.
- Cara status dihitung, dua sampai tiga kalimat, tanpa jargon.
- Pernyataan bahwa angka adalah estimasi otomatis dan bisa meleset, terutama malam hari dan saat hujan.
- Versi aplikasi.

---

## 6. Keadaan gagal

Satu pola, tiga varian. Setiap varian: satu kalimat yang menjelaskan apa yang terjadi, satu tombol yang bisa ditekan. **Tidak ada spinner tanpa ujung.**

| Keadaan | Teks | Tombol |
|---|---|---|
| Tidak ada koneksi | `Tidak ada koneksi. Data terakhir 4 menit lalu.` | `Coba lagi` |
| Semua simpang tanpa data | `Belum ada data masuk dari simpang mana pun.` | `Coba lagi` |
| Izin lokasi ditolak | `Lokasi tidak diizinkan. Simpang tetap bisa dilihat di daftar.` | `Buka daftar` |

Aturan yang mengikat seluruh aplikasi: **kegagalan pengambilan data tidak boleh mengosongkan layar.** Snapshot terakhir tetap ditampilkan dengan penanda basi. Perilaku ini sudah ada di `TrafficRepository` — UI hanya perlu menghormatinya dan tidak menggantinya dengan layar kosong.

`per_lane` kosong dirender sebagai **tidak diketahui, bukan lancar.** Ketiadaan data bukan berarti jalan lancar, dan ini kegagalan paling berbahaya yang bisa dilakukan aplikasi ini.

---

## Aksesibilitas

Bagian ini bukan pelengkap. Sisi disabilitas proyek ini hilang saat pindah ke SaaS, dan di sinilah ia bisa hidup lagi — dalam bentuk yang bisa dibuktikan di depan penguji dalam tiga puluh detik.

- Setiap marker punya `Semantics` label lengkap.
- Setiap status punya teks pendamping, tidak pernah warna saja. Buta warna merah-hijau adalah kasus yang persis relevan untuk aplikasi lalu lintas.
- Rasio kontras teks minimal 4.5:1 terhadap latarnya. Periksa pil status secara khusus — teks berwarna di atas tint pucat adalah tempat aturan ini paling sering bocor.
- Daftar simpang menyediakan seluruh informasi peta dalam bentuk yang bisa dibaca pembaca layar.
- Hormati `MediaQuery.textScaler`. Jangan pernah mengunci tinggi baris yang berisi teks.

---

## Yang sengaja tidak dibuat

Ditulis di sini supaya tidak muncul lagi sebagai usulan di tengah jalan:

- **Akun dan login untuk warga.** Tidak perlu identitas untuk melihat kemacetan. Ini memangkas seluruh lapisan autentikasi dari backend.
- **Rute dan navigasi belok-per-belok.** Begitu muncul panah belok, aplikasi ini dibandingkan dengan Google Maps dan kalah.
- **Laporan dari warga.** Butuh moderasi; tanpa moderasi akan terisi sampah pada hari kedua.
- **Mode gelap.** Sedap dipandang, nol poin penilaian, dan menggandakan pekerjaan pemeriksaan kontras.

---

## Kriteria selesai

- [ ] Empat warna kepadatan hanya muncul lewat `CongestionColors`; `git grep` tidak menemukan hex kepadatan di luar `theme.dart`
- [ ] Atribusi OSM tampak di layar peta
- [ ] `per_lane` kosong dirender abu, bukan hijau
- [ ] Menit tanpa data pada grafik tidak diinterpolasi
- [ ] Kegagalan polling menyisakan snapshot terakhir plus penanda basi
- [ ] Semua teks antarmuka bahasa Indonesia, sentence case
- [ ] Area sentuh batang grafik setinggi grafik penuh (diuji lewat widget test)
- [ ] Seluruh isi terbungkus `MaxWidth448`
- [ ] Aplikasi bisa dijalankan penuh dengan `FakeFlowSenseApi`, tanpa backend